import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

/// Renders the first page of a PDF to a PNG and returns the raw bytes.
/// Returns null if the document is empty or rendering fails.
Future<Uint8List?> renderPdfFirstPageToPng(Uint8List bytes) async {
  final document = await PdfDocument.openData(bytes);
  if (document.pagesCount == 0) {
    await document.close();
    return null;
  }

  final page = await document.getPage(1);
  final pageImage = await page.render(
    width: page.width * 2,
    height: page.height * 2,
    format: PdfPageImageFormat.png,
  );
  await page.close();
  await document.close();

  return pageImage?.bytes;
}
