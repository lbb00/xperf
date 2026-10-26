import 'dart:io';

class Finding {
  final String rule;
  final String path;
  final int line;
  final String message;
  Finding(this.rule, this.path, this.line, this.message);
}

const msg001 =
    'List add / grow in loop without capacity cue; prefer List.filled / fixed length';
const msg002 = 'string + in loop; prefer StringBuffer';
const msg003 = 'print in loop; gate or buffer';
const msg004 =
    'empty List grown with add in size-hinted loop; prefer List.filled / fixed length';

bool isDart(String path) => path.endsWith('.dart');

bool skipDir(String name) {
  if (name == '.git' ||
      name == '.dart_tool' ||
      name == 'node_modules' ||
      name == 'vendor' ||
      name == 'build' ||
      name == 'test' ||
      name == 'tests' ||
      name == 'example' ||
      name == 'examples' ||
      name == 'example_dart' ||
      name == 'example_flutter' ||
      name == 'scripts' ||
      name == 'benchmark' ||
      name == 'benchmarks' ||
      name == 'integration_test' ||
      name == 'fixtures' ||
      name == 'docs') {
    return true;
  }
  // monorepo test-only packages: http_client_conformance_tests, …
  if (name.endsWith('_tests') || name.contains('conformance_test')) return true;
  return false;
}

String stripLineComment(String s) {
  final out = StringBuffer();
  var inStr = false;
  var q = '';
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inStr) {
      out.write(c);
      if (c == '\\' && i + 1 < s.length) {
        out.write(s[++i]);
        continue;
      }
      if (c == q) inStr = false;
      continue;
    }
    if (c == '"' || c == "'") {
      inStr = true;
      q = c;
      out.write(c);
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') break;
    out.write(c);
  }
  return out.toString();
}

bool looksStreamAdd(String code) {
  // StreamController / Sink / Subject / *C (rx-ish) .add — not List grow
  if (RegExp(r'\b(controller|sink|subject)\w*\.add\s*\(', caseSensitive: false)
      .hasMatch(code)) {
    return true;
  }
  if (RegExp(r'\b\w+(Controller|Sink|Subject|StreamController)\.add\s*\(')
      .hasMatch(code)) {
    return true;
  }
  // common corpus: _incomingMessagesC.add / xxxC.add
  if (RegExp(r'\b_?\w+C\.add\s*\(').hasMatch(code)) return true;
  if (RegExp(r'\.(addError|addStream|addListener|addPostFrameCallback)\s*\(')
      .hasMatch(code)) {
    return true;
  }
  // BytesBuilder / StringBuffer / Headers / Set / HttpHeaders — not List grow (G3 FP)
  if (RegExp(
          r'\b(builder|bytesBuilder|buffer|stringBuffer|responseHeaders|headers|toBeRemoved|'
          r'headerMap|cookieJar)\.add\s*\(',
          caseSensitive: false)
      .hasMatch(code)) {
    return true;
  }
  if (RegExp(r'\b(BytesBuilder|StringBuffer|HttpHeaders)\b').hasMatch(code) &&
      RegExp(r'\.add\s*\(').hasMatch(code)) {
    return true;
  }
  // headers[key] ??= []).add / map-of-lists header accumulate
  if (RegExp(r'\]\)?\s*\.add\s*\(').hasMatch(code)) return true;
  if (RegExp(r'headers\.add\s*\(').hasMatch(code)) return true;
  return false;
}

List<Finding> scanFile(String path) {
  final lines = File(path).readAsLinesSync();
  final out = <Finding>[];
  var depth = 0;
  var inLoop = 0;
  var loopHint = false;
  final binds = <String, int>{}; // name -> depth
  final fired004 = <String>{};
  for (var idx = 0; idx < lines.length; idx++) {
    final lineNo = idx + 1;
    final code = stripLineComment(lines[idx]);
    final opens = '{'.allMatches(code).length;
    final closes = '}'.allMatches(code).length;

    // Drop out-of-scope binds
    binds.removeWhere((_, d) => d > depth);

    // Empty list binds: final/var x = <T>[] or = []
    for (final m in RegExp(
            r'\b(?:final|var)\s+([A-Za-z_]\w*)\s*=\s*(?:<[^>]+>)?\s*\[\]')
        .allMatches(code)) {
      binds[m.group(1)!] = depth;
    }

    final loopHere = RegExp(r'\b(for|while)\b').hasMatch(code);
    if (loopHere) {
      inLoop = depth + 1;
      loopHint = RegExp(
              r'for\s*\(\s*(?:var|final|int)?\s*\w+\s*=\s*0\s*;|for\s*\(\s*(?:var|final)?\s*\w+\s+in\s+|<\s*\w*\.?length|\.length\b')
          .hasMatch(code);
    }
    if (inLoop > 0 && depth >= inLoop) {
      // avoid matching `??= []` map-of-lists idiom (G3 FP)
      final growAssign = RegExp(r'(?<![?=])=\s*(?:<\w+>)?\s*\[]').hasMatch(code);
      final listAdd = RegExp(r'\.add\s*\(').hasMatch(code) && !looksStreamAdd(code);
      if (listAdd || growAssign) {
        out.add(Finding('dt-list-add-empty', path, lineNo, msg001));
      }
      final stringyAssign =
          RegExp(r'\b(s|str|msg|text|out|result|name|buf)\w*\s*=').hasMatch(code);
      final accum = RegExp(r'\b(\w+)\s*=\s*\1\s*\+').hasMatch(code);
      if (accum ||
          ((code.contains('"') || code.contains("'") || stringyAssign) &&
              code.contains('+') &&
              code.contains('=') &&
              !RegExp(r'\+\s*\d').hasMatch(code) &&
              !code.contains('++') &&
              !code.contains('+='))) {
        out.add(Finding('dt-string-plus-in-loop', path, lineNo, msg002));
      }
      if (RegExp(r'\bprint\s*\(').hasMatch(code)) {
        out.add(Finding('dt-print-in-loop', path, lineNo, msg003));
      }
      // dt-growable-add-empty: empty bind + .add in size-hinted loop
      if (loopHint) {
        for (final name in binds.keys.toList()) {
          if (fired004.contains(name)) continue;
          if (looksStreamAdd(code)) continue;
          if (RegExp('\\b${RegExp.escape(name)}\\.add\\s*\\(').hasMatch(code)) {
            fired004.add(name);
            out.add(Finding('dt-growable-add-empty', path, lineNo, msg004));
          }
        }
      }
    }
    depth += opens - closes;
    if (depth < 0) depth = 0;
    if (inLoop > 0 && depth < inLoop) {
      inLoop = 0;
      loopHint = false;
    }
  }
  return out;
}

List<Finding> scanPath(String root) {
  final type = FileSystemEntity.typeSync(root);
  if (type == FileSystemEntityType.file) {
    return isDart(root) ? scanFile(root) : [];
  }
  if (type != FileSystemEntityType.directory) return [];
  final rootPath = Directory(root).absolute.path;
  final files = <String>[];
  for (final ent in Directory(root).listSync(recursive: true, followLinks: false)) {
    if (ent is! File || !isDart(ent.path)) continue;
    final abs = ent.absolute.path;
    var rel = abs;
    if (abs.startsWith(rootPath)) {
      rel = abs.substring(rootPath.length);
      if (rel.startsWith(Platform.pathSeparator)) rel = rel.substring(1);
    }
    final relParts = rel.split(Platform.pathSeparator).where((s) => s.isNotEmpty);
    if (relParts.any(skipDir)) continue;
    final base = ent.uri.pathSegments.isEmpty ? ent.path : ent.uri.pathSegments.last;
    if (base.endsWith('_test.dart')) continue;
    files.add(ent.path);
  }
  return files.expand(scanFile).toList();
}
