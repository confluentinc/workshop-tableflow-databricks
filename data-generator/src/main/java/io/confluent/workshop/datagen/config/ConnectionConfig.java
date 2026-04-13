package io.confluent.workshop.datagen.config;

import java.util.Map;

public record ConnectionConfig(String name, String kind, Map<String, Object> raw) {

    @SuppressWarnings("unchecked")
    public static ConnectionConfig from(String name, Map<String, Object> raw) {
        String kind = (String) raw.get("kind");
        return new ConnectionConfig(name, kind, raw);
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> connectionConfigs() {
        return (Map<String, Object>) raw.get("connectionConfigs");
    }

    @SuppressWarnings("unchecked")
    public Map<String, Object> producerConfigs() {
        return (Map<String, Object>) raw.get("producerConfigs");
    }

    public String tablePolicy() {
        return (String) raw.getOrDefault("tablePolicy", "create");
    }

    public String logLevel() {
        return (String) raw.getOrDefault("logLevel", "ERROR");
    }
}
