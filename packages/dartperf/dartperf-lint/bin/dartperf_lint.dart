#!/usr/bin/env dart
import 'dart:io';
import 'package:dartperf_lint/scan.dart';

enum Sev { off, hint, error }

Sev? parseSev(String s) {
  switch (s) {
    case 'error':
      return Sev.error;
    case 'hint':
      return Sev.hint;
    case 'off':
      return Sev.off;
    default:
      return null;
  }
}

String sevName(Sev s) {
  switch (s) {
    case Sev.error:
      return 'error';
    case Sev.hint:
      return 'hint';
    case Sev.off:
      return 'off';
  }
}

Never usage(int code) {
  stderr.writeln(
    'Usage: dartperf_lint.dart PATH... [options]\n'
    '  --format text|json\n'
    '  --severity RULE=error|hint|off\n'
    '  --scope all|loop   (default: all)\n'
      '  --strict-hints\n'
    '  --no-fail',
  );
  exit(code);
}

bool applySev(Map<String, Sev> rs, String spec) {
  final eq = spec.indexOf('=');
  if (eq < 0) return false;
  final rule = spec.substring(0, eq);
  final sev = parseSev(spec.substring(eq + 1));
  if (sev == null || !rs.containsKey(rule)) return false;
  rs[rule] = sev;
  return true;
}

void main(List<String> args) {
  if (args.isEmpty) usage(2);
  final rs = <String, Sev>{
    'dt-list-add-empty': Sev.off,
    'dt-string-plus-hot': Sev.off,
    'dt-print-hot': Sev.off,
    'dt-growable-add-empty': Sev.hint,
  };
  var format = 'text';
  var strictHints = false;
  var noFail = false;
  var scope = "all";
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '-h' || a == '--help') usage(0);
    if (a == '--format') {
      i++;
      if (i >= args.length) usage(2);
      format = args[i];
      continue;
    }
    if (a.startsWith('--format=')) {
      format = a.substring(9);
      continue;
    }
    if (a == '--severity') {
      i++;
      if (i >= args.length || !applySev(rs, args[i])) usage(2);
      continue;
    }
    if (a.startsWith('--severity=')) {
      if (!applySev(rs, a.substring(11))) usage(2);
      continue;
    }
    if (a == '--strict-hints') {
      strictHints = true;
      continue;
    }
    if (a == '--no-fail') {
      noFail = true;
      continue;
    }
    if (a == '--scope') {
      i++;
      if (i >= args.length) usage(2);
      scope = args[i];
      if (scope != 'all' && scope != 'loop') usage(2);
      continue;
    }
    if (a.startsWith('--scope=')) {
      scope = a.substring(8);
      if (scope != 'all' && scope != 'loop') usage(2);
      continue;
    }
    if (a.startsWith('-')) usage(2);
    paths.add(a);
  }
  if (paths.isEmpty) usage(2);

  final findings = <Finding>[];
  for (final p in paths) {
    findings.addAll(scanPath(p, scope: scope));
  }

  var nerr = 0, nhint = 0;
  // Presize to avoid dt-growable-add-empty self-hit on checker emit path
  final text = List<String>.filled(findings.length, '', growable: true)..clear();
  final jsonRows = List<String>.filled(findings.length, '', growable: true)..clear();
  for (final f in findings) {
    final s = rs[f.rule] ?? Sev.hint;
    if (s == Sev.off) continue;
    if (s == Sev.error) {
      nerr++;
    } else {
      nhint++;
    }
    if (format == 'json') {
      jsonRows.add(
          '{"rule":"${f.rule}","severity":"${sevName(s)}","path":"${f.path}","line":${f.line},"message":"${f.message}"}');
    } else {
      text.add('${f.path}:${f.line}: ${sevName(s)} ${f.rule}: ${f.message}');
    }
  }
  if (format == 'json') {
    stdout.writeln('[${jsonRows.join(',')}]');
  } else {
    if (text.isNotEmpty) stdout.writeln(text.join('\n'));
    final shown = nerr + nhint;
    if (shown > 0) {
      stderr.writeln('$shown finding(s) ($nerr error, $nhint hint)');
    } else {
      stderr.writeln('ok');
    }
  }
  if (noFail) return;
  if (nerr > 0 || (strictHints && nhint > 0)) exit(1);
}
