package io.confluent.workshop.datagen;

import io.confluent.workshop.datagen.config.ConfigParser;
import io.confluent.workshop.datagen.config.ConnectionConfig;
import io.confluent.workshop.datagen.config.GeneratorConfig;
import io.confluent.workshop.datagen.engine.StageOrchestrator;
import io.confluent.workshop.datagen.health.DqrTestHandler;
import io.confluent.workshop.datagen.health.HealthServer;
import org.apache.avro.Schema;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;

public class Main {

    private static final Logger log = LoggerFactory.getLogger(Main.class);

    public static void main(String[] args) {
        String configPath = parseConfigPath(args);
        log.info("=== Data Generator Starting ===");
        log.info("Config: {}", configPath);

        HealthServer healthServer = new HealthServer();
        StageOrchestrator orchestrator = null;

        try {
            healthServer.start();

            log.info("Parsing configuration...");
            ConfigParser config = new ConfigParser(configPath);
            log.info("Loaded {} generators, {} connections, {} stages",
                    config.generators().size(),
                    config.connections().size(),
                    config.stages().size());

            orchestrator = new StageOrchestrator(config, healthServer);

            registerDqrEndpoint(config, healthServer);

            // Register shutdown hook
            final StageOrchestrator orch = orchestrator;
            Runtime.getRuntime().addShutdownHook(new Thread(() -> {
                log.info("Shutdown signal received");
                orch.shutdown();
                healthServer.stop();
            }, "shutdown-hook"));

            log.info("Initializing sinks...");
            orchestrator.initialize();

            log.info("Starting data generation...");
            orchestrator.run();

            log.info("=== Data Generation Complete ===");
        } catch (Exception e) {
            log.error("Fatal error", e);
            if (orchestrator != null) orchestrator.shutdown();
            healthServer.stop();
            System.exit(1);
        }
    }

    /**
     * Register /test-dqr endpoint if a Kafka connection and clickstream topic are available.
     * Finds the clickstream topic name from any generator with "clickstream" in its name
     * that targets a Kafka topic, loads the schema from data/schemas/clickstream_schema.avsc.
     */
    private static void registerDqrEndpoint(ConfigParser config, HealthServer healthServer) {
        ConnectionConfig kafkaConn = config.connections().values().stream()
                .filter(c -> "kafka".equals(c.kind()))
                .findFirst().orElse(null);

        if (kafkaConn == null) {
            log.info("No Kafka connection found — /test-dqr endpoint not registered");
            return;
        }

        String clickstreamTopic = null;
        for (GeneratorConfig gc : config.generators()) {
            if (gc.name() != null && gc.name().contains("clickstream") && gc.isKafka()) {
                clickstreamTopic = gc.topic();
                break;
            }
        }

        if (clickstreamTopic == null) {
            clickstreamTopic = "clickstream";
            log.info("/test-dqr using default topic: {}", clickstreamTopic);
        }

        Schema clickstreamSchema = loadClickstreamSchema();
        if (clickstreamSchema == null) {
            log.warn("Could not load clickstream schema — /test-dqr endpoint not registered");
            return;
        }

        healthServer.registerEndpoint("/test-dqr",
                new DqrTestHandler(kafkaConn, clickstreamTopic, clickstreamSchema));
        log.info("/test-dqr endpoint registered (topic: {})", clickstreamTopic);
    }

    private static Schema loadClickstreamSchema() {
        String[] searchPaths = {
            "/home/data/schemas/clickstream_schema.avsc",
            "data/schemas/clickstream_schema.avsc",
            "../../data/schemas/clickstream_schema.avsc"
        };
        for (String path : searchPaths) {
            File f = new File(path);
            if (f.exists()) {
                try {
                    return new Schema.Parser().parse(f);
                } catch (Exception e) {
                    log.warn("Failed to parse schema at {}: {}", path, e.getMessage());
                }
            }
        }
        return null;
    }

    private static String parseConfigPath(String[] args) {
        for (int i = 0; i < args.length; i++) {
            if ("--config".equals(args[i]) && i + 1 < args.length) {
                return args[i + 1];
            }
        }
        // Default config path (legacy convention)
        return "/home/data/java-datagen-configuration.json";
    }
}
