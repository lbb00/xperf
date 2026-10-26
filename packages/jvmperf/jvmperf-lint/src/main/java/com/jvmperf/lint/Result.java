package com.jvmperf.lint;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public class Result {
    public final List<Finding> findings;
    public final int syntaxErrors;
    public final List<Map<String, Object>> syntaxErrorLocations;

    public Result(List<Finding> findings, int syntaxErrors, List<Map<String, Object>> locations) {
        this.findings = findings;
        this.syntaxErrors = syntaxErrors;
        this.syntaxErrorLocations = locations;
    }

    public static Result empty() {
        return new Result(List.of(), 0, List.of());
    }
}
