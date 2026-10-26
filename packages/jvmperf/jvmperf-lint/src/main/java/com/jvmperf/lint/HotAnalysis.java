package com.jvmperf.lint;

import org.treesitter.TSNode;

import java.nio.charset.StandardCharsets;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.jvmperf.lint.Ast.*;
import static com.jvmperf.lint.Constants.COLD_OR_ERROR_METHOD_RE;

public class HotAnalysis {
    public static final Set<String> HOT_CALLBACKS = Set.of(
            "onTouch", "onTouchEvent", "dispatchTouchEvent", "onInterceptTouchEvent", "onGenericMotionEvent",
            "onDraw", "dispatchDraw", "onDrawForeground", "onDrawFrame", "onMeasure", "onLayout",
            "onScroll", "onScrolled", "onScrollChange", "onScrollChanged", "onFling", "onBindViewHolder",
            "onImageAvailable", "onFrameAvailable", "onPreviewFrame", "doFrame", "onSurfaceTextureUpdated",
            "onAudioAvailable", "onPeriodicNotification", "onSensorChanged", "onAccessibilityEvent",
            "onInputBufferAvailable", "onOutputBufferAvailable", "onAnimationUpdate", "onCaptureCompleted",
            "onCaptureProgressed", "onCharacteristicChanged", "onScanResult");
    public static final Set<String> HOT_REGISTRARS = Set.of(
            "setOnTouchListener", "setOnImageAvailableListener", "setOnFrameAvailableListener", "postFrameCallback",
            "postFrameCallbackDelayed", "setOnScrollChangeListener", "addUpdateListener", "setPreviewCallback",
            "setPreviewCallbackWithBuffer", "setOnGenericMotionListener", "addOnPreDrawListener", "collect",
            "collectLatest", "collectIndexed", "setOnDrawListener", "setFrameCallback");
    public static final Pattern HOT_PARAM_RE = Pattern.compile(
            "^on\\w*?(Frame|Jpeg|Image|Touch|Draw|Packet|Datagram|Sample|Audio|Pixels|Motion|Bytes)"
                    + "(Event|Available|Received|Decoded|Encoded|Ready)?s?$");
    public static final Set<String> HOT_ANNOTATIONS = Set.of(
            "HotPath", "Hot", "PerformanceCritical", "CriticalPath", "HotSpot");
    public static final Pattern HOT_MARK_RE = Pattern.compile("//\\s*jvmperf-lint:\\s*hot\\b");
    public static final Pattern ANNOT_RE = Pattern.compile("@\\s*([A-Za-z_][\\w.]*)");
    public static final Pattern INT_LIT_RE = Pattern.compile("(\\d[\\d_]*)L?");
    public static final Pattern TYPE_NAME_RE = Pattern.compile("[A-Z]\\w*");
    public static final Pattern PERIODIC_ARG_RE = Pattern.compile(
            "(?i)interval|backoff|retry|reconnect|period|heartbeat|poll|timeout|delay_ms|RETRY");
    public static final Set<RecvName> SLEEPS = Set.of(
            new RecvName("Thread", "sleep"), new RecvName("SystemClock", "sleep"),
            new RecvName("", "delay"), new RecvName("TimeUnit.MILLISECONDS", "sleep"),
            new RecvName("TimeUnit.SECONDS", "sleep"));
    public static final int MAX_DEPTH = 2;

    public record ClassFn(String cls, String fn) {}
    public record RecvName(String recv, String name) {}
    public record Reason(String text, int depth, String kind) {}
    public record FnInfo(TSNode node, String name, String cls) {}
    public record Range(int start, int end) {}

    final Engine.Linter L;
    final boolean isJava;
    final Set<String> loopTypes;
    final Set<String> funcTypes;
    final List<FnInfo> fns = new ArrayList<>();
    final Map<String, List<FnInfo>> byName = new HashMap<>();
    final Map<Range, Reason> hotFn = new HashMap<>();
    final Map<Range, Reason> hotLambda = new HashMap<>();
    final Map<ClassFn, String> exports = new HashMap<>();
    final Map<Range, Reason> cache = new HashMap<>();
    final Map<Range, Boolean> periodic = new HashMap<>();
    final Set<Integer> markedLines = new HashSet<>();

    public HotAnalysis(Engine.Linter L, Set<String> loopTypes, Set<String> funcTypes) {
        this.L = L;
        this.isJava = "java".equals(L.lang);
        this.loopTypes = loopTypes;
        this.funcTypes = funcTypes;
        String srcText = new String(L.src, StandardCharsets.UTF_8);
        String[] lines = srcText.split("\n", -1);
        for (int i = 0; i < lines.length; i++) {
            if (HOT_MARK_RE.matcher(lines[i]).find()) markedLines.add(i + 1);
        }
        collect();
        seed();
        if (HotConfig.CONFIG.propagate) propagate();
    }

    static Range key(TSNode n) { return new Range(n.getStartByte(), n.getEndByte()); }

    boolean isCall(TSNode n) {
        return isJava ? typeIs(n, "method_invocation") : typeIs(n, "call_expression");
    }

    RecvName callee(TSNode n) {
        if (isJava) {
            if (typeIs(n, "method_invocation")) {
                TSNode nm = field(n, "name");
                TSNode o = field(n, "object");
                return new RecvName(o != null ? text(L.src, o) : "", nm != null ? text(L.src, nm) : "");
            }
            if (typeIs(n, "object_creation_expression")) {
                TSNode t = field(n, "type");
                String tn = t != null ? text(L.src, t).split("<", 2)[0] : "";
                return new RecvName("new", tn);
            }
            return new RecvName("", "");
        }
        List<TSNode> kids = children(n);
        if (kids.isEmpty()) return new RecvName("", "");
        TSNode h = kids.get(0);
        if (isIdent(h)) return new RecvName("", text(L.src, h));
        if (typeIs(h, "navigation_expression") || typeIs(h, "postfix_expression")) {
            List<TSNode> ids = new ArrayList<>();
            for (TSNode c : walkList(h)) if (isIdent(c)) ids.add(c);
            if (!ids.isEmpty()) {
                TSNode last = ids.get(ids.size() - 1);
                String full = text(L.src, h);
                int cut = last.getStartByte() - h.getStartByte();
                String recv = cut > 0 ? full.substring(0, cut).replaceAll("[?.]+$", "").replaceAll("\\.$", "") : "";
                return new RecvName(recv, text(L.src, last));
            }
        }
        if (typeIs(h, "call_expression")) return callee(h);
        return new RecvName("", "");
    }

    List<TSNode> args(TSNode n) {
        if (isJava) {
            TSNode a = field(n, "arguments");
            return a != null ? named(a) : List.of();
        }
        for (TSNode c : children(n)) {
            if (typeIs(c, "value_arguments")) return named(c);
            if (typeIs(c, "call_suffix")) {
                for (TSNode s : children(c)) if (typeIs(s, "value_arguments")) return named(s);
            }
        }
        return List.of();
    }

    List<TSNode> lambdaArgs(TSNode n) {
        List<TSNode> res = new ArrayList<>();
        if (isJava) {
            for (TSNode a : args(n)) {
                if (typeIs(a, "lambda_expression")) res.add(a);
                else if (typeIs(a, "object_creation_expression")
                        && children(a).stream().anyMatch(c -> typeIs(c, "class_body"))) res.add(a);
            }
            return res;
        }
        for (TSNode c : children(n)) {
            if (typeIs(c, "annotated_lambda")) {
                for (TSNode x : children(c)) if (typeIs(x, "lambda_literal")) res.add(x);
            }
            if (typeIs(c, "call_suffix")) {
                for (TSNode s : children(c)) {
                    if (typeIs(s, "annotated_lambda")) {
                        for (TSNode x : children(s)) if (typeIs(x, "lambda_literal")) res.add(x);
                    }
                }
            }
        }
        for (TSNode a : args(n)) {
            for (TSNode x : children(a)) {
                if (typeIs(x, "lambda_literal") || typeIs(x, "anonymous_function") || typeIs(x, "object_literal"))
                    res.add(x);
            }
        }
        return res;
    }

    String fnName(TSNode fn) {
        if (isJava) {
            TSNode nm = field(fn, "name");
            return nm != null ? text(L.src, nm) : null;
        }
        for (TSNode c : children(fn)) if (isIdent(c)) return text(L.src, c);
        return null;
    }

    String containerName(TSNode fn) {
        TSNode p = parent(fn);
        while (p != null) {
            if (isJava && Set.of("class_declaration", "enum_declaration", "record_declaration", "interface_declaration").contains(p.getType())) {
                TSNode nm = field(p, "name");
                return nm != null ? text(L.src, nm) : null;
            }
            if (isJava && typeIs(p, "object_creation_expression")) return null;
            if (!isJava && (typeIs(p, "class_declaration") || typeIs(p, "object_declaration"))) {
                for (TSNode c : children(p)) if (isIdent(c)) return text(L.src, c);
                return null;
            }
            if (!isJava && typeIs(p, "object_literal")) return null;
            p = parent(p);
        }
        return null;
    }

    Set<String> annotations(TSNode fn) {
        for (TSNode c : children(fn)) {
            if (typeIs(c, "modifiers")) {
                Set<String> found = new HashSet<>();
                Matcher m = ANNOT_RE.matcher(text(L.src, c));
                while (m.find()) found.add(m.group(1).replaceAll(".*\\.", ""));
                return found;
            }
        }
        return Set.of();
    }

    boolean isFn(TSNode n) {
        if (isJava) return typeIs(n, "method_declaration") || typeIs(n, "constructor_declaration");
        return typeIs(n, "function_declaration");
    }

    void collect() {
        for (TSNode n : L.nodes) {
            if (isFn(n)) {
                String nm = fnName(n);
                if (nm != null) {
                    FnInfo info = new FnInfo(n, nm, containerName(n));
                    fns.add(info);
                    byName.computeIfAbsent(nm, k -> new ArrayList<>()).add(info);
                }
            }
        }
    }

    void seed() {
        HotConfig cfg = HotConfig.CONFIG;
        for (FnInfo info : fns) {
            TSNode fn = info.node;
            String nm = info.name;
            String cls = info.cls;
            int line = Ast.line(fn);
            TSNode mods = null;
            for (TSNode c : children(fn)) if (typeIs(c, "modifiers")) { mods = c; break; }
            int firstLine = mods != null ? mods.getEndPoint().getRow() + 1 : line;
            if (cfg.callbacks.contains(nm)) {
                hotFn.put(key(fn), new Reason(nm, 0, "callback"));
            } else if (!java.util.Collections.disjoint(annotations(fn), HOT_ANNOTATIONS)
                    || markedLines.contains(line - 1) || markedLines.contains(line) || markedLines.contains(firstLine)) {
                hotFn.put(key(fn), new Reason(nm + "(标注 hot)", 0, "mark"));
            } else if (cfg.hotFnRe != null && cfg.hotFnRe.matcher(nm).find()) {
                hotFn.put(key(fn), new Reason(nm + "(--hot-fn)", 0, "mark"));
            } else if (cls != null && cfg.external.containsKey(new ClassFn(cls, nm))) {
                hotFn.put(key(fn), new Reason(cfg.external.get(new ClassFn(cls, nm)) + " → " + cls + "." + nm, 1, "external"));
            }
        }
        for (TSNode n : L.nodes) {
            if (isCall(n) || (isJava && typeIs(n, "object_creation_expression"))) {
                RecvName cn = callee(n);
                if (cfg.registrars.contains(cn.name())) {
                    for (TSNode lam : lambdaArgs(n)) {
                        hotLambda.put(key(lam), new Reason(cn.name() + "{}", 0, "lambda"));
                    }
                }
                if (!isJava) {
                    for (TSNode a : args(n)) {
                        List<TSNode> kids = children(a);
                        if (kids.size() >= 3 && isIdent(kids.get(0)) && !kids.get(1).isNamed()
                                && "=".equals(kids.get(1).getType())
                                && typeIs(kids.get(kids.size() - 1), "lambda_literal")
                                && HOT_PARAM_RE.matcher(text(L.src, kids.get(0))).matches()) {
                            hotLambda.put(key(kids.get(kids.size() - 1)),
                                    new Reason(text(L.src, kids.get(0)) + " = {}", 0, "lambda"));
                        }
                    }
                }
            } else if (!isJava && typeIs(n, "assignment")) {
                List<TSNode> kids = children(n);
                if (kids.size() >= 3 && typeIs(kids.get(kids.size() - 1), "lambda_literal")) {
                    String tgt = text(L.src, kids.get(0));
                    int dot = tgt.lastIndexOf('.');
                    String leaf = dot >= 0 ? tgt.substring(dot + 1) : tgt;
                    if (HOT_PARAM_RE.matcher(leaf).matches()) {
                        hotLambda.put(key(kids.get(kids.size() - 1)), new Reason(leaf + " = {}", 0, "lambda"));
                    }
                }
            } else if (isJava && typeIs(n, "assignment_expression")) {
                TSNode r = field(n, "right");
                TSNode lft = field(n, "left");
                if (r != null && typeIs(r, "lambda_expression") && lft != null) {
                    String leaf = text(L.src, lft);
                    int dot = leaf.lastIndexOf('.');
                    leaf = dot >= 0 ? leaf.substring(dot + 1) : leaf;
                    if (HOT_PARAM_RE.matcher(leaf).matches()) {
                        hotLambda.put(key(r), new Reason(leaf + " = ...", 0, "lambda"));
                    }
                }
            }
        }
    }


    boolean periodicLoop(TSNode loop) {
        Range k = key(loop);
        Boolean r = periodic.get(k);
        if (r == null) {
            r = periodicScan(loop);
            periodic.put(k, r);
        }
        return r;
    }

    boolean periodicScan(TSNode loop) {
        for (TSNode c : walk(loop)) {
            if (!isCall(c)) continue;
            RecvName cn = callee(c);
            if ("accept".equals(cn.name()) && args(c).isEmpty()) return true;
            if (SLEEPS.contains(cn) || ("sleep".equals(cn.name()) && cn.recv().startsWith("TimeUnit"))) {
                List<TSNode> a = args(c);
                String txt = a.isEmpty() ? "" : text(L.src, a.get(0));
                Matcher m = INT_LIT_RE.matcher(txt.strip());
                if ((m.matches() && Integer.parseInt(m.group(1).replace("_", "")) >= 500)
                        || PERIODIC_ARG_RE.matcher(txt).find()) return true;
            }
        }
        return false;
    }

    boolean isLoop(TSNode p) {
        if (loopTypes.contains(p.getType())) return true;
        if (!isJava && typeIs(p, "annotated_lambda") && parent(p) != null && typeIs(parent(p), "call_expression")) {
            return Set.of("repeat", "forEach", "forEachIndexed", "onEach").contains(callee(parent(p)).name());
        }
        return false;
    }

    Reason reason(TSNode n) {
        Range k = key(n);
        if (cache.containsKey(k)) return cache.get(k);
        Reason r = null;
        TSNode p = parent(n);
        while (p != null) {
            if (typeIs(p, "catch_clause") || typeIs(p, "catch_block")) { r = null; break; }
            if (typeIs(p, "throw_statement") || typeIs(p, "throw_expression") || isThrowJump(p)) { r = null; break; }
            if (isLoop(p) && !periodicLoop(p)) {
                r = new Reason("循环@" + Ast.line(p), 0, "loop");
                break;
            }
            Range kp = key(p);
            if (hotLambda.containsKey(kp)) { r = hotLambda.get(kp); break; }
            if (isFn(p)) {
                Reason hr = hotFn.get(kp);
                // Propagated heat into cold/error helpers is usually a false positive.
                if (hr != null && "prop".equals(hr.kind()) && coldMethodName(fnName(p))) r = null;
                else r = hr;
                break;
            }
            p = parent(p);
        }
        cache.put(k, r);
        return r;
    }

    static boolean coldMethodName(String nm) {
        return nm != null && !nm.isEmpty() && COLD_OR_ERROR_METHOD_RE.matcher(nm).matches();
    }

    static boolean isThrowJump(TSNode n) {
        if (!typeIs(n, "jump_expression")) return false;
        for (TSNode c : children(n)) if ("throw".equals(c.getType())) return true;
        return false;
    }

    String hotText(Reason r) { return "[热: " + r.text() + "]"; }

    Iterable<TSNode> regionCalls(TSNode region) {
        List<TSNode> out = new ArrayList<>();
        ArrayDeque<TSNode> stack = new ArrayDeque<>(children(region));
        while (!stack.isEmpty()) {
            TSNode x = stack.pop();
            if (isFn(x) || typeIs(x, "catch_clause") || typeIs(x, "catch_block")
                    || typeIs(x, "throw_statement") || typeIs(x, "throw_expression") || isThrowJump(x)) continue;
            if (isCall(x)) out.add(x);
            for (TSNode c : children(x)) stack.push(c);
        }
        return out;
    }

    void propagate() {
        List<Object[]> work = new ArrayList<>();
        for (FnInfo info : fns) {
            Reason r = hotFn.get(key(info.node));
            if (r != null) work.add(new Object[]{info.node, r});
        }
        for (TSNode n : L.nodes) {
            Range k = key(n);
            if (hotLambda.containsKey(k)) work.add(new Object[]{n, hotLambda.get(k)});
            else if (isLoop(n) && !periodicLoop(n)) {
                String owner = ownerName(n);
                String t = owner != null ? owner + ":循环@" + Ast.line(n) : "循环@" + Ast.line(n);
                work.add(new Object[]{n, new Reason(t, 0, "loop")});
            }
        }
        Set<String> seen = new HashSet<>();
        while (!work.isEmpty()) {
            Object[] item = work.remove(0);
            TSNode region = (TSNode) item[0];
            Reason r = (Reason) item[1];
            int limit = MAX_DEPTH + ("external".equals(r.kind()) ? 1 : 0);
            if (r.depth() >= limit) continue;
            for (TSNode c : regionCalls(region)) {
                if (reasonBlocked(c, region)) continue;
                RecvName cn = callee(c);
                List<FnInfo> targets = new ArrayList<>();
                if (("".equals(cn.recv()) || "this".equals(cn.recv())) && byName.containsKey(cn.name())) {
                    for (FnInfo info : byName.get(cn.name())) {
                        if (!eq(info.node, region)) targets.add(info);
                    }
                } else if (!cn.recv().isEmpty() && Character.isUpperCase(cn.recv().charAt(0))
                        && TYPE_NAME_RE.matcher(cn.recv()).matches()) {
                    for (FnInfo info : byName.getOrDefault(cn.name(), List.of())) {
                        if (Objects.equals(info.cls, cn.recv())) targets.add(info);
                    }
                    if (targets.isEmpty()) exports.putIfAbsent(new ClassFn(cn.recv(), cn.name()), r.text());
                }
                for (FnInfo info : targets) {
                    if (coldMethodName(info.name)) continue; // error/toString/dump — not hot
                    Range kf = key(info.node);
                    Reason existing = hotFn.get(kf);
                    if (existing != null && existing.depth() <= r.depth() + 1) continue;
                    Reason nr = new Reason(r.text() + " → " + info.name, r.depth() + 1, "prop");
                    hotFn.put(kf, nr);
                    cache.clear();
                    String sk = kf.start() + ":" + kf.end() + ":" + nr.depth();
                    if (seen.add(sk)) work.add(new Object[]{info.node, nr});
                }
            }
        }
    }

    boolean reasonBlocked(TSNode call, TSNode region) {
        TSNode p = parent(call);
        while (p != null && !eq(p, region)) {
            if (isLoop(p) && periodicLoop(p)) return true;
            p = parent(p);
        }
        return false;
    }

    String ownerName(TSNode n) {
        TSNode p = parent(n);
        while (p != null) {
            if (isFn(p)) return fnName(p);
            p = parent(p);
        }
        return null;
    }
}
