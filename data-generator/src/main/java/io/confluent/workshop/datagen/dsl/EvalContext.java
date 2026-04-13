package io.confluent.workshop.datagen.dsl;

import io.confluent.workshop.datagen.engine.LookupRegistry;

import java.util.*;

/**
 * Evaluation context for a single generator. Holds varsOnce (computed once at
 * generator start), vars (recomputed per event), and a reference to the global
 * lookup registry for cross-generator data access.
 */
public class EvalContext {

    private final Map<String, Object> varsOnceValues = new LinkedHashMap<>();
    private final Map<String, Object> varsValues = new LinkedHashMap<>();
    private final LookupRegistry lookupRegistry;

    public EvalContext(LookupRegistry lookupRegistry) {
        this.lookupRegistry = lookupRegistry;
    }

    public void putVarsOnce(String key, Object value) {
        varsOnceValues.put(key, value);
    }

    public void putVar(String key, Object value) {
        varsValues.put(key, value);
    }

    public void clearVars() {
        varsValues.clear();
    }

    /**
     * Resolve a variable name. Vars take precedence over varsOnce.
     */
    public Object getVariable(String name) {
        if (varsValues.containsKey(name)) return varsValues.get(name);
        if (varsOnceValues.containsKey(name)) return varsOnceValues.get(name);
        return null;
    }

    public boolean hasVariable(String name) {
        return varsValues.containsKey(name) || varsOnceValues.containsKey(name);
    }

    public LookupRegistry lookupRegistry() {
        return lookupRegistry;
    }

    /**
     * Returns all variable names (both varsOnce and vars) for string interpolation.
     */
    public Set<String> allVariableNames() {
        Set<String> names = new LinkedHashSet<>(varsOnceValues.keySet());
        names.addAll(varsValues.keySet());
        return names;
    }
}
