package io.confluent.workshop.datagen.health;

import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Lightweight HTTP server exposing Prometheus-compatible metrics on port 9400.
 * Compatible with existing CloudWatch/Azure Monitor collection scripts.
 * Also supports registering additional endpoints (e.g. /test-dqr).
 */
public class HealthServer {

    private static final Logger log = LoggerFactory.getLogger(HealthServer.class);
    private static final int DEFAULT_PORT = 9400;

    private final AtomicLong eventsSentTotal = new AtomicLong(0);
    private final AtomicLong eventsFailedTotal = new AtomicLong(0);
    private HttpServer server;

    public void start() throws IOException {
        start(DEFAULT_PORT);
    }

    public void start(int port) throws IOException {
        server = HttpServer.create(new InetSocketAddress(port), 0);

        server.createContext("/", exchange -> {
            String metrics = buildMetrics();
            byte[] body = metrics.getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "text/plain; charset=utf-8");
            exchange.sendResponseHeaders(200, body.length);
            try (OutputStream os = exchange.getResponseBody()) {
                os.write(body);
            }
        });

        server.setExecutor(null);
        server.start();
        log.info("Health server started on port {}", port);
    }

    public void registerEndpoint(String path, HttpHandler handler) {
        if (server != null) {
            server.createContext(path, handler);
            log.info("Registered endpoint: {}", path);
        }
    }

    private String buildMetrics() {
        long sent = eventsSentTotal.get();
        long failed = eventsFailedTotal.get();
        return String.format("""
                # HELP datagen_events_sent_total Total events successfully written
                # TYPE datagen_events_sent_total counter
                datagen_events_sent_total %d
                # HELP datagen_events_failed_total Total events that failed to write
                # TYPE datagen_events_failed_total counter
                datagen_events_failed_total %d
                """, sent, failed);
    }

    public void incrementEventsSent() {
        eventsSentTotal.incrementAndGet();
    }

    public void incrementEventsFailed() {
        eventsFailedTotal.incrementAndGet();
    }

    public void stop() {
        if (server != null) {
            server.stop(1);
            log.info("Health server stopped");
        }
    }
}
