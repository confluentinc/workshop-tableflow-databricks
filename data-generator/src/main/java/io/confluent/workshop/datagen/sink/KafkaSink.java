package io.confluent.workshop.datagen.sink;

import io.confluent.workshop.datagen.config.ConnectionConfig;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.errors.TopicExistsException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;

public class KafkaSink implements Sink {

    private static final Logger log = LoggerFactory.getLogger(KafkaSink.class);
    private static final int DEFAULT_PARTITIONS = 1;
    private static final short DEFAULT_REPLICATION_FACTOR = 3;

    private final KafkaProducer<String, GenericRecord> producer;
    private final AdminClient adminClient;
    private final Set<String> ensuredTopics = ConcurrentHashMap.newKeySet();

    public KafkaSink(ConnectionConfig config) {
        Properties props = new Properties();

        Map<String, Object> producerConfigs = config.producerConfigs();
        if (producerConfigs != null) {
            props.putAll(producerConfigs);
        }

        props.putIfAbsent("key.serializer",
                "org.apache.kafka.common.serialization.StringSerializer");

        props.putIfAbsent("linger.ms", "100");
        props.putIfAbsent("batch.size", "65536");

        // The datagen owns its schemas -- register them on first produce
        props.putIfAbsent("auto.register.schemas", "true");

        this.producer = new KafkaProducer<>(props);

        // AdminClient reuses the same broker connection properties
        Properties adminProps = new Properties();
        if (producerConfigs != null) {
            for (String key : List.of("bootstrap.servers", "sasl.jaas.config",
                    "sasl.mechanism", "security.protocol")) {
                if (producerConfigs.containsKey(key)) {
                    adminProps.put(key, producerConfigs.get(key));
                }
            }
        }
        this.adminClient = AdminClient.create(adminProps);

        log.info("KafkaSink connected to {}", producerConfigs.get("bootstrap.servers"));
    }

    /**
     * Create the topic if it doesn't already exist. Idempotent per topic name
     * within the lifetime of this sink.
     */
    private void ensureTopicExists(String topic, int partitions) {
        if (!ensuredTopics.add(topic)) return;

        NewTopic newTopic = new NewTopic(topic, partitions, DEFAULT_REPLICATION_FACTOR);
        try {
            adminClient.createTopics(Collections.singleton(newTopic)).all().get();
            log.info("Created Kafka topic: {} ({} partitions, RF {})",
                    topic, partitions, DEFAULT_REPLICATION_FACTOR);
        } catch (ExecutionException e) {
            if (e.getCause() instanceof TopicExistsException) {
                log.debug("Topic {} already exists", topic);
            } else {
                log.warn("Could not create topic {}: {}", topic, e.getCause().getMessage());
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            log.warn("Interrupted while creating topic {}", topic);
        }
    }

    public void write(String topic, Map<String, Object> fields, Schema schema, int partitions) throws Exception {
        ensureTopicExists(topic, partitions);

        GenericRecord record = new GenericData.Record(schema);

        for (Map.Entry<String, Object> entry : fields.entrySet()) {
            String fieldName = entry.getKey();
            Object value = entry.getValue();

            Schema.Field schemaField = schema.getField(fieldName);
            if (schemaField == null) continue;

            record.put(fieldName, coerceToAvro(value, schemaField.schema()));
        }

        producer.send(new ProducerRecord<>(topic, null, record));
    }

    /**
     * Coerce a Java value to match the Avro schema type.
     */
    private Object coerceToAvro(Object value, Schema fieldSchema) {
        if (value == null) return null;

        // Handle union types (nullable fields)
        if (fieldSchema.getType() == Schema.Type.UNION) {
            for (Schema unionType : fieldSchema.getTypes()) {
                if (unionType.getType() != Schema.Type.NULL) {
                    return coerceToAvro(value, unionType);
                }
            }
            return value;
        }

        return switch (fieldSchema.getType()) {
            case STRING -> value.toString();
            case INT -> {
                if (value instanceof Number n) yield n.intValue();
                yield Integer.parseInt(value.toString());
            }
            case LONG -> {
                if (value instanceof Number n) yield n.longValue();
                yield Long.parseLong(value.toString());
            }
            case FLOAT -> {
                if (value instanceof Number n) yield n.floatValue();
                yield Float.parseFloat(value.toString());
            }
            case DOUBLE -> {
                if (value instanceof Number n) yield n.doubleValue();
                yield Double.parseDouble(value.toString());
            }
            case BOOLEAN -> {
                if (value instanceof Boolean b) yield b;
                yield Boolean.parseBoolean(value.toString());
            }
            default -> value;
        };
    }

    @Override
    public void write(Map<String, Object> fields) throws Exception {
        throw new UnsupportedOperationException("Use write(topic, fields, schema)");
    }

    @Override
    public void writeUpdate(Map<String, Object> setFields, Map<String, Object> whereFields) {
        throw new UnsupportedOperationException("Kafka does not support updates");
    }

    @Override
    public void flush() throws Exception {
        producer.flush();
    }

    @Override
    public void close() {
        if (producer != null) {
            producer.flush();
            producer.close();
        }
        if (adminClient != null) {
            adminClient.close();
        }
        log.info("KafkaSink closed");
    }
}
