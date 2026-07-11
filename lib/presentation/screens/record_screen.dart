import 'package:flutter/material.dart';

import '../../core/constants/tamil_strings.dart';
import '../../data/models/store.dart';
import '../../data/services/ocr_service.dart';
import '../../data/services/screen_recorder_service.dart';
import 'review_screen.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final _recorder = ScreenRecorderService();
  final _ocr = OcrService();
  Store _selectedStore = Store.zepto;
  bool _recording = false;
  bool _processing = false;

  Future<void> _toggleRecording() async {
    if (!_recording) {
      final label = '${_selectedStore.key}_${DateTime.now().millisecondsSinceEpoch}';
      final started = await _recorder.start(label);
      setState(() => _recording = started);
      return;
    }

    setState(() {
      _recording = false;
      _processing = true;
    });

    final videoPath = await _recorder.stop();
    if (videoPath == null) {
      setState(() => _processing = false);
      return;
    }

    final candidates = await _ocr.extractFromVideo(videoPath);
    if (!mounted) return;

    setState(() => _processing = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ReviewScreen(store: _selectedStore, candidates: candidates),
      ),
    );
  }

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(TS.recordStore)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(TS.selectStore, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: Store.values.map((s) {
                final selected = s == _selectedStore;
                return ChoiceChip(
                  label: Text(s.label, style: const TextStyle(fontSize: 18)),
                  selected: selected,
                  onSelected: _recording
                      ? null
                      : (_) => setState(() => _selectedStore = s),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Text(
              TS.recordingInstructions,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            if (_processing)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(TS.processing, style: Theme.of(context).textTheme.bodyLarge),
                ],
              )
            else
              ElevatedButton.icon(
                icon: Icon(_recording ? Icons.stop_circle : Icons.videocam),
                label: Text(_recording ? TS.stopRecording : TS.startRecording),
                onPressed: _toggleRecording,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recording ? Colors.red : null,
                ),
              ),
            if (_recording) ...[
              const SizedBox(height: 16),
              Text(
                TS.recordingInProgress,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
