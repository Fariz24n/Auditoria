import 'dart:async';

class AiActivationService {
  AiActivationService._();

  static final AiActivationService instance = AiActivationService._();

  bool _isActive = false;
  bool get isActive => _isActive;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onActivationChanged => _controller.stream;

  void setActive(bool v) {
    if (_isActive == v) return;
    _isActive = v;
    _controller.add(_isActive);
  }

  void toggle() => setActive(!_isActive);

  void dispose() {
    _controller.close();
  }
}
