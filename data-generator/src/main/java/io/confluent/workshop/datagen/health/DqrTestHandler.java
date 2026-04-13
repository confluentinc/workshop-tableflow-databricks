package io.confluent.workshop.datagen.health;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import io.confluent.workshop.datagen.config.ConnectionConfig;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.Future;

/**
 * HTTP handler for /test-dqr that produces one valid and one invalid
 * clickstream event directly to Kafka, demonstrating CEL data quality
 * rule enforcement and DLQ routing.
 */
public class DqrTestHandler implements HttpHandler {

    private static final Logger log = LoggerFactory.getLogger(DqrTestHandler.class);

    private final ConnectionConfig kafkaConfig;
    private final String clickstreamTopic;
    private final Schema clickstreamSchema;

    public DqrTestHandler(ConnectionConfig kafkaConfig, String clickstreamTopic, Schema clickstreamSchema) {
        this.kafkaConfig = kafkaConfig;
        this.clickstreamTopic = clickstreamTopic;
        this.clickstreamSchema = clickstreamSchema;
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        if (!"GET".equalsIgnoreCase(exchange.getRequestMethod()) &&
            !"POST".equalsIgnoreCase(exchange.getRequestMethod())) {
            sendResponse(exchange, 405, "{\"error\":\"Method not allowed\"}");
            return;
        }

        log.info("DQR test triggered via /test-dqr");
        StringBuilder result = new StringBuilder();
        result.append("{\n  \"test\": \"data-quality-rules\",\n  \"topic\": \"")
              .append(clickstreamTopic).append("\",\n  \"events\": [\n");

        Properties props = new Properties();
        if (kafkaConfig.producerConfigs() != null) {
            props.putAll(kafkaConfig.producerConfigs());
        }
        props.putIfAbsent("key.serializer",
                "org.apache.kafka.common.serialization.StringSerializer");

        try (KafkaProducer<String, GenericRecord> producer = new KafkaProducer<>(props)) {
            // Valid event
            String validResult = produceEvent(producer, "page-view", "valid");
            result.append("    ").append(validResult);

            result.append(",\n");

            // Invalid event (should be routed to DLQ by CEL rule)
            String invalidResult = produceEvent(producer, "admin-access", "invalid");
            result.append("    ").append(invalidResult);

            producer.flush();
        } catch (Exception e) {
            log.error("DQR test failed", e);
            sendResponse(exchange, 500,
                    "{\"error\":\"" + e.getMessage().replace("\"", "'") + "\"}");
            return;
        }

        result.append("\n  ]\n}");
        sendResponse(exchange, 200, result.toString());
    }

    private String produceEvent(KafkaProducer<String, GenericRecord> producer,
                                String action, String label) {
        GenericRecord record = new GenericData.Record(clickstreamSchema);
        record.put("activity_id", "DQR-TEST-" + UUID.randomUUID().toString().substring(0, 8));
        record.put("customer_email", "dqr-test@riverhotel.com");
        record.put("hotel_id", "H100000000");
        record.put("action", action);
        record.put("event_duration", 120);
        record.put("url", "/test/dqr");
        record.put("created_at", System.currentTimeMillis());

        try {
            Future<RecordMetadata> future = producer.send(
                    new ProducerRecord<>(clickstreamTopic, null, record));
            RecordMetadata meta = future.get();
            log.info("DQR test [{}]: action='{}' -> topic={} partition={} offset={}",
                    label, action, meta.topic(), meta.partition(), meta.offset());
            return String.format(
                    "{\"action\":\"%s\",\"label\":\"%s\",\"destination\":\"%s\",\"offset\":%d}",
                    action, label, meta.topic(), meta.offset());
        } catch (Exception e) {
            log.info("DQR test [{}]: action='{}' -> DLQ (rule violation: {})",
                    label, action, e.getMessage());
            return String.format(
                    "{\"action\":\"%s\",\"label\":\"%s\",\"destination\":\"DLQ\",\"reason\":\"%s\"}",
                    action, label, e.getMessage().replace("\"", "'"));
        }
    }

    private void sendResponse(HttpExchange exchange, int status, String body) throws IOException {
        byte[] bytes = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(bytes);
        }
    }
}
