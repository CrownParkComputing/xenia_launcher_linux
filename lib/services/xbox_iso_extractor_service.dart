import 'dart:io';
import 'package:path/path.dart' as path;
import 'xiso_service.dart';

class XboxIsoExtractorService {
  static final _xisoService = XisoService();

  static Future<bool> extractIso(String source, String target, {
    bool excludeSysUpdate = true,
    Function(String)? onOperation,
    Function(String)? onStatus,
    Function(double)? onProgress,
  }) async {
    try {
      _xisoService.onOperation = onOperation;
      _xisoService.onStatus = onStatus;
      _xisoService.onIsoProgress = onProgress;

      return await _xisoService.extractXiso(source, target, excludeSysUpdate: excludeSysUpdate);
    } catch (e) {
      onStatus?.call('Error extracting ISO: $e');
      return false;
    }
  }

  static Future<XisoListAndSize> getFileList(String source, {
    bool excludeSysUpdate = true,
    Function(String)? onOperation,
    Function(String)? onStatus,
  }) async {
    try {
      _xisoService.onOperation = onOperation;
      _xisoService.onStatus = onStatus;

      return await _xisoService.getFileListAndSize(source, excludeSysUpdate: excludeSysUpdate);
    } catch (e) {
      onStatus?.call('Error getting file list: $e');
      return XisoListAndSize();
    }
  }

  static void abort() {
    _xisoService.abort();
  }
}
