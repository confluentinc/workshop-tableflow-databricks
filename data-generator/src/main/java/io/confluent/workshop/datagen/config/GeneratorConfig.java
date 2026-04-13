package io.confluent.workshop.datagen.config;

import java.util.LinkedHashMap;
import java.util.Map;

public record GeneratorConfig(
        String name,
        String connection,
        String table,
        String topic,
        String op,
        Map<String, Object> row,
        Map<String, Object> value,
        Map<String, Object> where,
        Map<String, Object> vars,
        Map<String, Object> varsOnce,
        Map<String, Object> localConfigs,
        Map<String, Object> rawNode) {

    @SuppressWarnings("unchecked")
    public static GeneratorConfig from(Map<String, Object> node) {
        return new GeneratorConfig(
                (String) node.get("name"),
                (String) node.get("connection"),
                (String) node.get("table"),
                (String) node.get("topic"),
                (String) node.get("op"),
                (Map<String, Object>) node.get("row"),
                (Map<String, Object>) node.get("value"),
                (Map<String, Object>) node.get("where"),
                (Map<String, Object>) node.get("vars"),
                (Map<String, Object>) node.get("varsOnce"),
                (Map<String, Object>) node.get("localConfigs"),
                node);
    }

    public boolean isPostgres() {
        return table != null;
    }

    public boolean isKafka() {
        return topic != null;
    }

    public boolean isUpdate() {
        return "update".equals(op);
    }

    public Map<String, Object> outputFields() {
        return isPostgres() ? row : value;
    }

    public int maxEvents() {
        if (localConfigs == null) return Integer.MAX_VALUE;
        Object me = localConfigs.get("maxEvents");
        if (me instanceof Number n) return n.intValue();
        return Integer.MAX_VALUE;
    }

    public Object throttleMs() {
        if (localConfigs == null) return null;
        return localConfigs.get("throttleMs");
    }

    public int partitions() {
        if (localConfigs == null) return 0;
        Object p = localConfigs.get("partitions");
        if (p instanceof Number n) return n.intValue();
        return 0;
    }

    public Object avroSchemaHint() {
        if (localConfigs == null) return null;
        @SuppressWarnings("unchecked")
        Map<String, Object> hint = (Map<String, Object>) localConfigs.get("avroSchemaHint");
        if (hint == null) return null;
        return hint.get("value");
    }

    /**
     * Extract column definitions from pgHint annotations in the row map.
     * Returns an ordered map of column_name -> SQL_TYPE (e.g. "VARCHAR(50) PRIMARY KEY").
     * Returns null if this is not a Postgres INSERT generator or no pgHints are present.
     */
    @SuppressWarnings("unchecked")
    public Map<String, String> pgHintColumns() {
        if (!isPostgres() || isUpdate() || row == null) return null;

        Map<String, String> columns = new LinkedHashMap<>();
        for (Map.Entry<String, Object> entry : row.entrySet()) {
            if (entry.getValue() instanceof Map<?, ?> fieldDef) {
                Object hint = ((Map<String, Object>) fieldDef).get("pgHint");
                if (hint instanceof String s) {
                    columns.put(entry.getKey(), s);
                }
            }
        }
        return columns.isEmpty() ? null : columns;
    }
}
