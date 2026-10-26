import 'dart:typed_data';

Future<Uint8List> consolidateBytes(Stream<Uint8List> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

void collectHeaders(dynamic responseHeaders, List<List<int>> pairs) {
  for (final header in pairs) {
    responseHeaders.add(header[0], header[1]);
  }
}

void markDone(Set<int> toBeRemoved, Iterable<int> ids) {
  for (final id in ids) {
    toBeRemoved.add(id);
  }
}
