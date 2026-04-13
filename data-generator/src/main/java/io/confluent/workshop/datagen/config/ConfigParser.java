package io.confluent.workshop.datagen.config;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.IOException;
import java.util.*;

/**
 * Parses the root Java Datagen configuration JSON, recursively resolving
 * loadJsonFile references into fully expanded generator and connection objects.
 */
public class ConfigParser {

    private static final Logger log = LoggerFactory.getLogger(ConfigParser.class);
    private static final ObjectMapper mapper = new ObjectMapper();

    private final List<GeneratorConfig> generators = new ArrayList<>();
    private final Map<String, ConnectionConfig> connections = new LinkedHashMap<>();
    private final List<List<String>> stages = new ArrayList<>();

    public ConfigParser(String configPath) throws IOException {
        Map<String, Object> root = readJson(configPath);
        parseGenerators(root);
        parseConnections(root);
        parseSchedule(root);
    }

    @SuppressWarnings("unchecked")
    private void parseGenerators(Map<String, Object> root) throws IOException {
        List<Object> gens = (List<Object>) root.get("generators");
        if (gens == null) return;

        for (Object g : gens) {
            Map<String, Object> node = (Map<String, Object>) g;
            Map<String, Object> resolved = resolveNode(node);
            GeneratorConfig gc = GeneratorConfig.from(resolved);
            generators.add(gc);
            log.info("  Loaded generator: {}", gc.name());
        }
    }

    @SuppressWarnings("unchecked")
    private void parseConnections(Map<String, Object> root) throws IOException {
        Map<String, Object> conns = (Map<String, Object>) root.get("connections");
        if (conns == null) return;

        for (Map.Entry<String, Object> entry : conns.entrySet()) {
            Map<String, Object> node = (Map<String, Object>) entry.getValue();
            Map<String, Object> resolved = resolveNode(node);
            connections.put(entry.getKey(), ConnectionConfig.from(entry.getKey(), resolved));
            log.info("  Loaded connection: {} (kind={})", entry.getKey(), resolved.get("kind"));
        }
    }

    @SuppressWarnings("unchecked")
    private void parseSchedule(Map<String, Object> root) {
        Map<String, Object> schedule = (Map<String, Object>) root.get("schedule");
        if (schedule == null) {
            List<String> allNames = generators.stream().map(GeneratorConfig::name).toList();
            stages.add(allNames);
            return;
        }

        List<Map<String, Object>> stageList = (List<Map<String, Object>>) schedule.get("stages");
        for (Map<String, Object> stage : stageList) {
            List<String> names = (List<String>) stage.get("generators");
            stages.add(names);
        }
    }

    /**
     * If a node is a loadJsonFile directive, loads and returns the file contents.
     * Otherwise returns the node unchanged.
     */
    @SuppressWarnings("unchecked")
    private Map<String, Object> resolveNode(Map<String, Object> node) throws IOException {
        if ("loadJsonFile".equals(node.get("_gen"))) {
            String filePath = (String) node.get("file");
            return readJson(filePath);
        }
        return node;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> readJson(String path) throws IOException {
        return mapper.readValue(new File(path), new TypeReference<>() {});
    }

    /**
     * Reads a JSON file and returns its content as a raw object (can be list or map).
     */
    public static Object readJsonRaw(String path) throws IOException {
        return mapper.readValue(new File(path), Object.class);
    }

    public List<GeneratorConfig> generators() { return generators; }
    public Map<String, ConnectionConfig> connections() { return connections; }
    public List<List<String>> stages() { return stages; }
}
