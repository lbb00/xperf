import 'dart:io';
import 'dart:convert';

const rounds = 9;
const warm = 3;

double median(List<double> xs) {
  final a = [...xs]..sort();
  final n = a.length;
  final m = n ~/ 2;
  return n.isOdd ? a[m] : 0.5 * (a[m - 1] + a[m]);
}

double timeMany(int Function() fn) {
  for (var i = 0; i < warm; i++) fn();
  final samples = <double>[];
  var sink = 0;
  for (var r = 0; r < rounds; r++) {
    final sw = Stopwatch()..start();
    sink += fn();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  if (sink == 0x7fffffff) exit(2);
  return median(samples);
}

void emit(String dir, String rule, List<Map<String, Object>> pairs) {
  final ts = DateTime.now().toUtc().toIso8601String();
  double lastAfter = 1;
  final lines = <String>[];
  for (final p in pairs) {
    final role = p['role'] as String;
    final ms = (p['median_ms'] as num).toDouble();
    if (role == 'after') lastAfter = ms;
    final ratio = ms / lastAfter;
    final map = {
      'rule': rule,
      'case': p['case'],
      'role': role,
      'dart': Platform.version.split(' ').first,
      'median_ms': ms,
      'ops': p['ops'],
      'ratio': ratio,
      'ts': ts,
    };
    lines.add(jsonEncode(map));
    stdout.writeln('  $role ${p['case']} $ms ratio=$ratio');
  }
  final path = '$dir/$rule.jsonl';
  File(path).writeAsStringSync(lines.join('\n') + '\n');
  stdout.writeln('wrote $path');
}

void main() {
  final dir = Platform.environment['EVIDENCE_DIR'] ??
      '../../evidence'; // relative to examples/bench
  Directory(dir).createSync(recursive: true);
  stdout.writeln('dart ${Platform.version}');

  // dt-growable-add-empty empty growable + add vs filled
  final n4 = int.parse(Platform.environment['DT004_N'] ?? '200000');
  final src4 = List<int>.generate(n4, (i) => i);
  final before4 = timeMany(() {
    final out = <int>[];
    for (final x in src4) out.add(x);
    return out.length;
  });
  final after4 = timeMany(() {
    final out = List<int>.filled(src4.length, 0);
    for (var i = 0; i < src4.length; i++) out[i] = src4[i];
    return out.length;
  });
  emit(dir, 'dt-growable-add-empty', [
    {'case': 'list_filled', 'role': 'after', 'median_ms': after4, 'ops': n4},
    {'case': 'empty_add', 'role': 'before', 'median_ms': before4, 'ops': n4},
  ]);

  // dt-list-add-empty same smell with growable vs filled (alias of dt-growable-add-empty fixture names)
  final n1 = int.parse(Platform.environment['DT001_N'] ?? '200000');
  final src1 = List<int>.generate(n1, (i) => i);
  final before1 = timeMany(() {
    final out = <int>[];
    for (final x in src1) out.add(x);
    return out.length;
  });
  final after1 = timeMany(() {
    final out = List<int>.filled(src1.length, 0);
    for (var i = 0; i < src1.length; i++) out[i] = src1[i];
    return out.length;
  });
  emit(dir, 'dt-list-add-empty', [
    {'case': 'list_filled', 'role': 'after', 'median_ms': after1, 'ops': n1},
    {'case': 'add_loop_empty', 'role': 'before', 'median_ms': before1, 'ops': n1},
  ]);

  // dt-string-plus-hot string + vs StringBuffer
  final n2 = int.parse(Platform.environment['DT002_N'] ?? '30000');
  final before2 = timeMany(() {
    var s = '';
    for (var i = 0; i < n2; i++) s = s + i.toString();
    return s.length;
  });
  final after2 = timeMany(() {
    final buf = StringBuffer();
    for (var i = 0; i < n2; i++) buf.write(i);
    return buf.length;
  });
  emit(dir, 'dt-string-plus-hot', [
    {'case': 'string_buffer', 'role': 'after', 'median_ms': after2, 'ops': n2},
    {'case': 'string_plus', 'role': 'before', 'median_ms': before2, 'ops': n2},
  ]);

  // dt-print-hot print in loop vs once (discard)
  final n3 = int.parse(Platform.environment['DT003_N'] ?? '10000');
  final sink = File('/dev/null').openSync(mode: FileMode.write);
  final before3 = timeMany(() {
    var s = 0;
    for (var i = 0; i < n3; i++) {
      sink.writeStringSync('$i\n');
      s += i;
    }
    return s;
  });
  final after3 = timeMany(() {
    var s = 0;
    for (var i = 0; i < n3; i++) s += i;
    sink.writeStringSync('$s\n');
    return s;
  });
  sink.closeSync();
  emit(dir, 'dt-print-hot', [
    {'case': 'print_once', 'role': 'after', 'median_ms': after3, 'ops': n3},
    {'case': 'print_in_loop', 'role': 'before', 'median_ms': before3, 'ops': n3},
  ]);
}
