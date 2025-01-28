import 'dart:io';
import 'package:path/path.dart' as path;
import 'log_service.dart';

class XboxIsoExtractorService {
  static final LogService _logService = LogService();

  static Future<bool> extractIso(
    String isoPath, 
    String extractPath, 
    {
      Function(String)? onOperation,
      Function(String)? onStatus,
      Function(double)? onProgress,
    }
  ) async {
    try {
      final isoFile = File(isoPath);
      if (!await isoFile.exists()) {
        throw Exception('ISO file does not exist');
      }

      final extractDir = Directory(extractPath);
      if (!await extractDir.exists()) {
        await extractDir.create(recursive: true);
      }

      onOperation?.call('Starting ISO extraction...');
      onStatus?.call('Starting ISO extraction...');
      onProgress?.call(0.0);

      // Use extract-xiso if available
      try {
        final result = await Process.run('extract-xiso', ['-x', isoPath, extractPath]);
        
        if (result.exitCode != 0) {
          final errorMsg = 'Failed to extract ISO: ${result.stderr}';
          onOperation?.call(errorMsg);
          onStatus?.call(errorMsg);
          throw Exception(errorMsg);
        }

        const successMsg = 'ISO extracted successfully';
        onOperation?.call(successMsg);
        onStatus?.call(successMsg);
        onProgress?.call(100.0);
        _logService.log('$successMsg to $extractPath');
        return true;
      } catch (e) {
        if (e.toString().contains('No such file or directory')) {
          final errorMsg = 'extract-xiso is not installed. Please install it using your package manager.';
          onOperation?.call(errorMsg);
          onStatus?.call(errorMsg);
          throw Exception(errorMsg);
        }
        rethrow;
      }
    } catch (e) {
      _logService.log('Error extracting ISO: $e');
      onOperation?.call('Error extracting ISO: $e');
      onStatus?.call('Error extracting ISO: $e');
      onProgress?.call(0.0);
      return false;
    }
  }
} 