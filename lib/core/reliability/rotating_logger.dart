import 'dart:async';
import 'dart:io';

/// Local rotating circular diagnostic logger.
/// Maximum 2MB per file, rotating between two files.
/// Strictly logs textual telemetry (FPS, inference ms, alerts).
/// NEVER logs or writes camera frame pixels.
class RotatingLogger {
  final Directory logDirectory;
  final int maxBytesPerFile;

  int _currentFileIndex = 1;
  File? _activeFile;
  IOSink? _sink;

  RotatingLogger({
    required this.logDirectory,
    this.maxBytesPerFile = 2 * 1024 * 1024, // 2MB
  });

  Future<void> init() async {
    if (!await logDirectory.exists()) {
      await logDirectory.create(recursive: true);
    }
    _activeFile = File('${logDirectory.path}/wayze_log_$_currentFileIndex.txt');
    _sink = _activeFile!.openWrite(mode: FileMode.append);
  }

  void log(String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp] [$tag] $message\n';

    _sink?.write(entry);
    _checkRotation();
  }

  void _checkRotation() {
    if (_activeFile == null) return;
    try {
      if (_activeFile!.existsSync() && _activeFile!.lengthSync() >= maxBytesPerFile) {
        _rotate();
      }
    } catch (_) {}
  }

  Future<void> _rotate() async {
    await _sink?.flush();
    await _sink?.close();

    _currentFileIndex = _currentFileIndex == 1 ? 2 : 1;
    _activeFile = File('${logDirectory.path}/wayze_log_$_currentFileIndex.txt');
    if (await _activeFile!.exists()) {
      await _activeFile!.delete(); // Overwrite oldest rotated chunk
    }
    _sink = _activeFile!.openWrite(mode: FileMode.write);
  }

  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
  }
}
