import 'dart:io';

/// Writes [json] to the file at [path].
Future<void> writeProjectFile(String path, String json) =>
    File(path).writeAsString(json, flush: true);

/// Reads the file at [path] and returns its contents, or null on error.
Future<String?> readProjectFile(String path) async {
  try {
    return await File(path).readAsString();
  } catch (_) {
    return null;
  }
}
