package io.confluent.workshop.datagen.engine;

import io.confluent.workshop.datagen.config.GeneratorConfig;
import io.confluent.workshop.datagen.dsl.DslEvaluator;
import io.confluent.workshop.datagen.dsl.EvalContext;
import io.confluent.workshop.datagen.health.HealthServer;
import io.confluent.workshop.datagen.sink.KafkaSink;
import io.confluent.workshop.datagen.sink.PostgresSink;
import org.apache.avro.Schema;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;

/**
 * Runs a single generator, producing events until maxEvents is reached or the
 * generator is interrupted. Handles varsOnce initialization, per-event vars
 * evaluation, throttling, and writing to the appropriate sink.
 */
public class GeneratorRunner {

    private static final Logger log = LoggerFactory.getLogger(GeneratorRunner.class);

    private final GeneratorConfig config;
    private final DslEvaluator evaluator;
    private final EvalContext context;
    private final PostgresSink postgresSink;
    private final KafkaSink kafkaSink;
    private final HealthServer healthServer;
    private int eventCount = 0;
    private boolean varsOnceInitialized = false;
    private Schema avroSchema;

    public GeneratorRunner(GeneratorConfig config, DslEvaluator evaluator,
                           EvalContext context, PostgresSink postgresSink,
                           KafkaSink kafkaSink, HealthServer healthServer) {
        this.config = config;
        this.evaluator = evaluator;
        this.context = context;
        this.postgresSink = postgresSink;
        this.kafkaSink = kafkaSink;
        this.healthServer = healthServer;
    }

    /**
     * Initialize varsOnce (called once before the first event).
     */
    @SuppressWarnings("unchecked")
    public void initVarsOnce() {
        if (varsOnceInitialized) return;
        varsOnceInitialized = true;

        Map<String, Object> varsOnce = config.varsOnce();
        if (varsOnce != null) {
            for (Map.Entry<String, Object> entry : varsOnce.entrySet()) {
                Object value = evaluator.evaluate(entry.getValue(), context);
                context.putVarsOnce(entry.getKey(), value);
            }
        }

        if (config.isKafka() && config.avroSchemaHint() != null) {
            Object schemaObj = evaluator.evaluate(config.avroSchemaHint(), context);
            if (schemaObj instanceof Map<?, ?> schemaMap) {
                String schemaJson = new com.fasterxml.jackson.databind.ObjectMapper()
                        .valueToTree(schemaObj).toString();
                avroSchema = new Schema.Parser().parse(schemaJson);
            } else if (schemaObj instanceof String s) {
                avroSchema = new Schema.Parser().parse(s);
            }
        }
    }

    /**
     * Produce a single event. Returns true if the generator should continue,
     * false if maxEvents has been reached.
     */
    public boolean produceOne() {
        if (eventCount >= config.maxEvents()) {
            return false;
        }

        try {
            // Evaluate per-event vars
            context.clearVars();
            Map<String, Object> vars = config.vars();
            if (vars != null) {
                for (Map.Entry<String, Object> entry : vars.entrySet()) {
                    Object value = evaluator.evaluate(entry.getValue(), context);
                    context.putVar(entry.getKey(), value);
                }
            }

            // Evaluate output fields
            Map<String, Object> outputFields = config.outputFields();
            Map<String, Object> evaluated = new LinkedHashMap<>();
            for (Map.Entry<String, Object> entry : outputFields.entrySet()) {
                Object value = evaluator.evaluate(entry.getValue(), context);
                evaluated.put(entry.getKey(), value);
            }

            // Write to sink
            if (config.isPostgres()) {
                writeToPostgres(evaluated);
            } else if (config.isKafka()) {
                writeToKafka(evaluated);
            }

            // Record in lookup registry for cross-generator lookups
            Map<String, Object> lookupData = new LinkedHashMap<>();
            if (config.isPostgres()) {
                lookupData.put("row", evaluated);
            } else {
                lookupData.put("value", evaluated);
            }
            context.lookupRegistry().record(config.name(), lookupData);

            eventCount++;
            if (healthServer != null) healthServer.incrementEventsSent();

            if (eventCount % 500 == 0 || eventCount == config.maxEvents()) {
                log.info("  {} events: {}/{}", config.name(), eventCount, config.maxEvents());
            }

            return eventCount < config.maxEvents();
        } catch (Exception e) {
            log.error("Error producing event for {}: {}", config.name(), e.getMessage(), e);
            if (healthServer != null) healthServer.incrementEventsFailed();
            return true; // Continue on error
        }
    }

    private void writeToPostgres(Map<String, Object> evaluated) throws Exception {
        if (postgresSink == null) {
            throw new IllegalStateException("No Postgres sink for generator: " + config.name());
        }

        if (config.isUpdate()) {
            // Evaluate WHERE clause fields
            Map<String, Object> whereFields = new LinkedHashMap<>();
            if (config.where() != null) {
                for (Map.Entry<String, Object> entry : config.where().entrySet()) {
                    Object value = evaluator.evaluate(entry.getValue(), context);
                    whereFields.put(entry.getKey(), value);
                }
            }
            postgresSink.writeUpdate(config.table(), evaluated, whereFields);
        } else {
            postgresSink.write(config.table(), evaluated);
        }
    }

    private void writeToKafka(Map<String, Object> evaluated) throws Exception {
        if (kafkaSink == null) {
            throw new IllegalStateException("No Kafka sink for generator: " + config.name());
        }
        if (avroSchema == null) {
            throw new IllegalStateException(
                    "No Avro schema for Kafka generator: " + config.name());
        }
        int partitions = config.partitions() > 0 ? config.partitions() : 1;
        kafkaSink.write(config.topic(), evaluated, avroSchema, partitions);
    }

    /**
     * Evaluate and return the throttle delay in milliseconds, or -1 if none.
     */
    public long evaluateThrottleMs() {
        Object throttle = config.throttleMs();
        if (throttle == null) return -1;

        Object result = evaluator.evaluate(throttle, context);
        if (result instanceof Number n) {
            return n.longValue();
        }
        return -1;
    }

    public boolean isFinished() {
        return eventCount >= config.maxEvents();
    }

    public String name() {
        return config.name();
    }

    public int eventCount() {
        return eventCount;
    }
}
