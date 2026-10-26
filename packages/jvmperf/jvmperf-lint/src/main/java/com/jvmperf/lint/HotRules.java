package com.jvmperf.lint;

import org.treesitter.TSNode;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static com.jvmperf.lint.Ast.*;
import static com.jvmperf.lint.Engine.coldOrErrorMethod;
import static com.jvmperf.lint.Engine.inThrow;
import static com.jvmperf.lint.Engine.diagnosticMethod;

/** Rules jp-hot-heavy-alloc–jp-hot-payload-copy (jp-ui-text-append is context-independent). */
public class HotRules {
    static final Set<String> HEAVY_CTORS = Set.of(
            "Paint", "Path", "Rect", "RectF", "Matrix", "Canvas", "LinearGradient", "RadialGradient",
            "SweepGradient", "BitmapShader", "DashPathEffect", "Region", "ColorMatrix", "ColorMatrixColorFilter",
            "PorterDuffXfermode", "TextPaint");
    static final Set<HotAnalysis.RecvName> HEAVY_FACTORIES = Set.of(
            new HotAnalysis.RecvName("Bitmap", "createBitmap"),
            new HotAnalysis.RecvName("Bitmap", "createScaledBitmap"),
            new HotAnalysis.RecvName("Typeface", "create"),
            new HotAnalysis.RecvName("Typeface", "createFromAsset"),
            new HotAnalysis.RecvName("StaticLayout.Builder", "obtain"));
    static final Set<String> PRIM_ARRAYS_KT = Set.of(
            "ByteArray", "IntArray", "LongArray", "ShortArray", "CharArray", "FloatArray", "DoubleArray");
    static final Set<String> SYS_CALLS = Set.of(
            "getSystemService", "getRealMetrics", "getRealSize", "getEnabledAccessibilityServiceList",
            "getInstalledAccessibilityServiceList", "getRunningAppProcesses", "getRunningServices",
            "getInstalledPackages", "getInstalledApplications", "getPackageInfo", "getApplicationInfo",
            "queryIntentActivities", "queryIntentServices", "resolveActivity", "getIdentifier", "getPackagesForUid");
    static final Pattern SETTINGS_RE = Pattern.compile("^(android\\.provider\\.)?Settings\\.(Secure|System|Global)$");
    static final Set<String> POSTS = Set.of("post", "postDelayed", "runOnUiThread", "postOnAnimation", "postAtFrontOfQueue");
    static final Set<String> LOG_RECV = Set.of("Log", "android.util.Log", "Timber");
    static final Set<String> LOG_FNS = Set.of("v", "d", "i", "w", "e", "wtf");
    static final Pattern SAMPLED_RE = Pattern.compile(
            "%\\s*\\d{2,}|isLoggable|BuildConfig\\.DEBUG|is(Debug|Trace)Enabled|"
                    + "==\\s*(MotionEvent\\.)?ACTION_(DOWN|UP|CANCEL)\\b");
    static final Pattern TRUNC_RE = Pattern.compile(
            "(\\?\\.toString\\(\\))?\\?\\.(substring\\w*|split|lines|take(Last)?\\(\\s*\\d{1,2}\\s*\\))");

    final Engine.Linter L;
    final HotAnalysis H;
    final boolean isJava;

    public HotRules(Engine.Linter L, Set<String> loopTypes, Set<String> funcTypes) {
        this.L = L;
        this.H = new HotAnalysis(L, loopTypes, funcTypes);
        this.isJava = "java".equals(L.lang);
    }

    public HotAnalysis analysis() { return H; }

    public void run() {
        for (TSNode n : L.nodes) {
            String t = n.getType();
            if (H.isCall(n) || (isJava && (typeIs(n, "object_creation_expression") || typeIs(n, "array_creation_expression")))) {
                call(n);
            }
            if (!isJava && typeIs(n, "assignment")) uiTextKotlin(n);
            else if (isJava && typeIs(n, "method_invocation")) uiTextJava(n);
        }
    }

    boolean inSampledBranch(TSNode n) {
        TSNode p = parent(n);
        while (p != null && !H.isFn(p)) {
            if (typeIs(p, "if_statement") || typeIs(p, "if_expression")) {
                TSNode cond = field(p, "condition");
                String txt = cond != null ? text(L.src, cond) : text(L.src, p).split("\\{", 2)[0];
                if (txt.length() > 160) txt = txt.substring(0, 160);
                if (SAMPLED_RE.matcher(txt).find()) return true;
            }
            p = parent(p);
        }
        return false;
    }

    String fnText(TSNode n) {
        TSNode p = parent(n);
        while (p != null && !H.isFn(p)) p = parent(p);
        return text(L.src, p != null ? p : L.root);
    }

    boolean isFormat(String recv, String nm, TSNode n) {
        if (("String".equals(recv) && "format".equals(nm)) || "formatted".equals(nm)) return true;
        if ("format".equals(nm) && !isJava) {
            List<TSNode> kids = children(n);
            if (!kids.isEmpty() && typeIs(kids.get(0), "navigation_expression")) {
                List<TSNode> named = named(kids.get(0));
                return !named.isEmpty() && typeIs(named.get(0), "string_literal");
            }
        }
        return false;
    }

    void call(TSNode n) {
        HotAnalysis.Reason r = H.reason(n);
        if (r == null) return;
        // Error / throw / diagnostic helpers stay cold even if a hot caller reached them.
        if (inThrow(n) || coldOrErrorMethod(L, n) || diagnosticMethod(L, n)) return;
        String tag = H.hotText(r);
        HotAnalysis.RecvName cn = H.callee(n);
        String recv = cn.recv(), nm = cn.name();
        List<TSNode> args = typeIs(n, "array_creation_expression") ? List.of() : H.args(n);
        if (payloadCopy(n, recv, nm, args, tag)) return;

        if (isJava && typeIs(n, "object_creation_expression")) {
            String simple = nm.contains(".") ? nm.substring(nm.lastIndexOf('.') + 1) : nm;
            if (HEAVY_CTORS.contains(simple)) L.report(n, "jp-hot-heavy-alloc", "new " + nm + "(...) " + tag);
            else if ("ByteArrayOutputStream".equals(nm) && args.isEmpty())
                L.report(n, "jp-hot-heavy-alloc", "new ByteArrayOutputStream()（默认 32 字节，反复扩容复制）" + tag);
            else if ("StringBuilder".equals(nm) && args.isEmpty() && !"loop".equals(r.kind()))
                L.report(n, "jp-hot-heavy-alloc", "new StringBuilder() " + tag);
            return;
        }
        if (isJava && typeIs(n, "array_creation_expression")) {
            if (r.depth() == 0 && !"loop".equals(r.kind()) && !smallConst(text(L.src, n)))
                L.report(n, "jp-hot-heavy-alloc", text(L.src, n).substring(0, Math.min(40, text(L.src, n).length())) + " " + tag);
            return;
        }
        if (!isJava && recv.isEmpty() && HEAVY_CTORS.contains(nm)) L.report(n, "jp-hot-heavy-alloc", nm + "(...) " + tag);
        else if (!isJava && recv.isEmpty() && "ByteArrayOutputStream".equals(nm) && args.isEmpty())
            L.report(n, "jp-hot-heavy-alloc", "ByteArrayOutputStream()（默认 32 字节，反复扩容复制）" + tag);
        else if (!isJava && recv.isEmpty() && "StringBuilder".equals(nm) && args.isEmpty() && !"loop".equals(r.kind()))
            L.report(n, "jp-hot-heavy-alloc", "StringBuilder() " + tag);
        else if (!isJava && recv.isEmpty() && PRIM_ARRAYS_KT.contains(nm) && args.size() == 1 && r.depth() == 0
                && !"loop".equals(r.kind()) && !smallConst(text(L.src, args.get(0))))
            L.report(n, "jp-hot-heavy-alloc", nm + "(" + text(L.src, args.get(0)).substring(0, Math.min(30, text(L.src, args.get(0)).length())) + ") " + tag);

        String recvLeaf = "StaticLayout.Builder".equals(recv) ? recv : (recv.contains(".") ? recv.substring(recv.lastIndexOf('.') + 1) : recv);
        if (HEAVY_FACTORIES.contains(new HotAnalysis.RecvName(recvLeaf, nm))
                || HEAVY_FACTORIES.contains(new HotAnalysis.RecvName(recv, nm)))
            L.report(n, "jp-hot-heavy-alloc", recv + "." + nm + "(...) " + tag);

        if (!"loop".equals(r.kind()) && !inSampledBranch(n)) {
            if (isFormat(recv, nm, n))
                L.report(n, "jp-hot-format-log", (recv.isEmpty() ? "" : recv + ".") + nm + "(...) " + tag);
            else if (LOG_RECV.contains(recv) && LOG_FNS.contains(nm) && args.size() >= 2) {
                TSNode msg = args.get(1);
                TSNode inner = (!isJava && typeIs(msg, "value_argument") && !children(msg).isEmpty())
                        ? children(msg).get(children(msg).size() - 1) : msg;
                String txt = text(L.src, inner);
                if (typeIs(inner, "binary_expression") || (typeIs(inner, "string_literal") && txt.contains("$") && !isJava))
                    L.report(n, "jp-hot-format-log", recv + "." + nm + "(\"...$x\") " + tag);
            }
        }

        String recvLast = recv.contains(".") ? recv.substring(recv.lastIndexOf('.') + 1) : recv;
        if (SYS_CALLS.contains(nm) || (SETTINGS_RE.matcher(recv).matches() && nm.startsWith("get"))
                || ("Toast".equals(recvLast) && "makeText".equals(nm)))
            L.report(n, "jp-hot-system-call", (recv.isEmpty() ? "" : recv + ".") + nm + "(...) " + tag);

        if ("BitmapFactory".equals(recvLast) && nm.startsWith("decode")) {
            Map<String, Integer> want = Map.of(
                    "decodeByteArray", 4, "decodeStream", 3, "decodeFile", 2, "decodeResource", 3,
                    "decodeFileDescriptor", 3, "decodeResourceStream", 5);
            int need = want.getOrDefault(nm, 99);
            if (args.size() < need || !fnText(n).contains("inBitmap"))
                L.report(n, "jp-bitmap-decode-no-reuse", "BitmapFactory." + nm + "(...) 未设置 inBitmap " + tag);
        }

        if (POSTS.contains(nm) && !H.lambdaArgs(n).isEmpty() && !inSampledBranch(n))
            L.report(n, "jp-hot-post-lambda", (recv.isEmpty() ? "" : recv + ".") + nm + " { ... } " + tag);

        if ("toByteArray".equals(nm) && args.isEmpty() && recv != null && !recv.isEmpty() && recv.matches("\\w+")) {
            String ft = fnText(n);
            Pattern p1 = Pattern.compile("\\b" + Pattern.quote(recv) + "\\b\\s*(:\\s*ByteArrayOutputStream\\s*)?=\\s*(new\\s+)?ByteArrayOutputStream\\s*\\(");
            Pattern p2 = Pattern.compile("ByteArrayOutputStream\\s+" + Pattern.quote(recv) + "\\s*=");
            if (p1.matcher(ft).find() || p2.matcher(ft).find())
                L.report(n, "jp-baos-tobytearray-copy", recv + ".toByteArray() " + tag);
        }
    }

    boolean payloadCopy(TSNode n, String recv, String nm, List<TSNode> args, String tag) {
        String sizeTxt = null;
        String recvLast = recv.contains(".") ? recv.substring(recv.lastIndexOf('.') + 1) : recv;
        if ((("ByteBuffer".equals(recvLast) && ("allocate".equals(nm) || "allocateDirect".equals(nm))) && !args.isEmpty())
                || (!isJava && recv.isEmpty() && "ByteArray".equals(nm) && args.size() == 1)) {
            sizeTxt = text(L.src, args.get(0));
        } else if (isJava && typeIs(n, "array_creation_expression")) {
            sizeTxt = text(L.src, n);
        }
        if (sizeTxt != null) {
            Matcher m = Pattern.compile("\\b(\\w+)\\.(?:size|length|remaining\\(\\))").matcher(sizeTxt);
            while (m.find()) {
                String p = m.group(1);
                String ft = fnText(n);
                if (Pattern.compile("\\.put\\(\\s*" + Pattern.quote(p) + "\\s*[,)]|" + Pattern.quote(p)
                        + "\\.copyInto\\(|arraycopy\\(\\s*" + Pattern.quote(p) + "\\s*,").matcher(ft).find()) {
                    L.report(n, "jp-hot-payload-copy", "按 " + p + " 的大小新建缓冲并复制整个 " + p + " " + tag);
                    return true;
                }
            }
        }
        return false;
    }

    static boolean smallConst(String txt) {
        Matcher m = Pattern.compile("(\\d[\\d_]*)").matcher(txt);
        if (!m.find()) return false;
        return Pattern.compile("[\\s\\w.\\[\\]]*?(new\\s+\\w+\\s*\\[\\s*)?\\d[\\d_]*\\s*\\]?\\s*").matcher(txt).matches()
                && Integer.parseInt(m.group(1).replace("_", "")) < 256;
    }

    void uiTextKotlin(TSNode n) {
        List<TSNode> kids = children(n);
        if (kids.size() < 3) return;
        TSNode lhs = kids.get(0);
        // New grammar wraps assignable navigations in directly_assignable_expression.
        if (typeIs(lhs, "directly_assignable_expression")) {
            List<TSNode> inner = named(lhs);
            lhs = inner.isEmpty() ? lhs : inner.get(0);
        }
        if (!typeIs(lhs, "navigation_expression") && !typeIs(lhs, "postfix_expression")) {
            // Still allow plain text of lhs ending with .text
            String tgt0 = text(L.src, kids.get(0));
            if (!tgt0.endsWith(".text")) return;
            String recv0 = tgt0.substring(0, tgt0.length() - 5);
            String rhs0 = text(L.src, kids.get(kids.size() - 1));
            if (!rhs0.contains("+") && !rhs0.contains("$")) return;
            if (readsText(n, recv0, rhs0, List.of(recv0 + ".text")))
                L.report(n, "jp-ui-text-append", tgt0 + " = ... + 旧文本");
            return;
        }
        String tgt = text(L.src, kids.get(0));
        if (!tgt.endsWith(".text")) return;
        String recv = tgt.substring(0, tgt.length() - 5);
        String rhs = text(L.src, kids.get(kids.size() - 1));
        if (!rhs.contains("+") && !rhs.contains("$")) return;
        if (readsText(n, recv, rhs, List.of(recv + ".text")))
            L.report(n, "jp-ui-text-append", tgt + " = ... + 旧文本");
    }

    void uiTextJava(TSNode n) {
        HotAnalysis.RecvName cn = H.callee(n);
        if (!"setText".equals(cn.name()) || cn.recv().isEmpty()) return;
        List<TSNode> args = H.args(n);
        if (args.isEmpty()) return;
        String rhs = text(L.src, args.get(0));
        if (!rhs.contains("+")) return;
        if (readsText(n, cn.recv(), rhs, List.of(cn.recv() + ".getText()")))
            L.report(n, "jp-ui-text-append", cn.recv() + ".setText(... + 旧文本)");
    }

    boolean usesWhole(String txt, List<String> needles) {
        for (String x : needles) {
            Matcher m = Pattern.compile(Pattern.quote(x)).matcher(txt);
            while (m.find()) {
                String rest = txt.substring(m.end());
                if (!TRUNC_RE.matcher(rest).lookingAt()) return true;
            }
        }
        return false;
    }

    boolean readsText(TSNode n, String recv, String rhs, List<String> needles) {
        if (usesWhole(rhs, needles)) return true;
        String ft = fnText(n);
        Matcher vm = Pattern.compile("\\b([a-z_]\\w*)\\b").matcher(rhs);
        Set<String> vars = new java.util.HashSet<>();
        while (vm.find()) vars.add(vm.group(1));
        String needleAlt = String.join("|", needles.stream().map(Pattern::quote).toList());
        for (String v : vars) {
            if (Pattern.compile("\\b" + Pattern.quote(v) + "\\s*(:\\s*\\w+\\??\\s*)?=\\s*[^\\n;]*(" + needleAlt + ")")
                    .matcher(ft).find()) {
                Matcher m = Pattern.compile("\\b(val|var|String|CharSequence|final\\s+String)\\s+" + Pattern.quote(v) + "\\b[^\\n;]*")
                        .matcher(ft);
                if (m.find() && usesWhole(m.group(0), needles)) return true;
            }
        }
        return false;
    }
}
