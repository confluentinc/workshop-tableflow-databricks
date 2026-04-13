package io.confluent.workshop.datagen.dsl;

import io.confluent.workshop.datagen.config.ConfigParser;
import net.datafaker.Faker;
import net.objecthunter.exp4j.ExpressionBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicLong;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Recursively evaluates Java Datagen DSL nodes. Each node with a "_gen" key
 * dispatches to the corresponding function implementation.
 */
public class DslEvaluator {

    private static final Logger log = LoggerFactory.getLogger(DslEvaluator.class);
    private static final Pattern VAR_INTERPOLATION = Pattern.compile("#\\{([^}]+)}");

    private final Faker faker = new Faker();

    // Per-generator sequential counters keyed by "generatorName:fieldPath"
    private final Map<String, AtomicLong> sequentialCounters = new HashMap<>();

    @SuppressWarnings("unchecked")
    public Object evaluate(Object node, EvalContext ctx) {
        if (node == null) return null;

        if (node instanceof Map<?, ?> mapNode) {
            Map<String, Object> map = (Map<String, Object>) mapNode;
            String gen = (String) map.get("_gen");

            if (gen != null) {
                Object result = evaluateGen(gen, map, ctx);
                return applyModifiers(result, map, ctx);
            }

            // Plain map: evaluate each value recursively
            Map<String, Object> result = new LinkedHashMap<>();
            for (Map.Entry<String, Object> entry : map.entrySet()) {
                result.put(entry.getKey(), evaluate(entry.getValue(), ctx));
            }
            return result;
        }

        if (node instanceof List<?> list) {
            List<Object> result = new ArrayList<>();
            for (Object item : list) {
                result.add(evaluate(item, ctx));
            }
            return result;
        }

        // Primitives pass through
        return node;
    }

    @SuppressWarnings("unchecked")
    private Object evaluateGen(String gen, Map<String, Object> node, EvalContext ctx) {
        return switch (gen) {
            case "now" -> System.currentTimeMillis();

            case "math" -> evalMath(node, ctx);

            case "sequentialString" -> evalSequentialString(node);

            case "sequentialInteger" -> evalSequentialInteger(node);

            case "string" -> evalString(node, ctx);

            case "uniformDistribution" -> evalUniformDistribution(node, ctx);

            case "normalDistribution" -> evalNormalDistribution(node);

            case "oneOf" -> evalOneOf(node, ctx);

            case "weightedOneOf" -> evalWeightedOneOf(node, ctx);

            case "var" -> evalVar(node, ctx);

            case "lookup" -> evalLookup(node, ctx);

            case "histogram" -> evalHistogram(node);

            case "min" -> evalMin(node, ctx);

            case "loadJsonFile" -> evalLoadJsonFile(node);

            case "boolean" -> ThreadLocalRandom.current().nextBoolean();

            case "uuid" -> UUID.randomUUID().toString();

            case "constant" -> evaluate(node.get("x"), ctx);

            default -> throw new IllegalArgumentException("Unknown _gen function: " + gen);
        };
    }

    // --- Function implementations ---

    private Object evalMath(Map<String, Object> node, EvalContext ctx) {
        String expr = (String) node.get("expr");

        // Collect all variable names and values for substitution
        Set<String> varNames = ctx.allVariableNames();
        Map<String, Double> varValues = new HashMap<>();

        for (String name : varNames) {
            Object val = ctx.getVariable(name);
            if (val instanceof Number n) {
                varValues.put(name, n.doubleValue());
            }
        }

        try {
            ExpressionBuilder builder = new ExpressionBuilder(expr);
            if (!varValues.isEmpty()) {
                builder.variables(varValues.keySet());
            }
            var expression = builder.build();
            for (Map.Entry<String, Double> entry : varValues.entrySet()) {
                expression.setVariable(entry.getKey(), entry.getValue());
            }
            double result = expression.evaluate();

            // Return long if no decimal places specified and result is integral
            Object decimals = node.get("decimals");
            if (decimals != null) {
                int dp = ((Number) decimals).intValue();
                if (dp == 0) return (long) result;
                return round(result, dp);
            }
            if (result == Math.floor(result) && !Double.isInfinite(result)) {
                return (long) result;
            }
            return result;
        } catch (Exception e) {
            throw new IllegalStateException("Failed to evaluate math expression: " + expr, e);
        }
    }

    private Object evalSequentialString(Map<String, Object> node) {
        long startingFrom = ((Number) node.get("startingFrom")).longValue();
        String exprTemplate = (String) node.get("expr");

        String counterKey = "seq:" + exprTemplate + ":" + startingFrom;
        AtomicLong counter = sequentialCounters.computeIfAbsent(counterKey,
                k -> new AtomicLong(startingFrom));

        long value = counter.getAndIncrement();
        return exprTemplate.replace("~d", String.valueOf(value));
    }

    private Object evalSequentialInteger(Map<String, Object> node) {
        long startingFrom = node.containsKey("startingFrom")
                ? ((Number) node.get("startingFrom")).longValue() : 0;
        String counterKey = "seqint:" + startingFrom;
        AtomicLong counter = sequentialCounters.computeIfAbsent(counterKey,
                k -> new AtomicLong(startingFrom));
        return counter.getAndIncrement();
    }

    /**
     * Evaluates a string expression with dual resolution:
     * 1. #{varName} references are resolved from EvalContext
     * 2. Remaining #{Provider.method} references go to Datafaker
     */
    private Object evalString(Map<String, Object> node, EvalContext ctx) {
        String expr = (String) node.get("expr");

        // First pass: substitute known variables
        StringBuffer sb = new StringBuffer();
        Matcher m = VAR_INTERPOLATION.matcher(expr);
        while (m.find()) {
            String ref = m.group(1);
            if (ctx.hasVariable(ref)) {
                Object val = ctx.getVariable(ref);
                m.appendReplacement(sb, Matcher.quoteReplacement(String.valueOf(val)));
            }
            // Leave Faker expressions as-is for second pass
        }
        m.appendTail(sb);
        String intermediate = sb.toString();

        // Second pass: evaluate any remaining #{...} as Faker expressions
        if (intermediate.contains("#{")) {
            try {
                return faker.expression(intermediate);
            } catch (Exception e) {
                // If Faker can't resolve it, return as-is
                return intermediate;
            }
        }
        return intermediate;
    }

    @SuppressWarnings("unchecked")
    private Object evalUniformDistribution(Map<String, Object> node, EvalContext ctx) {
        Object boundsObj = node.get("bounds");
        List<Object> bounds;

        if (boundsObj instanceof List<?> list) {
            bounds = new ArrayList<>();
            for (Object b : list) {
                bounds.add(evaluate(b, ctx));
            }
        } else {
            throw new IllegalArgumentException("uniformDistribution requires bounds array");
        }

        double min = ((Number) bounds.get(0)).doubleValue();
        double max = ((Number) bounds.get(1)).doubleValue();
        double value = min + (max - min) * ThreadLocalRandom.current().nextDouble();

        Object decimals = node.get("decimals");
        if (decimals != null) {
            int dp = ((Number) decimals).intValue();
            if (dp == 0) return (long) value;
            return round(value, dp);
        }
        return value;
    }

    private Object evalNormalDistribution(Map<String, Object> node) {
        double mean = ((Number) node.get("mean")).doubleValue();
        double sd = ((Number) node.get("sd")).doubleValue();
        double value = mean + sd * ThreadLocalRandom.current().nextGaussian();

        // Apply clamp
        Object clampObj = node.get("clamp");
        if (clampObj instanceof List<?> clamp) {
            double lo = ((Number) clamp.get(0)).doubleValue();
            double hi = ((Number) clamp.get(1)).doubleValue();
            value = Math.max(lo, Math.min(hi, value));
        }

        Object decimals = node.get("decimals");
        if (decimals != null) {
            int dp = ((Number) decimals).intValue();
            if (dp == 0) return (long) value;
            return round(value, dp);
        }
        return value;
    }

    @SuppressWarnings("unchecked")
    private Object evalOneOf(Map<String, Object> node, EvalContext ctx) {
        Object choicesObj = node.get("choices");

        // choices can be a _gen expression that resolves to a list (e.g., var reference)
        Object resolved = evaluate(choicesObj, ctx);

        if (resolved instanceof List<?> choices) {
            if (choices.isEmpty()) return null;
            Object chosen = choices.get(ThreadLocalRandom.current().nextInt(choices.size()));
            return evaluate(chosen, ctx);
        }
        return resolved;
    }

    @SuppressWarnings("unchecked")
    private Object evalWeightedOneOf(Map<String, Object> node, EvalContext ctx) {
        List<Map<String, Object>> choices = (List<Map<String, Object>>) node.get("choices");

        int totalWeight = 0;
        for (Map<String, Object> choice : choices) {
            totalWeight += ((Number) choice.get("weight")).intValue();
        }

        int roll = ThreadLocalRandom.current().nextInt(totalWeight);
        int cumulative = 0;
        for (Map<String, Object> choice : choices) {
            cumulative += ((Number) choice.get("weight")).intValue();
            if (roll < cumulative) {
                return evaluate(choice.get("value"), ctx);
            }
        }
        return evaluate(choices.getLast().get("value"), ctx);
    }

    @SuppressWarnings("unchecked")
    private Object evalVar(Map<String, Object> node, EvalContext ctx) {
        String varName = (String) node.get("var");
        Object value = ctx.getVariable(varName);
        if (value == null) {
            throw new IllegalStateException("Variable not found: " + varName);
        }

        // Navigate path if specified
        List<String> path = (List<String>) node.get("path");
        if (path != null && !path.isEmpty()) {
            value = navigatePath(value, path);
        }

        return value;
    }

    @SuppressWarnings("unchecked")
    private Object evalLookup(Map<String, Object> node, EvalContext ctx) {
        String name = (String) node.get("name");
        List<String> path = (List<String>) node.get("path");

        Object histogramNode = node.get("histogram");
        if (histogramNode != null) {
            Map<String, Object> histMap = (Map<String, Object>) histogramNode;
            // Resolve the histogram (it's a _gen:histogram node)
            Object resolved = evaluate(histMap, ctx);
            if (resolved instanceof List<?> bins) {
                return ctx.lookupRegistry().lookupWithHistogram(
                        name, path, (List<Map<String, Object>>) bins);
            }
        }

        return ctx.lookupRegistry().lookupRandom(name, path);
    }

    @SuppressWarnings("unchecked")
    private Object evalHistogram(Map<String, Object> node) {
        // Returns the bins list as-is for use by lookup
        return node.get("bins");
    }

    @SuppressWarnings("unchecked")
    private Object evalMin(Map<String, Object> node, EvalContext ctx) {
        List<Object> args = (List<Object>) node.get("args");
        double minVal = Double.MAX_VALUE;

        for (Object arg : args) {
            Object evaluated = evaluate(arg, ctx);
            if (evaluated instanceof Number n) {
                minVal = Math.min(minVal, n.doubleValue());
            }
        }

        if (minVal == Math.floor(minVal) && !Double.isInfinite(minVal)) {
            return (long) minVal;
        }
        return minVal;
    }

    private Object evalLoadJsonFile(Map<String, Object> node) {
        String filePath = (String) node.get("file");
        try {
            return ConfigParser.readJsonRaw(filePath);
        } catch (IOException e) {
            throw new IllegalStateException("Failed to load JSON file: " + filePath, e);
        }
    }

    // --- Modifiers ---

    @SuppressWarnings("unchecked")
    private Object applyModifiers(Object result, Map<String, Object> node, EvalContext ctx) {
        // decimals modifier (applied after _gen evaluation)
        Object decimals = node.get("decimals");
        if (decimals != null && result instanceof Number n) {
            int dp = ((Number) decimals).intValue();
            if (dp == 0) {
                result = (long) n.doubleValue();
            } else {
                result = round(n.doubleValue(), dp);
            }
        }

        // clamp modifier
        Object clampObj = node.get("clamp");
        if (clampObj instanceof List<?> clamp && result instanceof Number n) {
            double lo = ((Number) clamp.get(0)).doubleValue();
            double hi = ((Number) clamp.get(1)).doubleValue();
            double val = Math.max(lo, Math.min(hi, n.doubleValue()));
            result = (val == Math.floor(val)) ? (long) val : val;
        }

        // serialize modifier
        Object serialize = node.get("serialize");
        if (serialize instanceof Map<?, ?> serMap) {
            String type = (String) ((Map<String, Object>) serMap).get("type");
            if ("postgresTimestamp".equals(type) && result instanceof Number n) {
                result = Timestamp.from(Instant.ofEpochMilli(n.longValue()));
            }
        }

        // path modifier (for var, applied after base evaluation)
        // Already handled in evalVar, skip here

        return result;
    }

    // --- Helpers ---

    @SuppressWarnings("unchecked")
    private Object navigatePath(Object obj, List<String> path) {
        Object current = obj;
        for (String key : path) {
            if (current instanceof Map<?, ?> map) {
                current = map.get(key);
            } else {
                return null;
            }
        }
        return current;
    }

    private double round(double value, int decimals) {
        return BigDecimal.valueOf(value)
                .setScale(decimals, RoundingMode.HALF_UP)
                .doubleValue();
    }

    /**
     * Reset sequential counters (for testing or re-initialization).
     */
    public void resetCounters() {
        sequentialCounters.clear();
    }
}
