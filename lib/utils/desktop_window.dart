// Routes to the platform-appropriate window-management implementation.
// On web the stub is used (no-op); on native the window_manager setup runs.
export 'desktop_window_stub.dart'
    if (dart.library.io) 'desktop_window_native.dart';
