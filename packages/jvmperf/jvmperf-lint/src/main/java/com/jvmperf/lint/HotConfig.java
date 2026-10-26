package com.jvmperf.lint;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

public class HotConfig {
    public Set<String> callbacks = new HashSet<>(HotAnalysis.HOT_CALLBACKS);
    public Set<String> registrars = new HashSet<>(HotAnalysis.HOT_REGISTRARS);
    public Pattern hotFnRe = null;
    public boolean propagate = true;
    /** (class/object, function) -> reason from CLI first pass */
    public Map<HotAnalysis.ClassFn, String> external = new HashMap<>();

    public static final HotConfig CONFIG = new HotConfig();
}
