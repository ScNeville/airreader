// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';

/// Triggers a browser file download with [json] as the content.
/// The [path] is used as the download filename (basename only).
Future<void> writeProjectFile(String path, String json) async {
  final filename = path.contains('/') ? path.split('/').last : path;
  final bytes = utf8.encode(json);
  final blob = html.Blob([bytes], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename;
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// On web, files are always loaded via [FilePicker] bytes – this path is unused.
Future<String?> readProjectFile(String path) async => null;
