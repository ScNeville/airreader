// Routes to the platform-appropriate PDF renderer.
// On web PDF rendering is unsupported (returns null); on native pdfx is used.
export 'pdf_importer_stub.dart' if (dart.library.io) 'pdf_importer_native.dart';
