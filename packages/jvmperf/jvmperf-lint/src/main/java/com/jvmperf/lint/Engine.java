package com.jvmperf.lint;

import org.treesitter.TSNode;
import org.treesitter.TSTree;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.jvmperf.lint.Ast.*;
import static com.jvmperf.lint.Constants.*;

public final class Engine {
    private Engine() {}

    public static String langOf(String path) {
        if (path.endsWith(".java")) return "java";
        if (path.endsWith(".kt") || path.endsWith(".kts")) return "kotlin";
        return null;
    }

    public static String sourceGroup(String path) {
        String norm = path.replace('\\', '/');
        if (BENCHMARK_PATH_RE.matcher(norm).find()) return "test";
        if (SAMPLE_PATH_RE.matcher(norm).find()) return "test";
        String[] parts = path.split("[/\\\\]+");
        for (int i = 0; i < parts.length - 1; i++) {
            if (TEST_SOURCE_PART.matcher(parts[i]).find()) return "test";
        }
        String stem = parts[parts.length - 1];
        int dot = stem.lastIndexOf('.');
        if (dot > 0) stem = stem.substring(0, dot);
        if (Pattern.compile("(?:Unit)?Tests?$", Pattern.CASE_INSENSITIVE).matcher(stem).find()) return "test";
        for (int i = 0; i < parts.length - 1; i++) {
            if ("smoke".equalsIgnoreCase(parts[i])) return "smoke";
        }
        return "production";
    }

    public static Result lintSource(String path, byte[] src, String lang, Set<String> enabled) {
        return new Linter(path, src, lang, enabled).run();
    }

    public static Map<HotAnalysis.ClassFn, String> collectHotExports(String path, byte[] src, String lang) {
        Linter L = new Linter(path, src, lang, Set.of());
        Set<String> loops = "java".equals(lang) ? JAVA_LOOPS : KT_LOOPS;
        Set<String> funcs = "java".equals(lang) ? JAVA_FUNCS : KT_FUNCS;
        // Seed loops/funcs like rules do
        if ("java".equals(lang)) new JavaRules(L).collectStructure();
        else new KotlinRules(L).collectStructure();
        HotAnalysis H = new HotAnalysis(L, loops, funcs);
        String base = path.contains("/") ? path.substring(path.lastIndexOf('/') + 1) : path;
        Map<HotAnalysis.ClassFn, String> out = new LinkedHashMap<>();
        H.exports.forEach((k, v) -> out.put(k, base + ":" + v));
        return out;
    }

    public static boolean logGuarded(Linter L, TSNode n) {
        TSNode p = parent(n);
        while (p != null && !Set.of("method_declaration", "function_declaration", "lambda_expression",
                "anonymous_function", "getter", "setter").contains(p.getType())) {
            if (typeIs(p, "if_statement") || typeIs(p, "if_expression")) {
                TSNode cond = field(p, "condition");
                String t = cond != null ? text(L.src, cond) : text(L.src, p);
                if (t.length() > 160) t = t.substring(0, 160);
                if (GUARD_RE.matcher(t).find()) return true;
                if (SAMPLE_BRANCH_RE.matcher(t).find()) return true;
            }
            p = parent(p);
        }
        return false;
    }

    public static boolean samplePath(String path) {
        return SAMPLE_PATH_RE.matcher(path.replace('\\', '/')).find();
    }

    public static String enclosingMethodName(Linter L, TSNode n) {
        TSNode fn = L.enclosingFunc(n);
        if (fn == null) return "";
        if (typeIs(fn, "method_declaration") || typeIs(fn, "constructor_declaration")) {
            TSNode nm = field(fn, "name");
            return nm != null ? text(L.src, nm) : "";
        }
        if (typeIs(fn, "function_declaration") || typeIs(fn, "anonymous_function")
                || typeIs(fn, "getter") || typeIs(fn, "setter") || typeIs(fn, "secondary_constructor")) {
            for (TSNode c : children(fn)) {
                if (isIdent(c)) return text(L.src, c);
            }
        }
        return "";
    }

    public static boolean diagnosticMethod(Linter L, TSNode n) {
        String name = enclosingMethodName(L, n);
        return !name.isEmpty() && DIAGNOSTIC_METHOD_RE.matcher(name).matches();
    }

    public static boolean inSignatureOnly(TSNode n) {
        TSNode p = parent(n);
        while (p != null) {
            String ty = p.getType();
            if (Set.of("block", "constructor_body", "function_body", "statements").contains(ty)) {
                TSNode gp = parent(p);
                if (gp != null && Set.of(
                        "method_declaration", "constructor_declaration", "compact_constructor_declaration",
                        "function_declaration", "anonymous_function", "getter", "setter",
                        "secondary_constructor", "lambda_expression").contains(gp.getType())) {
                    return false;
                }
            }
            if (Set.of("formal_parameter", "receiver_parameter", "catch_formal_parameter",
                    "spread_parameter", "parameter", "function_value_parameter",
                    "throws", "super_interfaces", "type_list", "delegation_specifier").contains(ty)) {
                return true;
            }
            if (Set.of("method_declaration", "constructor_declaration", "compact_constructor_declaration",
                    "function_declaration", "secondary_constructor").contains(ty)) {
                return true;
            }
            p = parent(p);
        }
        return false;
    }

    public static String enclosingTypeName(Linter L, TSNode n) {
        TSNode p = parent(n);
        while (p != null) {
            if (typeIs(p, "class_declaration") || typeIs(p, "interface_declaration")
                    || typeIs(p, "enum_declaration") || typeIs(p, "object_declaration")
                    || typeIs(p, "companion_object")) {
                TSNode nm = field(p, "name");
                if (nm != null) return text(L.src, nm);
                for (TSNode c : children(p)) if (isIdent(c)) return text(L.src, c);
                return "";
            }
            p = parent(p);
        }
        return "";
    }

    public static boolean inBuilderType(Linter L, TSNode n) {
        return enclosingTypeName(L, n).endsWith("Builder");
    }

    public static boolean inFunctionalApiTypeArg(Linter L, TSNode g) {
        TSNode p = parent(g);
        while (p != null) {
            if (typeIs(p, "type_arguments")) {
                TSNode gt = parent(p);
                if (gt != null && (typeIs(gt, "generic_type") || typeIs(gt, "user_type"))) {
                    String base;
                    if (typeIs(gt, "generic_type")) {
                        List<TSNode> kids = children(gt);
                        base = kids.isEmpty() ? "" : text(L.src, kids.get(0)).replaceAll(".*\\.", "");
                    } else {
                        base = text(L.src, gt).replaceAll("<.*", "").replaceAll(".*\\.", "");
                    }
                    if (FUNCTIONAL_API_TYPES.contains(base)) return true;
                }
            }
            if (Set.of("field_declaration", "local_variable_declaration", "property_declaration",
                    "method_declaration", "function_declaration", "class_body", "interface_body").contains(p.getType())) {
                break;
            }
            p = parent(p);
        }
        return false;
    }


    public static boolean isStringConcatArg(TSNode arg) {
        TSNode n = arg;
        if (typeIs(n, "value_argument")) {
            List<TSNode> kids = named(n);
            if (!kids.isEmpty()) n = kids.get(kids.size() - 1);
        }
        // Java: binary_expression; Kotlin: additive_expression for "a" + b
        return typeIs(n, "binary_expression") || typeIs(n, "additive_expression");
    }

    public static boolean skipBoxedCollection(Linter L, TSNode n) {
        if (inSignatureOnly(n) || inBuilderType(L, n) || inFunctionalApiTypeArg(L, n)) return true;
        if (codecPackage(L.path)) return true;
        if (hasTypeVarArg(L, n)) return true;
        String enclosing = enclosingTypeName(L, n);
        if (IMMUTABLE_PRIMITIVE_ARRAY_RE.matcher(enclosing).matches()) return true;
        if (enclosing.endsWith("Settings")) return true; // HTTP/2 SETTINGS maps — wire API
        String raw = text(L.src, n);
        // Tiny domain keys / flag maps — boxing cost is not the story
        if (Pattern.compile("\\bMap\\s*<\\s*Byte\\s*,").matcher(raw).find()) return true;
        if (Pattern.compile("\\bMap\\s*<\\s*[^,>]+\\s*,\\s*Boolean\\s*>").matcher(raw).find()) return true;
        if (Pattern.compile("\\bMap\\s*<\\s*Class\\s*<").matcher(raw).find()) return true;
        return false;
    }

    public static boolean codecPackage(String path) {
        return CODEC_PACKAGE_PATH_RE.matcher(path.replace('\\', '/')).find();
    }

    /** True when a generic type argument looks like a type parameter (E, K, V, T, …). */
    public static boolean hasTypeVarArg(Linter L, TSNode n) {
        String raw = text(L.src, n);
        Matcher m = Pattern.compile("<\\s*([A-Z][A-Z0-9]?)\\b").matcher(raw);
        while (m.find()) {
            String t = m.group(1);
            if (!BOXED_JAVA.contains(t) && !BOXED_KT.contains(t) && TYPE_VAR_RE.matcher(t).matches())
                return true;
        }
        m = Pattern.compile("[,<]\\s*([A-Z][A-Z0-9]?)\\s*[,>]").matcher(raw);
        while (m.find()) {
            String t = m.group(1);
            if (!BOXED_JAVA.contains(t) && !BOXED_KT.contains(t) && TYPE_VAR_RE.matcher(t).matches())
                return true;
        }
        return false;
    }

    public static boolean skipLogInLoop(Linter L, TSNode n, boolean isStdio) {
        if (samplePath(L.path)) return true;
        if (diagnosticMethod(L, n)) return true;
        if (isStdio && !LintConfig.CONFIG.strictStdioInLoop) return true;
        if (logGuarded(L, n)) return true;
        return false;
    }


    public static boolean codegenPath(String path) {
        return CODEGEN_PATH_RE.matcher(path.replace('\\', '/')).find();
    }

    public static boolean inThrow(TSNode n) {
        TSNode p = parent(n);
        while (p != null) {
            String ty = p.getType();
            if (Set.of("throw_statement", "throw_expression").contains(ty)) return true;
            if (typeIs(p, "jump_expression")) {
                for (TSNode c : children(p)) {
                    if ("throw".equals(c.getType())) return true;
                }
            }
            if (JAVA_FUNCS.contains(ty) || KT_FUNCS.contains(ty)
                    || Set.of("lambda_expression", "lambda_literal", "class_body", "object_literal").contains(ty))
                return false;
            p = parent(p);
        }
        return false;
    }

    public static boolean coldOrErrorMethod(Linter L, TSNode n) {
        String name = enclosingMethodName(L, n);
        return !name.isEmpty() && COLD_OR_ERROR_METHOD_RE.matcher(name).matches();
    }

    public static boolean skipFormatInLoop(Linter L, TSNode n) {
        if (inThrow(n)) return true;
        if (codegenPath(L.path)) return true;
        if (diagnosticMethod(L, n) || coldOrErrorMethod(L, n)) return true;
        return false;
    }


    public static boolean testingSupportPath(String path) {
        return TESTING_SUPPORT_PATH_RE.matcher(path.replace('\\', '/')).find();
    }

    public static boolean shortLivedMethod(Linter L, TSNode n) {
        String name = enclosingMethodName(L, n);
        return !name.isEmpty() && SHORT_LIVED_METHOD_RE.matcher(name).matches();
    }

    public static boolean isClientFactoryType(String cname) {
        if (cname == null || cname.isEmpty()) return false;
        if (CLIENT_FACTORY_TYPES.contains(cname)) return true;
        // OkHttpClient.Builder / Retrofit.Builder (not StringBuilder / any *Builder)
        if (cname.contains("OkHttp") || cname.contains("Retrofit") || cname.contains("MockRetrofit")) {
            return cname.endsWith("Builder") || cname.endsWith(".Builder");
        }
        return false;
    }

    public static boolean skipClientFactory(Linter L, TSNode n) {
        if (samplePath(L.path)) return true;
        if ("test".equals(sourceGroup(L.path))) return true;
        return false;
    }

    public static boolean shouldFlagClientFactory(Linter L, TSNode n) {
        if (skipClientFactory(L, n)) return false;
        return L.inLoop(n) || shortLivedMethod(L, n);
    }

    /**
     * jp-unpresized-collection: demote cold/codegen/tiny/unknowable-while; for soft collections
     * (ArrayList/StringBuilder/…) also demote when fill size is not knowable.
     * HashMap/HashSet unknown fills still report (rehash cost).
     */
    public static boolean skipUnpresized(Linter L, TSNode decl, String var, TSNode fill) {
        return skipUnpresized(L, decl, var, fill, "");
    }

    public static boolean skipUnpresized(Linter L, TSNode decl, String var, TSNode fill, String cname) {
        if (diagnosticMethod(L, decl) || coldOrErrorMethod(L, decl)) return true;
        if (samplePath(L.path) || codegenPath(L.path)) return true;
        String typeName = enclosingTypeName(L, decl);
        if (typeName.endsWith("Builder") || "Builder".equals(typeName)) return true;
        if (ensureCapacityLater(L, decl, var, fill)) return true;
        if (tinyConstantLoop(L, fill)) return true;
        if (unknowableWhileFill(L, fill)) return true;
        if (unknowableStreamForEach(L, fill)) return true;
        boolean soft = cname.isEmpty() || SOFT_UNPRESIZED.contains(cname);
        if (soft && !fillSizeKnowable(L, fill)) return true;
        return false;
    }

    /** Classic for / enhanced-for over array|Collection id / entrySet|keySet|values / Collection.forEach. */
    static boolean fillSizeKnowable(Linter L, TSNode fill) {
        TSNode p = parent(fill);
        while (p != null) {
            String ty = p.getType();
            if (JAVA_LOOPS.contains(ty) || KT_LOOPS.contains(ty)) {
                if ("for_statement".equals(ty)) {
                    if (constantLoopBound(L, p) >= 0) return true;
                    TSNode cond = field(p, "condition");
                    if (cond != null) {
                        String c = text(L.src, cond);
                        if (Pattern.compile("(\\.length|\\.size\\s*\\(|\\.count\\s*\\()").matcher(c).find())
                            return true;
                        if (Pattern.compile("<\\s*=?\\s*\\w+").matcher(c).find()) return true;
                    }
                    String full = text(L.src, p);
                    if (Pattern.compile("\\bin\\s+\\w+").matcher(full).find()
                            && !Pattern.compile("\\bin\\s+\\w+\\s*\\(").matcher(full).find())
                        return true;
                    return false;
                }
                if ("enhanced_for_statement".equals(ty)) {
                    TSNode value = field(p, "value");
                    if (value == null) return false;
                    return iterableSizeKnowable(L, value);
                }
                return false;
            }
            if (typeIs(p, "lambda_expression") || typeIs(p, "lambda_literal") || typeIs(p, "annotated_lambda")) {
                TSNode call = parent(p);
                while (call != null && !typeIs(call, "method_invocation") && !typeIs(call, "call_expression")) {
                    if (JAVA_FUNCS.contains(call.getType()) || KT_FUNCS.contains(call.getType())) return false;
                    call = parent(call);
                }
                if (call == null) return false;
                String t = text(L.src, call);
                if (!(t.contains("forEach") || t.contains("onEach"))) return false;
                if (t.contains("stream(") || t.contains("Stream.") || t.contains(".stream()")) return false;
                return true;
            }
            if (JAVA_FUNCS.contains(ty) || KT_FUNCS.contains(ty)) return false;
            p = parent(p);
        }
        return false;
    }

    static boolean iterableSizeKnowable(Linter L, TSNode value) {
        String v = text(L.src, value).strip();
        if (v.isEmpty()) return false;
        if (v.matches("\\w+")) return true;
        if (v.contains(".length") || v.contains(".size()")) return true;
        if (Pattern.compile("\\.(entrySet|keySet|values|toArray|iterator)\\s*\\(\\s*\\)\\s*$")
                .matcher(v).find()) return true;
        if (v.startsWith("Arrays.asList(") || v.startsWith("List.of(") || v.startsWith("Set.of(")) return true;
        if (v.contains("(") || v.startsWith("new ")) return false;
        if (v.matches("[\\w.]+")) return true;
        return false;
    }

    static boolean unknowableStreamForEach(Linter L, TSNode fill) {
        TSNode p = parent(fill);
        while (p != null) {
            if (typeIs(p, "lambda_expression") || typeIs(p, "lambda_literal") || typeIs(p, "annotated_lambda")) {
                TSNode call = parent(p);
                while (call != null && !typeIs(call, "method_invocation") && !typeIs(call, "call_expression")) {
                    call = parent(call);
                }
                if (call == null) return false;
                String t = text(L.src, call);
                return t.contains("stream(") || t.contains("Stream.") || t.contains(".stream()");
            }
            if (JAVA_LOOPS.contains(p.getType()) || KT_LOOPS.contains(p.getType())) return false;
            if (JAVA_FUNCS.contains(p.getType()) || KT_FUNCS.contains(p.getType())) return false;
            p = parent(p);
        }
        return false;
    }

    static boolean ensureCapacityLater(Linter L, TSNode decl, String var, TSNode fill) {
        int from = decl.getEndByte(), to = fill.getStartByte();
        if (to <= from) return false;
        String chunk = new String(L.src, from, Math.min(L.src.length, to) - from, StandardCharsets.UTF_8);
        if (Pattern.compile("\\b" + Pattern.quote(var) + "\\s*\\.\\s*ensure(Capacity|Size)\\s*\\(")
                .matcher(chunk).find()) return true;
        // Reassignment with capacity: var = new ArrayList<>(n) / HashMap.newHashMap(n) / StringBuilder(n)
        if (Pattern.compile("\\b" + Pattern.quote(var) + "\\s*=\\s*new\\s+\\w+\\s*(?:<[^>]*>)?\\s*\\([^)]*\\)")
                .matcher(chunk).find()) return true;
        if (Pattern.compile("\\b" + Pattern.quote(var)
                + "\\s*=\\s*(?:arrayListOf|mutableListOf|HashMap|ArrayList|StringBuilder|HashMap\\.newHashMap)\\s*[<(]")
                .matcher(chunk).find()) return true;
        return false;
    }

    static boolean tinyConstantLoop(Linter L, TSNode fill) {
        TSNode p = parent(fill);
        while (p != null) {
            if (JAVA_LOOPS.contains(p.getType()) || KT_LOOPS.contains(p.getType())) {
                return constantLoopBound(L, p) <= TINY_LOOP_BOUND && constantLoopBound(L, p) >= 0;
            }
            if (JAVA_FUNCS.contains(p.getType()) || KT_FUNCS.contains(p.getType())
                    || typeIs(p, "lambda_expression") || typeIs(p, "lambda_literal")) return false;
            p = parent(p);
        }
        return false;
    }

    /** @return bound if known tiny/finite literal, else -1 */
    static int constantLoopBound(Linter L, TSNode loop) {
        String ty = loop.getType();
        if ("for_statement".equals(ty)) {
            // Java classic for (init; cond; update) or Kotlin for (x in 1..N) / until
            TSNode cond = field(loop, "condition");
            if (cond != null) {
                Matcher m = Pattern.compile("<\\s*=?\\s*(\\d{1,3})\\b").matcher(text(L.src, cond));
                if (m.find()) return Integer.parseInt(m.group(1));
            }
            String full = text(L.src, loop);
            Matcher range = Pattern.compile("\\bin\\s+(-?\\d+)\\s*\\.\\.<?\\s*(\\d+)").matcher(full);
            if (range.find()) {
                int a = Integer.parseInt(range.group(1)), b = Integer.parseInt(range.group(2));
                return Math.max(0, b - a + (full.contains("..<") ? 0 : 1));
            }
            Matcher until = Pattern.compile("\\bin\\s+0\\s*until\\s+(\\d+)").matcher(full);
            if (until.find()) return Integer.parseInt(until.group(1));
            Matcher repeat = Pattern.compile("\\brepeat\\s*\\(\\s*(\\d+)\\s*\\)").matcher(full);
            if (repeat.find()) return Integer.parseInt(repeat.group(1));
        }
        if ("enhanced_for_statement".equals(ty)) {
            TSNode value = field(loop, "value");
            if (value != null) {
                String v = text(L.src, value).strip();
                if (v.matches("new\\s+\\w+\\s*\\[\\s*(\\d{1,3})\\s*]")) {
                    Matcher m = Pattern.compile("\\[\\s*(\\d+)").matcher(v);
                    if (m.find()) return Integer.parseInt(m.group(1));
                }
                if (v.startsWith("List.of(") || v.startsWith("Set.of(") || v.startsWith("Arrays.asList(")
                        || v.startsWith("arrayOf(") || v.startsWith("listOf(")) {
                    // count top-level commas in arg list — rough
                    int depth = 0, commas = 0;
                    int start = v.indexOf('(');
                    if (start >= 0) {
                        for (int i = start; i < v.length(); i++) {
                            char c = v.charAt(i);
                            if (c == '(' || c == '<') depth++;
                            else if (c == ')' || c == '>') depth--;
                            else if (c == ',' && depth == 1) commas++;
                        }
                        return commas + 1;
                    }
                }
            }
        }
        return -1;
    }

    static boolean unknowableWhileFill(Linter L, TSNode fill) {
        TSNode p = parent(fill);
        while (p != null) {
            if (typeIs(p, "while_statement") || typeIs(p, "do_statement") || typeIs(p, "do_while_statement")) {
                TSNode cond = field(p, "condition");
                String c = cond != null ? text(L.src, cond) : text(L.src, p).split("\\{", 2)[0];
                if (c.length() > 200) c = c.substring(0, 200);
                // Matcher.find / hasNext*/hasMore* / peek/poll / streaming reader / while(true)
                if (Pattern.compile(
                        "\\.find\\s*\\(|\\.hasNext\\w*\\s*\\(|\\.hasMore\\w*\\s*\\(|\\.readLine\\s*\\(|"
                                + "\\.next\\w*\\s*\\(|\\.peek\\s*\\(|\\.poll\\s*\\(|\\.isString\\s*\\(|"
                                + "\\.isNumber\\s*\\(|\\.isObject\\s*\\(|\\.isArray\\s*\\(|\\.isEnd\\w*\\s*\\(|"
                                + "^\\s*true\\s*$|iter_next\\s*\\(")
                        .matcher(c).find())
                    return true;
                // while (x != null) / while (!q.isEmpty()) drain-style
                if (Pattern.compile("!=\\s*null|\\.isEmpty\\s*\\(").matcher(c).find()) return true;
                return false;
            }
            if (JAVA_LOOPS.contains(p.getType()) || KT_LOOPS.contains(p.getType())) return false;
            if (JAVA_FUNCS.contains(p.getType()) || KT_FUNCS.contains(p.getType())
                    || typeIs(p, "lambda_expression") || typeIs(p, "lambda_literal")) return false;
            p = parent(p);
        }
        return false;
    }

    /** jp-expensive-alloc-in-loop: ThreadLocal / static format-cache fill loops. */
    public static boolean threadLocalOrCacheFill(Linter L, TSNode n) {
        TSNode fn = L.enclosingFunc(n);
        if (fn == null) return false;
        String body = text(L.src, fn);
        if (body.contains("ThreadLocal")) return true;
        // Lazy array cache: formats[i] = new SimpleDateFormat / BROWSER_COMPATIBLE_DATE_FORMATS[i] =
        if (Pattern.compile("\\w+\\s*\\[\\s*\\w+\\s*]\\s*=").matcher(body).find()
                && Pattern.compile("(?i)(date)?format|cache|pool").matcher(body).find())
            return true;
        return false;
    }

    public static boolean skipExpensiveAlloc(Linter L, TSNode n) {
        if (inThrow(n)) return true;
        if (coldOrErrorMethod(L, n) || diagnosticMethod(L, n)) return true;
        if (threadLocalOrCacheFill(L, n)) return true;
        return false;
    }




    public static class Linter {
        final String path;
        final byte[] src;
        final String lang;
        final Set<String> enabled;
        final TSTree tree;
        final TSNode root;
        final List<TSNode> nodes;
        final List<int[]> loops = new ArrayList<>();
        final List<TSNode> funcs = new ArrayList<>();
        final Set<String> enums = new HashSet<>();
        final Set<String> valueClasses = new HashSet<>();
        final Map<String, boolean[]> localFns = new HashMap<>(); // name -> {inline, hasFnParam}
        final boolean android;
        final Map<Integer, Set<String>> lineIgnores = new HashMap<>(); // null set means all
        final Map<Integer, Boolean> lineIgnoreAll = new HashMap<>();
        Set<String> fileIgnores = new HashSet<>();
        boolean fileIgnoreAll = false;
        final List<Finding> findings = new ArrayList<>();
        Set<String> applicable = Set.of();

        Linter(String path, byte[] src, String lang, Set<String> enabled) {
            this.path = path;
            this.src = src;
            this.lang = lang;
            this.enabled = enabled;
            this.tree = Ast.parse(lang, src);
            this.root = tree.getRootNode();
            this.nodes = walkList(root);
            this.android = Pattern.compile("^\\s*import\\s+androidx?\\.", Pattern.MULTILINE)
                    .matcher(new String(src, StandardCharsets.UTF_8)).find();
            collectIgnores();
        }

        void report(TSNode node, String code, String detail) {
            if (!enabled.contains(code) || !applicable.contains(code)) return;
            int line = Ast.line(node);
            int col = Ast.column(src, node);
            if (isIgnored(line, code)) return;
            findings.add(new Finding(path, line, col, code, detail));
        }

        boolean inLoop(TSNode n) {
            int a = n.getStartByte(), b = n.getEndByte();
            for (int[] r : loops) if (r[0] <= a && b <= r[1]) return true;
            return false;
        }

        TSNode enclosingFunc(TSNode n) {
            TSNode best = null;
            for (TSNode f : funcs) {
                if (f.getStartByte() <= n.getStartByte() && n.getEndByte() <= f.getEndByte()) {
                    if (best == null || f.getStartByte() >= best.getStartByte()) best = f;
                }
            }
            return best;
        }

        void collectIgnores() {
            String[] lines = new String(src, StandardCharsets.UTF_8).split("\n", -1);
            for (int i = 0; i < lines.length; i++) {
                Matcher m = IGNORE_RE.matcher(lines[i]);
                if (!m.find()) continue;
                String spec = m.group(2).split("--", 2)[0];
                Set<String> codes = new HashSet<>();
                for (String t : spec.trim().split("[\\s,]+")) {
                    if (t.isEmpty()) continue;
                    Rule.parse(t).ifPresent(r -> codes.add(r.code()));
                }
                boolean all = codes.isEmpty();
                if ("ignore-file".equals(m.group(1))) {
                    if (all) fileIgnoreAll = true;
                    else fileIgnores.addAll(codes);
                } else {
                    for (int ln : new int[]{i + 1, i + 2}) {
                        if (all) lineIgnoreAll.put(ln, true);
                        else lineIgnores.computeIfAbsent(ln, k -> new HashSet<>()).addAll(codes);
                    }
                }
            }
        }

        boolean isIgnored(int line, String code) {
            if (fileIgnoreAll || fileIgnores.contains(code)) return true;
            if (Boolean.TRUE.equals(lineIgnoreAll.get(line))) return true;
            Set<String> s = lineIgnores.get(line);
            return s != null && s.contains(code);
        }

        List<Map<String, Object>> syntaxErrorLocations() {
            List<Map<String, Object>> out = new ArrayList<>();
            for (TSNode n : nodes) {
                if (typeIs(n, "ERROR") || n.isMissing()) {
                    Map<String, Object> m = new LinkedHashMap<>();
                    m.put("line", Ast.line(n));
                    m.put("column", n.getStartPoint().getColumn() + 1);
                    m.put("kind", n.isMissing() ? "MISSING" : "ERROR");
                    out.add(m);
                }
            }
            return out;
        }

        Result run() {
            applicable = new HashSet<>();
            for (Rule r : Rule.RULES) if (r.langs().contains(lang)) applicable.add(r.code());
            if ("java".equals(lang)) {
                new JavaRules(this).run();
                new HotRules(this, JAVA_LOOPS, JAVA_FUNCS).run();
            } else {
                new KotlinRules(this).run();
                new HotRules(this, KT_LOOPS, KT_FUNCS).run();
            }
            findings.sort((a, b) -> {
                int c = Integer.compare(a.line(), b.line());
                if (c != 0) return c;
                c = Integer.compare(a.column(), b.column());
                return c != 0 ? c : a.rule().compareTo(b.rule());
            });
            List<Finding> uniq = new ArrayList<>();
            Set<String> seen = new HashSet<>();
            for (Finding f : findings) {
                String k = f.line() + ":" + f.column() + ":" + f.rule();
                if (seen.add(k)) uniq.add(f);
            }
            List<Map<String, Object>> locs = syntaxErrorLocations();
            return new Result(uniq, locs.size(), locs);
        }

        // jp-sleep-polling pure polling
        static final Set<String> CALL_TYPES = Set.of("method_invocation", "object_creation_expression", "call_expression");
        static final Set<String> CATCH_TYPES = Set.of("catch_clause", "catch_block");

        boolean pollOnlyLoop(TSNode sleepCall, TSNode loop) {
            List<int[]> condRanges = new ArrayList<>();
            for (TSNode c : walk(loop)) {
                if (typeIs(c, "if_statement")) {
                    TSNode cn = field(c, "condition");
                    if (cn != null) condRanges.add(new int[]{cn.getStartByte(), cn.getEndByte()});
                } else if (typeIs(c, "if_expression")) {
                    List<TSNode> named = named(c);
                    if (!named.isEmpty()) condRanges.add(new int[]{named.get(0).getStartByte(), named.get(0).getEndByte()});
                }
            }
            TSNode lc = field(loop, "condition");
            if (lc == null) {
                List<TSNode> named = named(loop);
                if (!named.isEmpty()) lc = loop.getType().startsWith("do") ? named.get(named.size() - 1) : named.get(0);
            }
            if (lc != null) condRanges.add(new int[]{lc.getStartByte(), lc.getEndByte()});
            int start = loop.getStartByte();
            for (TSNode c : walk(loop)) {
                if (!CALL_TYPES.contains(c.getType()) || c.getStartByte() < start) continue;
                if (c.getStartByte() <= sleepCall.getStartByte() && sleepCall.getEndByte() <= c.getEndByte()) continue;
                if (sleepCall.getStartByte() <= c.getStartByte() && c.getEndByte() <= sleepCall.getEndByte()) continue;
                boolean inCond = false;
                for (int[] r : condRanges) if (r[0] <= c.getStartByte() && c.getEndByte() <= r[1]) { inCond = true; break; }
                if (inCond) continue;
                TSNode p = parent(c);
                boolean inCatch = false;
                while (p != null && !eq(p, loop)) {
                    if (CATCH_TYPES.contains(p.getType())) { inCatch = true; break; }
                    p = parent(p);
                }
                if (inCatch) continue;
                return false;
            }
            return true;
        }
    }

    // =====================================================================
    // Java
    // =====================================================================
    public static class JavaRules {
        final Linter L;
        final Map<String, Set<String>> stringVarsCache = new HashMap<>();

        JavaRules(Linter L) { this.L = L; }

        void collectStructure() {
            for (TSNode n : L.nodes) {
                if (JAVA_LOOPS.contains(n.getType())) L.loops.add(new int[]{n.getStartByte(), n.getEndByte()});
                else if (JAVA_FUNCS.contains(n.getType())) L.funcs.add(n);
                else if (typeIs(n, "enum_declaration")) {
                    TSNode nm = field(n, "name");
                    if (nm != null) L.enums.add(text(L.src, nm));
                } else if (typeIs(n, "method_invocation") && Set.of("forEach", "forEachOrdered").contains(methodName(n))) {
                    TSNode args = field(n, "arguments");
                    for (TSNode a : named(args != null ? args : n)) {
                        if (typeIs(a, "lambda_expression")) L.loops.add(new int[]{a.getStartByte(), a.getEndByte()});
                    }
                }
            }
        }

        void run() {
            collectStructure();
            for (TSNode n : L.nodes) {
                String t = n.getType();
                switch (t) {
                    case "generic_type" -> genericType(n);
                    case "array_type" -> {
                        TSNode el = field(n, "element");
                        if (el != null && BOXED_JAVA.contains(text(L.src, el)) && !skipBoxedCollection(L, n))
                            L.report(n, "jp-boxed-primitive-collection", text(L.src, n));
                    }
                    case "assignment_expression" -> assignment(n);
                    case "method_invocation" -> invocation(n);
                    case "object_creation_expression" -> creation(n);
                    case "array_creation_expression" -> {
                        if (L.inLoop(n) && loopInvariantDims(n) && !skipExpensiveAlloc(L, n))
                            L.report(n, "jp-expensive-alloc-in-loop", text(L.src, n));
                    }
                    case "catch_clause" -> catchClause(n);
                                        case "method_declaration" -> {
                        TSNode nm = field(n, "name");
                        TSNode params = field(n, "parameters");
                        if (nm != null && "finalize".equals(text(L.src, nm)) && params != null && named(params).isEmpty())
                            L.report(nm, "jp-finalize", "finalize()");
                    }
                    case "local_variable_declaration", "field_declaration" -> {
                        localDecl(n);
                        if (typeIs(n, "field_declaration")) fieldUpdater(n);
                    }
                    default -> {}
                }
            }
        }

        String methodName(TSNode n) {
            TSNode nm = field(n, "name");
            return nm != null ? text(L.src, nm) : "";
        }
        String receiver(TSNode n) {
            TSNode o = field(n, "object");
            return o != null ? text(L.src, o) : "";
        }
        List<String> typeArgs(TSNode g) {
            for (TSNode c : children(g)) {
                if (typeIs(c, "type_arguments")) return named(c).stream().map(x -> text(L.src, x)).toList();
            }
            return List.of();
        }
        String baseName(TSNode g) {
            List<TSNode> kids = children(g);
            return kids.isEmpty() ? "" : text(L.src, kids.get(0)).replaceAll(".*\\.", "");
        }
        boolean loopInvariantDims(TSNode n) {
            List<TSNode> dims = children(n).stream().filter(c -> typeIs(c, "dimensions_expr")).toList();
            TSNode ty = field(n, "type");
            if (dims.size() != 1 || ty == null || !Set.of("byte","char","int","long","double","float","short").contains(text(L.src, ty)))
                return false;
            Matcher m = Pattern.compile("\\[\\s*(\\d[\\d_]*)\\s*\\]").matcher(text(L.src, dims.get(0)));
            return m.matches() && Integer.parseInt(m.group(1).replace("_", "")) >= BIG_BUFFER;
        }

        void genericType(TSNode g) {
            String name = baseName(g);
            List<String> args = typeArgs(g);
            if (args.isEmpty()) return;
            if (L.android && (HASH_MAPS.contains(name) || "Map".equals(name)) && Set.of("Integer","Long").contains(args.get(0))) {
                L.report(g, "jp-android-sparse-array", text(L.src, g));
                return;
            }
            if (COLLECTIONS.contains(name) && args.stream().anyMatch(BOXED_JAVA::contains)
                    && !skipBoxedCollection(L, g))
                L.report(g, "jp-boxed-primitive-collection", text(L.src, g));
            if ((HASH_MAPS.contains(name) || HASH_SETS.contains(name)) && L.enums.contains(args.get(0)))
                L.report(g, "jp-enum-key-hash-collection", text(L.src, g) + "（" + args.get(0) + " 是 enum）");
        }

        void localDecl(TSNode n) {
            TSNode ty = field(n, "type");
            if (ty == null) return;
            for (TSNode d : named(n)) {
                if (!typeIs(d, "variable_declarator")) continue;
                TSNode val = field(d, "value");
                if (val == null || !typeIs(val, "object_creation_expression")) continue;
                TSNode ctype = field(val, "type");
                String cname = ctype != null ? text(L.src, ctype).split("<",2)[0].replaceAll(".*\\.","") : "";
                if (typeIs(ty, "generic_type") && (HASH_MAPS.contains(cname) || HASH_SETS.contains(cname))) {
                    List<String> args = typeArgs(ty);
                    if (!args.isEmpty() && L.enums.contains(args.get(0)) && text(L.src, ctype).contains("<>"))
                        L.report(val, "jp-enum-key-hash-collection", text(L.src, ty) + " = new " + cname + "<>()（" + args.get(0) + " 是 enum）");
                }
                TSNode argl = field(val, "arguments");
                if (typeIs(n, "local_variable_declaration")
                        && Set.of("ArrayList","HashMap","HashSet","LinkedHashMap","LinkedHashSet","StringBuilder","ArrayDeque").contains(cname)
                        && argl != null && named(argl).isEmpty()) {
                    String var = text(L.src, field(d, "name"));
                    filledInLoop(n, var, cname);
                }
            }
        }

        void filledInLoop(TSNode decl, String var, String cname) {
            TSNode fn = L.enclosingFunc(decl);
            if (fn == null) return;
            for (TSNode m : walk(fn)) {
                if (typeIs(m, "method_invocation") && m.getStartByte() > decl.getEndByte()
                        && var.equals(receiver(m))
                        && Set.of("add","put","append","addLast","offer","push").contains(methodName(m))
                        && L.inLoop(m)) {
                    if (skipUnpresized(L, decl, var, m, cname)) return;
                    L.report(decl, "jp-unpresized-collection", var + " = new " + cname + "() 随后在循环中 " + methodName(m));
                    return;
                }
            }
        }

        void assignment(TSNode n) {
            if (!L.inLoop(n)) return;
            TSNode left = field(n, "left"), right = field(n, "right"), op = field(n, "operator");
            if (left == null || !typeIs(left, "identifier")) return;
            String var = text(L.src, left);
            if (!isStringVar(n, var)) return;
            String optext = op != null ? text(L.src, op) : "";
            if ("+=".equals(optext) || ("=".equals(optext) && right != null && accumulates(right, var)))
                L.report(n, "jp-string-concat-in-loop", text(L.src, n).substring(0, Math.min(60, text(L.src, n).length())));
        }

        boolean accumulates(TSNode right, String var) {
            TSNode cur = right;
            while (cur != null && typeIs(cur, "binary_expression")) {
                TSNode op = field(cur, "operator");
                if (op == null || !"+".equals(text(L.src, op))) return false;
                cur = field(cur, "left");
            }
            return cur != right && cur != null && typeIs(cur, "identifier") && var.equals(text(L.src, cur));
        }

        boolean isStringVar(TSNode at, String var) {
            TSNode fn = L.enclosingFunc(at);
            TSNode scope = fn != null ? fn : L.root;
            String k = scope.getStartByte() + ":" + scope.getEndByte();
            Set<String> names = stringVarsCache.computeIfAbsent(k, kk -> stringNames(walkList(scope), true));
            if (names.contains(var)) return true;
            Set<String> fields = stringVarsCache.computeIfAbsent("fields", kk -> stringNames(L.nodes, false));
            return fields.contains(var);
        }

        Set<String> stringNames(List<TSNode> nodes, boolean localsToo) {
            Set<String> types = localsToo
                    ? Set.of("local_variable_declaration", "field_declaration", "formal_parameter")
                    : Set.of("field_declaration");
            Set<String> out = new HashSet<>();
            for (TSNode m : nodes) {
                if (!types.contains(m.getType())) continue;
                TSNode ty = field(m, "type");
                if (ty == null || !"String".equals(text(L.src, ty))) continue;
                if (typeIs(m, "formal_parameter")) {
                    TSNode nm = field(m, "name");
                    if (nm != null) out.add(text(L.src, nm));
                }
                for (TSNode d : named(m)) {
                    if (typeIs(d, "variable_declarator")) out.add(text(L.src, field(d, "name")));
                }
            }
            return out;
        }

        void invocation(TSNode n) {
            String name = methodName(n), recv = receiver(n);
            TSNode argsN = field(n, "arguments");
            List<TSNode> argnodes = argsN != null ? named(argsN) : List.of();
            boolean loop = L.inLoop(n);
            if (loop) {
                if (("Pattern".equals(recv) && "compile".equals(name)) || (recv.endsWith("Pattern") && "compile".equals(name)))
                    L.report(n, "jp-regex-in-loop", "Pattern.compile(...)");
                else if (Set.of("replaceAll","replaceFirst").contains(name) && argnodes.size() == 2)
                    L.report(n, "jp-regex-in-loop", "." + name + "(...)：每次调用都编译正则");
                else if ("matches".equals(name) && argnodes.size() == 1 && typeIs(argnodes.get(0), "string_literal") && !recv.isEmpty())
                    L.report(n, "jp-regex-in-loop", ".matches(\"...\")：每次调用都编译正则");
                else if ("split".equals(name) && !argnodes.isEmpty() && typeIs(argnodes.get(0), "string_literal") && !splitFastpath(argnodes.get(0)))
                    L.report(n, "jp-regex-in-loop", ".split(" + text(L.src, argnodes.get(0)) + ")：非单字符快路径，每次编译正则");
                if (("String".equals(recv) && "format".equals(name)) || "formatted".equals(name)) {
                    if (!skipFormatInLoop(L, n))
                        L.report(n, "jp-format-in-loop", (recv.isEmpty() ? "" : recv + ".") + name + "(...)");
                }
                if ("intern".equals(name) && argnodes.isEmpty())
                    L.report(n, "jp-string-intern-in-loop", (recv.isEmpty() ? "" : recv + ".") + "intern()");
                if (Set.of("System.out","System.err").contains(recv) && Set.of("println","print","printf","format").contains(name)) {
                    if (!skipLogInLoop(L, n, true))
                        L.report(n, "jp-log-in-loop", recv + "." + name + "(...)");
                } else if ("Log".equals(recv) && Set.of("v","d","i","w","e","wtf").contains(name)) {
                    if (!skipLogInLoop(L, n, false))
                        L.report(n, "jp-log-in-loop", "Log." + name + "(...)");
                } else if (Set.of("debug","info","trace","warn","error").contains(name)
                        && Pattern.compile("log", Pattern.CASE_INSENSITIVE).matcher(recv).find()
                        && !argnodes.isEmpty() && isStringConcatArg(argnodes.get(0))) {
                    if (!skipLogInLoop(L, n, false))
                        L.report(n, "jp-log-in-loop", recv + "." + name + "(\"...\" + ...): string concat before level check");
                }
                if (expensiveFactory(recv, name) && !skipExpensiveAlloc(L, n))
                    L.report(n, "jp-expensive-alloc-in-loop", recv + "." + name + "(...)");
                if ((("Thread".equals(recv) || "SystemClock".equals(recv)) && "sleep".equals(name)
                        || ("TimeUnit.MILLISECONDS".equals(recv) && "sleep".equals(name))) && inWhile(n))
                    L.report(n, "jp-sleep-polling", recv + "." + name + "(...)");
            }
            if ("reduce".equals(name) && !argnodes.isEmpty() && boxedStreamChain(n)) {
                String last = text(L.src, argnodes.get(argnodes.size()-1)).replace(" ", "");
                if (Set.of("Integer::sum","Long::sum","Double::sum","Float::sum").contains(last)
                        || last.matches("\\(?(\\w+),(\\w+)\\)?->\\1\\+\\2"))
                    L.report(n, "jp-boxed-stream", ".reduce(..., " + text(L.src, argnodes.get(argnodes.size()-1)) + ")");
            } else if (Set.of("summingInt","summingLong","summingDouble","averagingInt","averagingLong","averagingDouble").contains(name)
                    && "Collectors".equals(recv))
                L.report(n, "jp-boxed-stream", "Collectors." + name + "(...)");
        }

        boolean expensiveFactory(String recv, String name) {
            return Set.of(
                    "MessageDigest:getInstance","Cipher:getInstance","Mac:getInstance",
                    "DateTimeFormatter:ofPattern","NumberFormat:getInstance",
                    "ByteBuffer:allocate","ByteBuffer:allocateDirect","JsonMapper:builder"
            ).contains(recv + ":" + name);
        }

        boolean boxedStreamChain(TSNode n) {
            List<String> names = new ArrayList<>();
            TSNode cur = field(n, "object");
            while (cur != null && typeIs(cur, "method_invocation")) {
                names.add(methodName(cur));
                if ("Stream".equals(receiver(cur))) names.add("Stream.of");
                cur = field(cur, "object");
            }
            Set<String> prim = Set.of("mapToInt","mapToLong","mapToDouble","asLongStream","asDoubleStream","chars","codePoints");
            boolean hasStream = names.contains("stream") || names.contains("Stream.of") || names.contains("parallelStream");
            return hasStream && names.stream().noneMatch(prim::contains);
        }

        boolean inWhile(TSNode n) {
            TSNode p = parent(n);
            while (p != null) {
                if (typeIs(p, "while_statement") || typeIs(p, "do_statement")) return L.pollOnlyLoop(n, p);
                if (JAVA_FUNCS.contains(p.getType())) return false;
                p = parent(p);
            }
            return false;
        }

        boolean splitFastpath(TSNode lit) {
            String s = text(L.src, lit);
            if (s.length() < 2) return false;
            s = s.substring(1, s.length()-1).replace("\\\\", "\\");
            if (s.length() == 1) return SPLIT_META.indexOf(s.charAt(0)) < 0;
            return s.length() == 2 && s.charAt(0) == '\\' && !Character.isLetterOrDigit(s.charAt(1));
        }

        void creation(TSNode n) {
            TSNode ctype = field(n, "type");
            if (ctype == null) return;
            String cname = text(L.src, ctype).split("<",2)[0].replaceAll(".*\\.","");
            if (L.inLoop(n) && EXPENSIVE_NEW.contains(cname) && !skipExpensiveAlloc(L, n))
                L.report(n, "jp-expensive-alloc-in-loop", "new " + cname + "(...)");
            if (isClientFactoryType(cname) && shouldFlagClientFactory(L, n))
                L.report(n, "jp-client-factory-recreate", "new " + cname + "(...)");
        }

        void catchClause(TSNode n) {
            if (!L.inLoop(n)) return;
            List<String> types = new ArrayList<>();
            for (TSNode c : walk(n)) {
                if (typeIs(c, "type_identifier") && parent(c) != null && typeIs(parent(c), "catch_type"))
                    types.add(text(L.src, c));
            }
            List<String> hit = types.stream().filter(t -> CF_EXCEPTIONS.contains(t.replaceAll(".*\\.",""))).toList();
            if (!hit.isEmpty()) L.report(n, "jp-exception-control-flow", "catch (" + String.join(" | ", hit) + ")");
        }

        void fieldUpdater(TSNode f) {
            TSNode ty = field(f, "type");
            if (ty == null) return;
            String tname = text(L.src, ty).split("<",2)[0].replaceAll(".*\\.","");
            if (!FIELD_UPDATER_TYPES.contains(tname)) return;
            TSNode mods = null;
            for (TSNode c : children(f)) if (typeIs(c, "modifiers")) { mods = c; break; }
            boolean isStatic = mods != null && java.util.Arrays.asList(text(L.src, mods).split("\\s+")).contains("static");
            if (!isStatic) L.report(ty, "jp-non-static-field-updater", tname + " field is not static");
        }
    }

    // =====================================================================
    // Kotlin
    // =====================================================================
    public static class KotlinRules {
        static final Set<String> LOOP_CALLS = Set.of("repeat", "forEach", "forEachIndexed", "onEach");
        static final Set<String> CHAIN_OPS = Set.of(
                "map", "filter", "flatMap", "mapNotNull", "filterNot", "filterIsInstance", "mapIndexed",
                "filterIndexed", "distinct", "sortedBy", "sorted", "zip", "flatten", "withIndex");
        static final Set<String> SHORT_CIRCUIT = Set.of(
                "first", "firstOrNull", "take", "find", "any", "none", "all", "indexOfFirst", "takeWhile",
                "single", "singleOrNull", "contains");

        final Linter L;
        KotlinRules(Linter L) { this.L = L; }

        HotAnalysis.RecvName callee(TSNode call) {
            List<TSNode> kids = children(call);
            if (kids.isEmpty()) return new HotAnalysis.RecvName("", "");
            TSNode h = kids.get(0);
            if (isIdent(h)) return new HotAnalysis.RecvName("", text(L.src, h));
            if (typeIs(h, "navigation_expression") || typeIs(h, "postfix_expression")) {
                List<TSNode> ids = new ArrayList<>();
                for (TSNode c : walkList(h)) if (isIdent(c)) ids.add(c);
                if (!ids.isEmpty()) {
                    TSNode last = ids.get(ids.size()-1);
                    String full = text(L.src, h);
                    int cut = last.getStartByte() - h.getStartByte();
                    String recv = cut > 0 ? full.substring(0, cut).replaceAll("[?.]+$", "").replaceAll("\\.$", "") : "";
                    return new HotAnalysis.RecvName(recv, text(L.src, last));
                }
            }
            if (typeIs(h, "call_expression")) return callee(h);
            return new HotAnalysis.RecvName("", "");
        }

        boolean hasLambda(TSNode call) {
            for (TSNode c : children(call)) {
                if (typeIs(c, "annotated_lambda")) return true;
                if (typeIs(c, "call_suffix")) {
                    for (TSNode s : children(c)) if (typeIs(s, "annotated_lambda")) return true;
                }
            }
            return false;
        }

        List<TSNode> args(TSNode call) {
            for (TSNode c : children(call)) {
                if (typeIs(c, "value_arguments")) return named(c);
                if (typeIs(c, "call_suffix")) {
                    for (TSNode s : children(c)) if (typeIs(s, "value_arguments")) return named(s);
                }
            }
            List<TSNode> kids = children(call);
            if (!kids.isEmpty() && typeIs(kids.get(0), "call_expression")) return args(kids.get(0));
            return List.of();
        }

        String typeName(TSNode ut) {
            List<TSNode> ids = new ArrayList<>();
            for (TSNode c : walkList(ut)) if (isIdent(c)) ids.add(c);
            // Prefer type_identifier / last id under this user_type only one level if possible
            List<TSNode> direct = children(ut).stream().filter(Ast::isIdent).toList();
            if (!direct.isEmpty()) return text(L.src, direct.get(direct.size()-1));
            return ids.isEmpty() ? text(L.src, ut) : text(L.src, ids.get(0));
        }

        List<String> typeArgs(TSNode node) {
            for (TSNode c : children(node)) {
                if (typeIs(c, "type_arguments"))
                    return named(c).stream().map(x -> text(L.src, x).strip()).toList();
                if (typeIs(c, "call_suffix")) {
                    for (TSNode s : children(c)) {
                        if (typeIs(s, "type_arguments"))
                            return named(s).stream().map(x -> text(L.src, x).strip()).toList();
                    }
                }
            }
            return List.of();
        }

        void collectStructure() {
            for (TSNode n : L.nodes) {
                String t = n.getType();
                if (KT_LOOPS.contains(t)) L.loops.add(new int[]{n.getStartByte(), n.getEndByte()});
                else if (KT_FUNCS.contains(t)) {
                    L.funcs.add(n);
                    if (typeIs(n, "function_declaration")) collectFn(n);
                } else if (typeIs(n, "class_declaration")) {
                    TSNode mods = null;
                    boolean isEnum = false, isValue = false, isInline = false;
                    for (TSNode c : children(n)) {
                        if (typeIs(c, "modifiers")) mods = c;
                        if (!c.isNamed() && "enum".equals(c.getType())) isEnum = true;
                        if (typeIs(c, "enum_class_body")) isEnum = true;
                        if (!c.isNamed() && ("value".equals(c.getType()) || "inline".equals(c.getType()))) {
                            if ("value".equals(c.getType())) isValue = true;
                            if ("inline".equals(c.getType())) isInline = true;
                        }
                        if (typeIs(c, "class_modifier")) {
                            String mt = text(L.src, c).strip();
                            if ("value".equals(mt) || "inline".equals(mt) || "enum".equals(mt) || "data".equals(mt)) {
                                if ("value".equals(mt)) isValue = true;
                                if ("inline".equals(mt)) isInline = true;
                                if ("enum".equals(mt)) isEnum = true;
                            }
                        }
                    }
                    if (mods != null) {
                        String mtTxt = text(L.src, mods);
                        if (mtTxt.contains("enum")) isEnum = true;
                        if (mtTxt.contains("value")) isValue = true;
                        if (mtTxt.contains("inline")) isInline = true;
                        for (TSNode c : walkList(mods)) {
                            if (typeIs(c, "class_modifier")) {
                                String mt = text(L.src, c).strip();
                                if ("value".equals(mt)) isValue = true;
                                if ("inline".equals(mt)) isInline = true;
                                if ("enum".equals(mt)) isEnum = true;
                            }
                        }
                    }
                    TSNode nm = null;
                    for (TSNode c : children(n)) if (isIdent(c)) { nm = c; break; }
                    if (nm != null) {
                        if (isEnum) L.enums.add(text(L.src, nm));
                        if (isValue || isInline) L.valueClasses.add(text(L.src, nm));
                    }
                } else if (typeIs(n, "call_expression") && hasLambda(n) && LOOP_CALLS.contains(callee(n).name())) {
                    outer:
                    for (TSNode c : children(n)) {
                        if (typeIs(c, "annotated_lambda")) {
                            L.loops.add(new int[]{c.getStartByte(), c.getEndByte()});
                            break;
                        }
                        if (typeIs(c, "call_suffix")) {
                            for (TSNode s : children(c)) if (typeIs(s, "annotated_lambda")) {
                                L.loops.add(new int[]{s.getStartByte(), s.getEndByte()});
                                break outer;
                            }
                        }
                    }
                }
            }
        }

        void run() {
            collectStructure();
            for (TSNode n : L.nodes) {
                String t = n.getType();
                switch (t) {
                    case "user_type" -> userType(n);
                    case "nullable_type" -> {
                        for (TSNode c : children(n)) {
                            if (typeIs(c, "user_type") && L.valueClasses.contains(text(L.src, c))) {
                                L.report(n, "jp-value-class-boxing", text(L.src, n) + "：可空的 value class 被装箱");
                                break;
                            }
                        }
                    }
                    case "assignment" -> assignment(n);
                    case "call_expression" -> call(n);
                    case "catch_block" -> catchBlock(n);
                                        case "function_declaration" -> {
                        TSNode nm = null, params = null;
                        for (TSNode c : children(n)) {
                            if (isIdent(c) && nm == null) nm = c;
                            if (typeIs(c, "function_value_parameters")) params = c;
                        }
                        if (nm != null && "finalize".equals(text(L.src, nm)) && params != null && named(params).isEmpty())
                            L.report(nm, "jp-finalize", "finalize()");
                    }
                    case "property_declaration" -> property(n);
                    default -> {}
                }
            }
        }

        void collectFn(TSNode fn) {
            TSNode nm = null, mods = null, params = null;
            for (TSNode c : children(fn)) {
                if (isIdent(c) && nm == null) nm = c;
                if (typeIs(c, "modifiers")) mods = c;
                if (typeIs(c, "function_value_parameters")) params = c;
            }
            if (nm == null) return;
            boolean inline = mods != null && java.util.Arrays.asList(text(L.src, mods).split("\\s+")).contains("inline");
            boolean hasFn = false;
            if (params != null) {
                for (TSNode c : walk(params)) if (typeIs(c, "function_type")) { hasFn = true; break; }
            }
            String name = text(L.src, nm);
            boolean[] prev = L.localFns.get(name);
            L.localFns.put(name, new boolean[]{
                    inline || (prev != null && prev[0]),
                    hasFn || (prev != null && prev[1])
            });
        }

        void userType(TSNode ut) {
            String name = typeName(ut);
            List<String> args = typeArgs(ut);
            if (args.isEmpty()) return;
            if ("Array".equals(name) && BOXED_KT.contains(args.get(0))) {
                if (!skipBoxedCollection(L, ut)) L.report(ut, "jp-boxed-primitive-collection", text(L.src, ut));
                return;
            }
            if ("Array".equals(name) && L.valueClasses.contains(args.get(0))) {
                L.report(ut, "jp-value-class-boxing", text(L.src, ut) + "：数组元素被装箱"); return;
            }
            if (L.android && (HASH_MAPS.contains(name) || Set.of("Map","MutableMap").contains(name))
                    && Set.of("Int","Long").contains(args.get(0))) {
                L.report(ut, "jp-android-sparse-array", text(L.src, ut)); return;
            }
            if (COLLECTIONS.contains(name) && args.stream().anyMatch(BOXED_KT::contains)
                    && !skipBoxedCollection(L, ut))
                L.report(ut, "jp-boxed-primitive-collection", text(L.src, ut));
            if ((HASH_MAPS.contains(name) || HASH_SETS.contains(name)) && L.enums.contains(args.get(0)))
                L.report(ut, "jp-enum-key-hash-collection", text(L.src, ut) + "（" + args.get(0) + " 是 enum）");
            for (String a : args) {
                if (L.valueClasses.contains(a.replace("?", ""))) {
                    L.report(ut, "jp-value-class-boxing", text(L.src, ut) + "：泛型参数中的 " + a + " 被装箱");
                    break;
                }
            }
        }

        void property(TSNode n) {
            TSNode deleg = null, call = null, var = null;
            for (TSNode c : children(n)) {
                if (typeIs(c, "property_delegate")) deleg = c;
                if (typeIs(c, "call_expression") && call == null) call = c;
                if (typeIs(c, "variable_declaration")) var = c;
            }
            if (deleg != null) {
                TSNode dcall = null;
                for (TSNode c : children(deleg)) if (typeIs(c, "call_expression")) { dcall = c; break; }
                if (dcall != null && "lazy".equals(callee(dcall).name()) && args(dcall).isEmpty())
                    L.report(deleg, "jp-lazy-default-mode", "by lazy { ... }");
            }
            if (call == null || var == null) return;
            HotAnalysis.RecvName cn = callee(call);
            List<String> targs = typeArgs(call);
            TSNode declT = null;
            for (TSNode c : children(var)) if (typeIs(c, "user_type")) { declT = c; break; }
            if (declT != null && targs.isEmpty()) {
                String dn = typeName(declT);
                List<String> da = typeArgs(declT);
                if (Set.of("MutableMap","HashMap","MutableSet","HashSet").contains(dn) && !da.isEmpty() && L.enums.contains(da.get(0))
                        && Set.of("mutableMapOf","hashMapOf","HashMap","mutableSetOf","hashSetOf","HashSet","LinkedHashMap").contains(cn.name()))
                    L.report(call, "jp-enum-key-hash-collection", text(L.src, declT) + " = " + cn.name() + "()（" + da.get(0) + " 是 enum）");
            }
            if (cn.recv().isEmpty() && Set.of("ArrayList","HashMap","HashSet","mutableListOf","mutableMapOf","mutableSetOf",
                    "hashMapOf","hashSetOf","StringBuilder","ArrayDeque","LinkedHashMap").contains(cn.name())
                    && args(call).isEmpty() && !hasLambda(call)) {
                TSNode id = null;
                for (TSNode c : children(var)) if (isIdent(c)) { id = c; break; }
                if (id != null) filledInLoop(n, text(L.src, id), cn.name());
            }
        }

        void filledInLoop(TSNode decl, String var, String fname) {
            TSNode fn = L.enclosingFunc(decl);
            if (fn == null) return;
            for (TSNode m : walk(fn)) {
                if (typeIs(m, "call_expression") && m.getStartByte() > decl.getEndByte() && L.inLoop(m)) {
                    HotAnalysis.RecvName cn = callee(m);
                    if (var.equals(cn.recv()) && Set.of("add","put","append","addLast","set").contains(cn.name())) {
                        if (skipUnpresized(L, decl, var, m, fname)) return;
                        L.report(decl, "jp-unpresized-collection", var + " = " + fname + "() 随后在循环中 " + cn.name());
                        return;
                    }
                }
                if (typeIs(m, "assignment") && m.getStartByte() > decl.getEndByte() && L.inLoop(m)) {
                    List<TSNode> kids = children(m);
                    if (!kids.isEmpty() && typeIs(kids.get(0), "indexing_expression")
                            && text(L.src, kids.get(0)).startsWith(var + "[")) {
                        if (skipUnpresized(L, decl, var, m, fname)) return;
                        L.report(decl, "jp-unpresized-collection", var + " = " + fname + "() 随后在循环中 " + var + "[k] = v");
                        return;
                    }
                }
            }
        }

        void assignment(TSNode n) {
            if (!L.inLoop(n) || children(n).isEmpty()) return;
            TSNode lhs = children(n).get(0);
            TSNode op = null;
            for (TSNode c : children(n)) if (!c.isNamed()) { op = c; break; }
            String var;
            if (isIdent(lhs)) var = text(L.src, lhs);
            else if (typeIs(lhs, "directly_assignable_expression")) var = identText(L.src, lhs);
            else return;
            if (op == null || var.isEmpty()) return;
            TSNode rhs = children(n).get(children(n).size() - 1);
            if (!isStringVar(n, var)) return;
            String ops = text(L.src, op);
            if (ops.isEmpty()) ops = op.getType();
            if ("+=".equals(ops) || ("=".equals(ops) && accumulates(rhs, var)))
                L.report(n, "jp-string-concat-in-loop", text(L.src, n).substring(0, Math.min(60, text(L.src, n).length())));

        }

        boolean accumulates(TSNode rhs, String var) {
            TSNode cur = rhs;
            while (cur != null && typeIs(cur, "binary_expression")) {
                List<TSNode> ops = children(cur).stream().filter(c -> !c.isNamed()).toList();
                if (ops.isEmpty() || !"+".equals(text(L.src, ops.get(0)))) return false;
                cur = children(cur).isEmpty() ? null : children(cur).get(0);
            }
            return cur != rhs && cur != null && isIdent(cur) && var.equals(text(L.src, cur));
        }

        boolean isStringVar(TSNode at, String var) {
            for (TSNode m : L.nodes) {
                if (!typeIs(m, "property_declaration") || m.getStartByte() > at.getStartByte()) continue;
                TSNode vd = null;
                for (TSNode c : children(m)) if (typeIs(c, "variable_declaration")) { vd = c; break; }
                if (vd == null) continue;
                TSNode nm = null;
                for (TSNode c : children(vd)) if (isIdent(c)) { nm = c; break; }
                if (nm == null || !var.equals(text(L.src, nm))) continue;
                TSNode ty = null;
                for (TSNode c : children(vd)) if (typeIs(c, "user_type") || typeIs(c, "nullable_type")) { ty = c; break; }
                if (ty != null) return text(L.src, ty).replace("?", "").equals("String");
                TSNode vdFinal = vd;
                List<TSNode> init = children(m).stream().filter(c -> c.isNamed() && !eq(c, vdFinal)).toList();
                return !init.isEmpty() && typeIs(init.get(init.size()-1), "string_literal");
            }
            return false;
        }

        void call(TSNode n) {
            HotAnalysis.RecvName cn = callee(n);
            String recv = cn.recv(), name = cn.name();
            boolean loop = L.inLoop(n);
            List<String> targs = typeArgs(n);
            if (targs.isEmpty() && !children(n).isEmpty() && typeIs(children(n).get(0), "call_expression"))
                targs = typeArgs(children(n).get(0));
            if (Set.of("HashMap","hashMapOf","mutableMapOf","LinkedHashMap","HashSet","hashSetOf","mutableSetOf",
                    "linkedMapOf","LinkedHashSet").contains(name) && !targs.isEmpty() && L.enums.contains(targs.get(0)) && recv.isEmpty())
                L.report(n, "jp-enum-key-hash-collection", name + "<" + String.join(", ", targs) + ">()（" + targs.get(0) + " 是 enum）");
            else if (L.android && Set.of("HashMap","hashMapOf","mutableMapOf").contains(name) && !targs.isEmpty()
                    && Set.of("Int","Long").contains(targs.get(0)) && recv.isEmpty())
                L.report(n, "jp-android-sparse-array", name + "<" + String.join(", ", targs) + ">()");
            else if (Set.of("ArrayList","HashSet","HashMap","mutableListOf","arrayListOf","mutableSetOf","hashSetOf",
                    "hashMapOf","mutableMapOf","arrayOf").contains(name) && targs.stream().anyMatch(BOXED_KT::contains) && recv.isEmpty()) {
                TSNode parent = parent(n);
                if (parent != null && typeIs(parent, "property_declaration")) {
                    TSNode vd = null;
                    for (TSNode c : children(parent)) if (typeIs(c, "variable_declaration")) { vd = c; break; }
                    TSNode scan = vd != null ? vd : parent;
                    boolean hasUser = false;
                    for (TSNode c : walk(scan)) if (typeIs(c, "user_type")) { hasUser = true; break; }
                    if (!hasUser && !skipBoxedCollection(L, n))
                        L.report(n, "jp-boxed-primitive-collection", name + "<" + String.join(", ", targs) + ">()");
                }
            }
            if ((CLIENT_FACTORY_TYPES.contains(name)
                    || (name.equals("Builder") && (recv.contains("OkHttp") || recv.contains("Retrofit")))
                    || ((recv.equals("OkHttpClient") || recv.equals("Retrofit") || recv.equals("MockRetrofit"))
                        && name.equals("Builder")))
                    && shouldFlagClientFactory(L, n))
                L.report(n, "jp-client-factory-recreate", (recv.isEmpty() ? name : recv + "." + name) + "(...)");
            if (!loop) {
                if (SHORT_CIRCUIT.contains(name) || CHAIN_OPS.contains(name)) chain(n);
                return;
            }
            List<TSNode> a = args(n);
            if ((recv.isEmpty() && "Regex".equals(name)) || "toRegex".equals(name)
                    || (recv.endsWith("Pattern") && "compile".equals(name)))
                L.report(n, "jp-regex-in-loop", text(L.src, n).substring(0, Math.min(40, text(L.src, n).length())));
            else if (Set.of("replaceAll","replaceFirst").contains(name) && a.size() == 2 && !typeIs(a.get(0), "call_expression"))
                L.report(n, "jp-regex-in-loop", "." + name + "(...)：Java 的 String." + name + " 每次编译正则");
            if ("format".equals(name) && ("String".equals(recv) || (!children(n).isEmpty() && typeIs(children(n).get(0), "navigation_expression")
                    && !named(children(n).get(0)).isEmpty() && typeIs(named(children(n).get(0)).get(0), "string_literal")))) {
                if (!skipFormatInLoop(L, n))
                    L.report(n, "jp-format-in-loop", text(L.src, n).substring(0, Math.min(40, text(L.src, n).length())));
            } else if ("formatted".equals(name)) {
                if (!skipFormatInLoop(L, n)) L.report(n, "jp-format-in-loop", ".formatted(...)");
            }
            if ("intern".equals(name) && a.isEmpty())
                L.report(n, "jp-string-intern-in-loop", (recv.isEmpty() ? "" : recv + ".") + "intern()");
            if (recv.isEmpty() && Set.of("println","print").contains(name)) {
                if (!skipLogInLoop(L, n, true)) L.report(n, "jp-log-in-loop", name + "(...)");
            } else if (Set.of("System.out","System.err").contains(recv)) {
                if (!skipLogInLoop(L, n, true)) L.report(n, "jp-log-in-loop", recv + "." + name + "(...)");
            } else if ("Log".equals(recv) && Set.of("v","d","i","w","e","wtf").contains(name)) {
                if (!skipLogInLoop(L, n, false)) L.report(n, "jp-log-in-loop", recv + "." + name + "(...)");
            } else if (Set.of("debug","info","trace","warn","error").contains(name)
                    && Pattern.compile("log", Pattern.CASE_INSENSITIVE).matcher(recv).find()
                    && !a.isEmpty() && isStringConcatArg(a.get(0))) {
                if (!skipLogInLoop(L, n, false))
                    L.report(n, "jp-log-in-loop", recv + "." + name + "(\"...\" + ...)");
            }
            if ((("Thread".equals(recv) || "SystemClock".equals(recv)) && "sleep".equals(name)) && inWhile(n))
                L.report(n, "jp-sleep-polling", recv + "." + name + "(...)");
            String recvLeaf = recv.contains(".") ? recv.substring(recv.lastIndexOf('.')+1) : recv;
            if (((recv.isEmpty() && EXPENSIVE_NEW.contains(name))
                    || Set.of("MessageDigest:getInstance","Cipher:getInstance","Mac:getInstance",
                    "DateTimeFormatter:ofPattern","NumberFormat:getInstance",
                    "ByteBuffer:allocate","ByteBuffer:allocateDirect","JsonMapper:builder").contains(recvLeaf + ":" + name))
                    && !skipExpensiveAlloc(L, n))
                L.report(n, "jp-expensive-alloc-in-loop", text(L.src, n).substring(0, Math.min(40, text(L.src, n).length())));
            else if (recv.isEmpty() && KT_ARRAY_CTORS.contains(name) && a.size() == 1
                    && text(L.src, a.get(0)).matches("\\d[\\d_]*")
                    && Integer.parseInt(text(L.src, a.get(0)).replace("_","")) >= BIG_BUFFER && !hasLambda(n)
                    && !skipExpensiveAlloc(L, n))
                L.report(n, "jp-expensive-alloc-in-loop", text(L.src, n) + "：常量大小的缓冲在每次迭代都重新分配");
            if ("copy".equals(name) && !recv.isEmpty()) {
                boolean namedArg = a.stream().anyMatch(c -> typeIs(c, "value_argument")
                        && children(c).stream().anyMatch(Ast::isIdent)
                        && text(L.src, c).contains("="));
                if (namedArg) L.report(n, "jp-data-copy-in-loop", text(L.src, n).substring(0, Math.min(50, text(L.src, n).length())));
            }
            if (hasLambda(n) && recv.isEmpty() && L.localFns.containsKey(name)) {
                boolean[] info = L.localFns.get(name);
                if (info[1] && !info[0]) L.report(n, "jp-lambda-to-non-inline-in-loop", name + " { ... }：" + name + " 不是 inline 函数");
            }
            if (SHORT_CIRCUIT.contains(name) || CHAIN_OPS.contains(name)) chain(n);
        }

        void chain(TSNode n) {
            TSNode p = parent(n);
            if (p != null && typeIs(p, "navigation_expression") && parent(p) != null && typeIs(parent(p), "call_expression"))
                return;
            List<String> ops = new ArrayList<>();
            TSNode cur = n;
            while (cur != null && typeIs(cur, "call_expression")) {
                ops.add(callee(cur).name());
                TSNode head = children(cur).isEmpty() ? null : children(cur).get(0);
                if (head != null && typeIs(head, "call_expression"))
                    head = children(head).isEmpty() ? null : children(head).get(0);
                if (head == null || !typeIs(head, "navigation_expression")) break;
                List<TSNode> named = named(head);
                cur = named.isEmpty() ? null : named.get(0);
            }
            java.util.Collections.reverse(ops);
            if (ops.contains("asSequence") || ops.contains("asFlow") || ops.contains("stream")) return;
            List<String> inter = ops.stream().filter(CHAIN_OPS::contains).toList();
            boolean terminalSc = !ops.isEmpty() && SHORT_CIRCUIT.contains(ops.get(ops.size()-1));
            if (inter.size() >= 3 || (inter.size() >= 2 && terminalSc))
                L.report(n, "jp-collection-chain", String.join(".", ops) + "：中间结果都是新的 List");
        }

        boolean inWhile(TSNode n) {
            TSNode p = parent(n);
            while (p != null) {
                if (typeIs(p, "while_statement") || typeIs(p, "do_while_statement")) return L.pollOnlyLoop(n, p);
                if (KT_FUNCS.contains(p.getType()) || typeIs(p, "lambda_literal")) return false;
                p = parent(p);
            }
            return false;
        }

        void catchBlock(TSNode n) {
            if (!L.inLoop(n)) return;
            List<String> types = children(n).stream().filter(c -> typeIs(c, "user_type")).map(this::typeName).toList();
            List<String> hit = types.stream().filter(CF_EXCEPTIONS::contains).toList();
            if (!hit.isEmpty()) L.report(n, "jp-exception-control-flow", "catch (e: " + String.join(" | ", hit) + ")");
        }

    }
}
