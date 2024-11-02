import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static final List<String> _logs = [];
  static void addLog(String message) {
    _logs.insert(0, "${DateTime.now()}: $message");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _logs.clear();
              });
            },
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_logs[index]),
            ),
          );
        },
      ),
    );
  }
}

// Custom log handler that both prints to console and adds to logs screen
void log(String message) {
  developer.log(message);
  _LogsScreenState.addLog(message);
}
