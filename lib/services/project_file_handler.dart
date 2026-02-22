// Routes to the platform-appropriate file I/O implementation.
// On web the stub (browser download) is used; on native dart:io is used.
export 'project_file_handler_stub.dart'
    if (dart.library.io) 'project_file_handler_io.dart';
