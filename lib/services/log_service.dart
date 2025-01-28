import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String level;

  LogEntry(this.message, this.level) : timestamp = DateTime.now();

  String get formattedTimestamp => 
    DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);

  @override
  String toString() => '[$formattedTimestamp] $level: $message';
}

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);

  void info(String message) {
    _addLog(message, 'INFO');
  }

  void error(String message) {
    _addLog(message, 'ERROR');
  }

  void warning(String message) {
    _addLog(message, 'WARNING');
  }

  void debug(String message) {
    _addLog(message, 'DEBUG');
  }

  void _addLog(String message, String level) {
    final entry = LogEntry(message, level);
    _logs.add(entry);
    debugPrint(entry.toString());
    notifyListeners();
  }

  void clear() {
    _logs.clear();
    notifyListeners();
  }

  void log(String message) {
    developer.log(message, name: 'XeniaLauncher');
  }
} 