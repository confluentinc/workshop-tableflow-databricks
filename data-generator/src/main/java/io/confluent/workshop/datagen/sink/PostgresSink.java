package io.confluent.workshop.datagen.sink;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import io.confluent.workshop.datagen.config.ConnectionConfig;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.util.Map;
import java.util.Set;
import java.util.StringJoiner;
import java.util.concurrent.ConcurrentHashMap;

public class PostgresSink implements Sink {

    private static final Logger log = LoggerFactory.getLogger(PostgresSink.class);
    private final HikariDataSource dataSource;
    private final String tablePolicy;
    private final Set<String> ensuredTables = ConcurrentHashMap.newKeySet();

    public PostgresSink(ConnectionConfig config) {
        Map<String, Object> cc = config.connectionConfigs();

        HikariConfig hc = new HikariConfig();
        hc.setJdbcUrl(String.format("jdbc:postgresql://%s:%s/%s",
                cc.get("host"),
                cc.getOrDefault("port", 5432),
                cc.get("db")));
        hc.setUsername((String) cc.get("username"));
        hc.setPassword((String) cc.get("password"));
        hc.setMaximumPoolSize(5);
        hc.setMinimumIdle(1);
        hc.setConnectionTimeout(30000);

        this.dataSource = new HikariDataSource(hc);
        this.tablePolicy = config.tablePolicy();
        log.info("PostgresSink connected to {}:{}/{} (tablePolicy={})",
                cc.get("host"), cc.getOrDefault("port", 5432), cc.get("db"), tablePolicy);
    }

    /**
     * Create a table from pgHint column definitions if tablePolicy is "create".
     * Idempotent — uses CREATE TABLE IF NOT EXISTS and tracks already-ensured tables.
     */
    public void ensureTableExists(String tableName, Map<String, String> columnDefs) {
        if (!"create".equals(tablePolicy)) return;
        if (!ensuredTables.add(tableName)) return;

        StringJoiner colDefs = new StringJoiner(", ");
        for (Map.Entry<String, String> col : columnDefs.entrySet()) {
            colDefs.add(col.getKey() + " " + col.getValue());
        }

        String schema = tableName.contains(".") ? tableName.substring(0, tableName.indexOf('.')) : null;

        try (Connection conn = dataSource.getConnection();
             Statement stmt = conn.createStatement()) {
            if (schema != null) {
                stmt.execute("CREATE SCHEMA IF NOT EXISTS " + schema);
            }
            String ddl = String.format("CREATE TABLE IF NOT EXISTS %s (%s)", tableName, colDefs);
            stmt.execute(ddl);
            log.info("Ensured table exists: {}", tableName);
        } catch (SQLException e) {
            log.warn("Failed to auto-create table {} (may already exist): {}", tableName, e.getMessage());
        }
    }

    @Override
    public void write(Map<String, Object> fields) throws Exception {
        throw new UnsupportedOperationException(
                "Use write(table, fields) -- table is required for Postgres inserts");
    }

    public void write(String table, Map<String, Object> fields) throws SQLException {
        StringJoiner columns = new StringJoiner(", ");
        StringJoiner placeholders = new StringJoiner(", ");

        for (String col : fields.keySet()) {
            columns.add(col);
            placeholders.add("?");
        }

        String sql = String.format("INSERT INTO %s (%s) VALUES (%s)",
                table, columns, placeholders);

        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            for (Object value : fields.values()) {
                setParameter(ps, idx++, value);
            }
            ps.executeUpdate();
        }
    }

    @Override
    public void writeUpdate(Map<String, Object> setFields, Map<String, Object> whereFields)
            throws Exception {
        throw new UnsupportedOperationException(
                "Use writeUpdate(table, setFields, whereFields)");
    }

    public void writeUpdate(String table, Map<String, Object> setFields,
                            Map<String, Object> whereFields) throws SQLException {
        StringJoiner setClauses = new StringJoiner(", ");
        for (String col : setFields.keySet()) {
            setClauses.add(col + " = ?");
        }

        StringJoiner whereClauses = new StringJoiner(" AND ");
        for (String col : whereFields.keySet()) {
            whereClauses.add(col + " = ?");
        }

        String sql = String.format("UPDATE %s SET %s WHERE %s",
                table, setClauses, whereClauses);

        try (Connection conn = dataSource.getConnection();
             PreparedStatement ps = conn.prepareStatement(sql)) {
            int idx = 1;
            for (Object value : setFields.values()) {
                setParameter(ps, idx++, value);
            }
            for (Object value : whereFields.values()) {
                setParameter(ps, idx++, value);
            }
            ps.executeUpdate();
        }
    }

    private void setParameter(PreparedStatement ps, int idx, Object value) throws SQLException {
        if (value == null) {
            ps.setNull(idx, java.sql.Types.NULL);
        } else if (value instanceof String s) {
            ps.setString(idx, s);
        } else if (value instanceof Integer i) {
            ps.setInt(idx, i);
        } else if (value instanceof Long l) {
            ps.setLong(idx, l);
        } else if (value instanceof Double d) {
            ps.setDouble(idx, d);
        } else if (value instanceof Timestamp ts) {
            ps.setTimestamp(idx, ts);
        } else if (value instanceof Number n) {
            ps.setDouble(idx, n.doubleValue());
        } else {
            ps.setString(idx, value.toString());
        }
    }

    @Override
    public void flush() {
        // JDBC auto-commits, nothing to flush
    }

    @Override
    public void close() {
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
            log.info("PostgresSink closed");
        }
    }
}
