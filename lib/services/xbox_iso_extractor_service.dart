import 'dart:io';
import 'package:path/path.dart' as path;

class XboxIsoExtractorService {
  static Future<void> launchIsoExtractor() async {
    try {
      final extractorPath = path.join(Directory.current.path, 'xbox_iso_extractor');
      final buildPath = path.join(extractorPath, 'build', 'linux', 'x64', 'release', 'bundle');
      final executablePath = path.join(buildPath, 'xbox_iso_extractor');
      
      // Check if the executable exists
      if (!File(executablePath).existsSync()) {
        print('Building Xbox ISO Extractor...');
        // Build the app first
        final buildResult = await Process.run(
          'flutter',
          ['build', 'linux', '--release'],
          workingDirectory: extractorPath,
        );
        
        if (buildResult.exitCode != 0) {
          print('Error building Xbox ISO Extractor: ${buildResult.stderr}');
          return;
        }
      }

      // Launch the executable
      if (File(executablePath).existsSync()) {
        await Process.start(
          executablePath,
          [],
          workingDirectory: buildPath,
          mode: ProcessStartMode.detached,
        );
      } else {
        print('Error: Executable not found at $executablePath');
      }

    } catch (e) {
      print('Failed to launch Xbox ISO Extractor: $e');
    }
  }
}
