import 'package:window_manager/window_manager.dart';

/// Thin abstraction over the platform window so [AppController]'s show/hide
/// logic is unit-testable without platform channels.
abstract class WindowController {
  Future<void> show();
  Future<void> hide();
  Future<void> destroy();
}

/// Real implementation backed by `window_manager`.
class RealWindowController implements WindowController {
  const RealWindowController();

  @override
  Future<void> show() => windowManager.show();

  @override
  Future<void> hide() => windowManager.hide();

  @override
  Future<void> destroy() => windowManager.destroy();
}
