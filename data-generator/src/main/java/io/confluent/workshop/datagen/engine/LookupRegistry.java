package io.confluent.workshop.datagen.engine;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * Stores generated row/value data keyed by generator name, enabling
 * cross-generator lookups (e.g., clickstream referencing customer emails).
 */
public class LookupRegistry {

    private final Map<String, List<Map<String, Object>>> data = new ConcurrentHashMap<>();
    private final Random random = new Random();

    public void record(String generatorName, Map<String, Object> row) {
        data.computeIfAbsent(generatorName, k -> new CopyOnWriteArrayList<>()).add(row);
    }

    public List<Map<String, Object>> getAll(String generatorName) {
        return data.getOrDefault(generatorName, List.of());
    }

    /**
     * Lookup a random row from the named generator, navigating the given path.
     * Returns the value at the path endpoint.
     */
    @SuppressWarnings("unchecked")
    public Object lookupRandom(String generatorName, List<String> path) {
        List<Map<String, Object>> rows = getAll(generatorName);
        if (rows.isEmpty()) {
            throw new IllegalStateException("No data for lookup generator: " + generatorName);
        }
        int index = random.nextInt(rows.size());
        return navigatePath(rows.get(index), path);
    }

    /**
     * Lookup with histogram-based skewed selection.
     * Bin values are widths (e.g., 0.8 + 0.2 = 1.0), not cumulative edges.
     * Frequency values are relative weights for each bin partition.
     * Example: [{bin: 0.8, frequency: 1}, {bin: 0.2, frequency: 0}]
     *   -> all selections come from the first 80% of rows.
     */
    @SuppressWarnings("unchecked")
    public Object lookupWithHistogram(String generatorName, List<String> path,
                                      List<Map<String, Object>> bins) {
        List<Map<String, Object>> rows = getAll(generatorName);
        if (rows.isEmpty()) {
            throw new IllegalStateException("No data for lookup generator: " + generatorName);
        }

        // Build weighted bin selection from frequency values
        double totalFreq = 0;
        for (Map<String, Object> bin : bins) {
            totalFreq += ((Number) bin.get("frequency")).doubleValue();
        }
        if (totalFreq == 0) {
            return navigatePath(rows.get(random.nextInt(rows.size())), path);
        }

        // Select a bin using weighted random
        double roll = random.nextDouble() * totalFreq;
        double cumFreq = 0;
        double cumWidth = 0;
        for (Map<String, Object> bin : bins) {
            double width = ((Number) bin.get("bin")).doubleValue();
            double freq = ((Number) bin.get("frequency")).doubleValue();
            cumFreq += freq;

            if (roll < cumFreq) {
                int startIdx = (int) (cumWidth * rows.size());
                int endIdx = (int) ((cumWidth + width) * rows.size());
                endIdx = Math.min(endIdx, rows.size());
                startIdx = Math.min(startIdx, endIdx - 1);
                startIdx = Math.max(startIdx, 0);
                int idx = startIdx + random.nextInt(Math.max(1, endIdx - startIdx));
                return navigatePath(rows.get(idx), path);
            }
            cumWidth += width;
        }

        int idx = random.nextInt(rows.size());
        return navigatePath(rows.get(idx), path);
    }

    @SuppressWarnings("unchecked")
    private Object navigatePath(Object obj, List<String> path) {
        Object current = obj;
        for (String key : path) {
            if (current instanceof Map<?, ?> map) {
                current = map.get(key);
            } else {
                throw new IllegalStateException(
                        "Cannot navigate path " + path + " through non-map: " + current);
            }
        }
        return current;
    }
}
