import 'dart:convert';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:airreader/services/pdf_importer.dart';

/// Result from a successful floor-plan image picker operation.
class FloorPlanImportResult {
  const FloorPlanImportResult({
    required this.bytes,
    required this.name,
    required this.widthPx,
    required this.heightPx,
  });

  final Uint8List bytes;
  final String name;
  final double widthPx;
  final double heightPx;
}

/// Service that handles picking and decoding floor-plan image files.
///
/// Supported formats: PNG, JPEG, SVG, PDF.
class FloorPlanImportService {
  const FloorPlanImportService._();

  /// Opens a native file-picker, reads the chosen image and decodes its
  /// pixel dimensions. Returns `null` if the user cancelled.
  static Future<FloorPlanImportResult?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      // PDF rendering via pdfx is not supported on web.
      allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', if (!kIsWeb) 'pdf'],
      withData: true,
      dialogTitle: 'Import Floor Plan',
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return null;

    final ext = (file.extension ?? '').toLowerCase();

    if (ext == 'pdf') {
      return _importPdf(bytes, file.name);
    } else if (ext == 'svg') {
      return _importSvg(bytes, file.name);
    } else {
      return _importBitmap(bytes, file.name);
    }
  }

  // ---------------------------------------------------------------------------
  // Bitmap (PNG / JPEG)
  // ---------------------------------------------------------------------------

  static Future<FloorPlanImportResult?> _importBitmap(
    Uint8List bytes,
    String name,
  ) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final width = frame.image.width.toDouble();
    final height = frame.image.height.toDouble();
    frame.image.dispose();
    codec.dispose();

    return FloorPlanImportResult(
      bytes: bytes,
      name: name,
      widthPx: width,
      heightPx: height,
    );
  }

  // ---------------------------------------------------------------------------
  // PDF – render page 1 to a high-resolution PNG
  // ---------------------------------------------------------------------------

  static Future<FloorPlanImportResult?> _importPdf(
    Uint8List bytes,
    String name,
  ) async {
    // Rendering delegated to the platform-conditional pdf_importer.
    // On web this always returns null (PDF is not supported on web).
    final pngBytes = await renderPdfFirstPageToPng(bytes);
    if (pngBytes == null) return null;

    // Re-decode from the rendered PNG to get true pixel dimensions.
    return _importBitmap(pngBytes, name);
  }

  // ---------------------------------------------------------------------------
  // SVG – rasterise to a 2048-px-wide PNG
  // ---------------------------------------------------------------------------

  static Future<FloorPlanImportResult?> _importSvg(
    Uint8List bytes,
    String name,
  ) async {
    const targetWidth = 2048.0;

    final svgString = utf8.decode(bytes);
    final loader = SvgStringLoader(svgString);
    final pictureInfo = await vg.loadPicture(loader, null);

    final srcW = pictureInfo.size.width;
    final srcH = pictureInfo.size.height;
    if (srcW <= 0 || srcH <= 0) {
      pictureInfo.picture.dispose();
      return null;
    }

    final scale = targetWidth / srcW;
    final outW = (srcW * scale).round();
    final outH = (srcH * scale).round();

    // Draw the SVG picture onto a scaled canvas and convert to PNG bytes.
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(scale, scale);
    canvas.drawPicture(pictureInfo.picture);
    pictureInfo.picture.dispose();

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW, outH);
    picture.dispose();

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) return null;

    return FloorPlanImportResult(
      bytes: byteData.buffer.asUint8List(),
      name: name,
      widthPx: outW.toDouble(),
      heightPx: outH.toDouble(),
    );
  }
}
