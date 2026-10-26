package com.jvmperf.lint;

import java.util.LinkedHashMap;
import java.util.Map;

public record Finding(String file, int line, int column, String rule, String detail) {
    public Map<String, Object> toMap() {
        Rule r = Rule.BY_CODE.get(rule);
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("file", file);
        m.put("line", line);
        m.put("column", column);
        m.put("rule", r.code());
        m.put("name", r.name());
        m.put("severity", r.severity());
        m.put("message_zh", r.msgZh());
        m.put("message_en", r.msgEn());
        m.put("detail", detail);
        m.put("fix", r.fix());
        m.put("source_group", Engine.sourceGroup(file));
        return m;
    }
}
