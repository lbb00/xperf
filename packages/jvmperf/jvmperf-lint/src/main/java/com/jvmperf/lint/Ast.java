package com.jvmperf.lint;

import org.treesitter.TSNode;
import org.treesitter.TSParser;
import org.treesitter.TSTree;
import org.treesitter.TreeSitterJava;
import org.treesitter.TreeSitterKotlin;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;

/** Tree-sitter helpers; byte offsets are UTF-8 (same as the former Python tool). */
public final class Ast {
    private Ast() {}

    public static TSTree parse(String lang, byte[] src) {
        TSParser parser = new TSParser();
        parser.setLanguage("java".equals(lang) ? new TreeSitterJava() : new TreeSitterKotlin());
        String text = new String(src, StandardCharsets.UTF_8);
        return parser.parseString(null, text);
    }

    public static String text(byte[] src, TSNode n) {
        if (n == null || n.isNull()) return "";
        int a = Math.max(0, n.getStartByte());
        int b = Math.min(src.length, n.getEndByte());
        if (a >= b) return "";
        return new String(src, a, b - a, StandardCharsets.UTF_8);
    }

    public static List<TSNode> children(TSNode n) {
        List<TSNode> out = new ArrayList<>();
        if (n == null || n.isNull()) return out;
        for (int i = 0; i < n.getChildCount(); i++) {
            TSNode c = n.getChild(i);
            if (c != null && !c.isNull()) out.add(c);
        }
        return out;
    }

    public static List<TSNode> named(TSNode n) {
        List<TSNode> out = new ArrayList<>();
        if (n == null || n.isNull()) return out;
        for (int i = 0; i < n.getNamedChildCount(); i++) {
            TSNode c = n.getNamedChild(i);
            if (c != null && !c.isNull()) out.add(c);
        }
        return out;
    }

    public static TSNode field(TSNode n, String name) {
        if (n == null || n.isNull()) return null;
        TSNode c = n.getChildByFieldName(name);
        return (c == null || c.isNull()) ? null : c;
    }

    public static List<TSNode> walkList(TSNode root) {
        List<TSNode> out = new ArrayList<>();
        ArrayList<TSNode> stack = new ArrayList<>();
        stack.add(root);
        while (!stack.isEmpty()) {
            TSNode n = stack.remove(stack.size() - 1);
            out.add(n);
            List<TSNode> kids = children(n);
            for (int i = kids.size() - 1; i >= 0; i--) stack.add(kids.get(i));
        }
        return out;
    }

    public static Iterable<TSNode> walk(TSNode root) {
        return walkList(root);
    }

    public static boolean isIdent(TSNode n) {
        return typeIs(n, "identifier") || typeIs(n, "simple_identifier") || typeIs(n, "type_identifier");
    }

    public static String identText(byte[] src, TSNode n) {
        if (n == null || n.isNull()) return "";
        if (isIdent(n)) return text(src, n);
        // unwrap wrappers like directly_assignable_expression
        for (TSNode c : named(n)) if (isIdent(c)) return text(src, c);
        return text(src, n);
    }

    public static boolean typeIs(TSNode n, String type) {
        return n != null && !n.isNull() && type.equals(n.getType());
    }

    public static boolean typeIn(TSNode n, java.util.Set<String> types) {
        return n != null && !n.isNull() && types.contains(n.getType());
    }

    public static TSNode parent(TSNode n) {
        if (n == null || n.isNull()) return null;
        TSNode p = n.getParent();
        return (p == null || p.isNull()) ? null : p;
    }

    public static int line(TSNode n) {
        return n.getStartPoint().getRow() + 1;
    }

    public static int column(byte[] src, TSNode n) {
        int bytePos = n.getStartByte();
        int i = bytePos - 1;
        while (i >= 0 && src[i] != '\n') i--;
        int lineStart = i + 1;
        String prefix = new String(src, lineStart, bytePos - lineStart, StandardCharsets.UTF_8);
        return prefix.length() + 1;
    }

    public static boolean eq(TSNode a, TSNode b) {
        if (a == null || b == null) return a == b;
        return TSNode.eq(a, b);
    }
}
