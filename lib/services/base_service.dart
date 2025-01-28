import 'package:flutter/foundation.dart';

abstract class BaseService {
  final List<Function(String)> _logListeners = [];

  void addLogListener(Function(String) listener) {
    _logListeners.add(listener);
  }

  void removeLogListener(Function(String) listener) {
    _logListeners.remove(listener);
  }

  void log(String message) {
    debugPrint('[Xenia Launcher] $message');
    for (var listener in _logListeners) {
      listener(message);
    }
  }
} 