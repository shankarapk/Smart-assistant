import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around Android's MediaProjection screen recording.
///
/// Important: this service does nothing but record the pixels already on
/// screen while the user manually operates their own store app (already
/// logged in by them, in their own session). It never touches the store's
/// network traffic, credentials, or APIs. The output is a local .mp4 file,
/// deleted right after OCR extraction runs on it.
class ScreenRecorderService {
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  Future<bool> _ensurePermissions() async {
    final notif = await Permission.notification.request(); // Android 13+ FGS notif
    return notif.isGranted || notif.isLimited || notif.isPermanentlyDenied == false;
  }

  /// Starts recording. [sessionLabel] is just used to name the output file,
  /// e.g. "zepto_2026_07_11".
  Future<bool> start(String sessionLabel) async {
    if (_isRecording) return false;
    await _ensurePermissions();
    final started = await FlutterScreenRecording.startRecordScreen(sessionLabel);
    _isRecording = started;
    return started;
  }

  /// Stops recording and returns the local file path of the captured video.
  Future<String?> stop() async {
    if (!_isRecording) return null;
    final path = await FlutterScreenRecording.stopRecordScreen;
    _isRecording = false;
    return path.isEmpty ? null : path;
  }
}
