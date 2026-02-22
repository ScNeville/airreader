import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:airreader/models/survey.dart';
import 'package:airreader/services/project_file_handler.dart';

/// Handles saving and loading survey project files (.airreader JSON).
class ProjectService {
  ProjectService._();

  static const _ext = 'airreader';

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  /// Prompt the user for a save location and write the project JSON.
  /// Returns the file path on success, null if the user cancelled.
  ///
  /// On web, the file is downloaded to the browser's default downloads folder
  /// and the survey name is returned as a virtual "path" for subsequent saves.
  static Future<String?> saveAs(Survey survey) async {
    final filename = '${survey.name}.$_ext';
    final json = const JsonEncoder.withIndent('  ').convert(survey.toJson());

    if (kIsWeb) {
      await writeProjectFile(filename, json);
      return filename;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Survey Project',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: [_ext],
    );
    if (path == null) return null;

    await writeProjectFile(path, json);
    return path;
  }

  /// Save the project to an already-known [path] without prompting.
  /// On web this triggers a fresh browser download.
  static Future<void> save(Survey survey, String path) async {
    final json = const JsonEncoder.withIndent('  ').convert(survey.toJson());
    await writeProjectFile(path, json);
  }

  // ---------------------------------------------------------------------------
  // Load
  // ---------------------------------------------------------------------------

  /// Prompt the user to pick a project file and return the loaded [Survey].
  /// Returns null if the user cancelled or the file is invalid.
  static Future<({Survey survey, String path})?> open() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Survey Project',
      type: FileType.custom,
      allowedExtensions: [_ext],
      // withData: true reads bytes while the security-scoped resource is still
      // open – avoids macOS sandbox path-access failures after the dialog closes
      // and is the only option on web.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    // file.path throws on web – use name as the virtual path instead.
    final path = kIsWeb ? file.name : (file.path ?? file.name);

    Survey? survey;
    if (file.bytes != null) {
      // Preferred path: bytes already loaded by the picker (sandbox-safe, web).
      try {
        final json = const Utf8Decoder().convert(file.bytes!);
        final map = jsonDecode(json) as Map<String, dynamic>;
        survey = Survey.fromJson(map);
      } catch (_) {
        return null;
      }
    } else if (!kIsWeb && file.path != null) {
      final json = await readProjectFile(file.path!);
      if (json != null) {
        try {
          final map = jsonDecode(json) as Map<String, dynamic>;
          survey = Survey.fromJson(map);
        } catch (_) {
          return null;
        }
      }
    }

    if (survey == null) return null;
    return (survey: survey, path: path);
  }
}
