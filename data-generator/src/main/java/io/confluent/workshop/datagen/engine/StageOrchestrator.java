package io.confluent.workshop.datagen.engine;

import io.confluent.workshop.datagen.config.ConfigParser;
import io.confluent.workshop.datagen.config.ConnectionConfig;
import io.confluent.workshop.datagen.config.GeneratorConfig;
import io.confluent.workshop.datagen.dsl.DslEvaluator;
import io.confluent.workshop.datagen.dsl.EvalContext;
import io.confluent.workshop.datagen.health.HealthServer;
import io.confluent.workshop.datagen.sink.KafkaSink;
import io.confluent.workshop.datagen.sink.PostgresSink;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/**
 * Executes generators in staged order. Within each stage, generators run
 * concurrently in separate threads so that throttle delays on one generator
 * do not block others.
 */
public class StageOrchestrator {

    private static final Logger log = LoggerFactory.getLogger(StageOrchestrator.class);

    private final ConfigParser config;
    private final LookupRegistry lookupRegistry;
    private final Map<String, PostgresSink> postgresSinks = new HashMap<>();
    private final Map<String, KafkaSink> kafkaSinks = new HashMap<>();
    private final Map<String, GeneratorRunner> runners = new LinkedHashMap<>();
    private final HealthServer healthServer;
    private volatile boolean shutdownRequested = false;

    public StageOrchestrator(ConfigParser config, HealthServer healthServer) {
        this.config = config;
        this.lookupRegistry = new LookupRegistry();
        this.healthServer = healthServer;
    }

    public void initialize() {
        // Create sinks from connection configs
        for (Map.Entry<String, ConnectionConfig> entry : config.connections().entrySet()) {
            ConnectionConfig cc = entry.getValue();
            if ("postgres".equals(cc.kind())) {
                postgresSinks.put(entry.getKey(), new PostgresSink(cc));
            } else if ("kafka".equals(cc.kind())) {
                kafkaSinks.put(entry.getKey(), new KafkaSink(cc));
            }
        }

        // Create runners for each generator
        for (GeneratorConfig gc : config.generators()) {
            DslEvaluator evaluator = new DslEvaluator();
            EvalContext context = new EvalContext(lookupRegistry);

            PostgresSink pgSink = gc.connection() != null ? postgresSinks.get(gc.connection()) : null;
            KafkaSink kafkaSink = gc.connection() != null ? kafkaSinks.get(gc.connection()) : null;

            GeneratorRunner runner = new GeneratorRunner(
                    gc, evaluator, context, pgSink, kafkaSink, healthServer);
            runners.put(gc.name(), runner);
        }

        // Auto-create Postgres tables from pgHint annotations (if tablePolicy is "create")
        for (GeneratorConfig gc : config.generators()) {
            Map<String, String> pgHints = gc.pgHintColumns();
            if (pgHints != null) {
                PostgresSink pgSink = postgresSinks.get(gc.connection());
                if (pgSink != null) {
                    pgSink.ensureTableExists(gc.table(), pgHints);
                }
            }
        }
    }

    public void run() {
        List<List<String>> stages = config.stages();

        for (int stageIdx = 0; stageIdx < stages.size(); stageIdx++) {
            if (shutdownRequested) break;

            List<String> stageGenerators = stages.get(stageIdx);
            log.info("=== Stage {} ({} generators: {}) ===",
                    stageIdx + 1, stageGenerators.size(), stageGenerators);

            // Initialize varsOnce for all generators in this stage
            for (String genName : stageGenerators) {
                GeneratorRunner runner = runners.get(genName);
                if (runner == null) {
                    log.warn("Generator not found: {}", genName);
                    continue;
                }
                runner.initVarsOnce();
            }

            runStage(stageGenerators);

            // Flush all sinks after each stage
            flushSinks();

            log.info("=== Stage {} complete ===", stageIdx + 1);
        }
    }

    /**
     * Run generators concurrently within a stage. Each generator gets its own
     * thread so throttle delays on one generator don't block others.
     * The stage completes when all generators finish their maxEvents.
     */
    private void runStage(List<String> generatorNames) {
        List<GeneratorRunner> stageRunners = new ArrayList<>();
        for (String name : generatorNames) {
            GeneratorRunner runner = runners.get(name);
            if (runner != null && !runner.isFinished()) stageRunners.add(runner);
        }

        if (stageRunners.isEmpty()) return;

        CountDownLatch latch = new CountDownLatch(stageRunners.size());
        ExecutorService executor = Executors.newFixedThreadPool(stageRunners.size(), r -> {
            Thread t = new Thread(r);
            t.setDaemon(true);
            return t;
        });

        for (GeneratorRunner runner : stageRunners) {
            executor.submit(() -> {
                try {
                    runGenerator(runner);
                } catch (Exception e) {
                    log.error("Generator {} failed: {}", runner.name(), e.getMessage(), e);
                } finally {
                    latch.countDown();
                }
            });
        }

        try {
            latch.await();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            shutdownRequested = true;
        } finally {
            executor.shutdownNow();
        }
    }

    private void runGenerator(GeneratorRunner runner) {
        while (!shutdownRequested) {
            if (runner.isFinished()) break;

            boolean shouldContinue = runner.produceOne();
            if (!shouldContinue) {
                log.info("  Generator {} finished ({} events)",
                        runner.name(), runner.eventCount());
                break;
            }

            long throttleMs = runner.evaluateThrottleMs();
            if (throttleMs > 0) {
                try {
                    Thread.sleep(throttleMs);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
    }

    private void flushSinks() {
        for (KafkaSink sink : kafkaSinks.values()) {
            try {
                sink.flush();
            } catch (Exception e) {
                log.error("Error flushing Kafka sink", e);
            }
        }
    }

    public void shutdown() {
        shutdownRequested = true;
        log.info("Shutting down sinks...");
        for (KafkaSink sink : kafkaSinks.values()) {
            try { sink.close(); } catch (Exception e) { log.error("Error closing Kafka sink", e); }
        }
        for (PostgresSink sink : postgresSinks.values()) {
            try { sink.close(); } catch (Exception e) { log.error("Error closing Postgres sink", e); }
        }
    }
}
