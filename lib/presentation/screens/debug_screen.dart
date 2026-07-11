import 'dart:io';
import 'package:flutter/material.dart';

import '../../core/constants/tamil_strings.dart';
import '../../data/models/store.dart';
import '../../data/services/ocr_service.dart';
import 'review_screen.dart';

/// Shown right after a recording is processed. Lets you actually see what
/// the screen recording captured and what OCR read off each frame, so you
/// can tell whether the problem is a blank/black recording (store app
/// blocking capture), a price format OCR didn't match, or something else —
/// instead of just getting an empty result with no explanation.
class DebugScreen extends StatelessWidget {
  final Store store;
  final OcrExtractionResult result;

  const DebugScreen({super.key, required this.store, required this.result});

  @override
  Widget build(BuildContext context) {
    final hasFrames = result.debugFrames.isNotEmpty;
    final hasAnyText = result.debugFrames.any((f) => f.rawTextBlocks.isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: Text('பரிசோதனை — ${store.label}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('சுருக்கம் (Summary)', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Frames captured: ${result.frameCount}'),
                  Text('Price-like items found: ${result.candidates.length}'),
                  const SizedBox(height: 12),
                  if (!hasFrames)
                    const Text(
                      '⚠️ No frames were captured at all. The recording may '
                      'have failed to start, or stopped immediately — try '
                      'again and confirm you see the red recording indicator '
                      'in your status bar while browsing the store app.',
                      style: TextStyle(color: Colors.orange),
                    )
                  else if (!hasAnyText)
                    const Text(
                      '⚠️ Frames were captured but OCR found no text on any '
                      'of them. This usually means the recording came out '
                      'blank/black — some apps block screen capture on '
                      'certain screens. Check the frame thumbnails below.',
                      style: TextStyle(color: Colors.orange),
                    )
                  else if (result.candidates.isEmpty)
                    const Text(
                      '⚠️ OCR found text, but none of it matched the price '
                      'pattern (₹ or Rs followed by a number). Check the raw '
                      'text below — the store may format prices differently '
                      'than expected.',
                      style: TextStyle(color: Colors.orange),
                    )
                  else
                    const Text('✅ Looks healthy — check the Review screen.',
                        style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('பிடிக்கப்பட்ட ஃபிரேம்கள் (Captured frames)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...result.debugFrames.map((frame) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('t = ${(frame.timeMs / 1000).toStringAsFixed(1)}s',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(frame.framePath), fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 8),
                      if (frame.rawTextBlocks.isEmpty)
                        const Text('(no text found on this frame)',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                      else
                        Text(
                          frame.rawTextBlocks.map((t) => '• $t').join('\n'),
                          style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                        ),
                    ],
                  ),
                ),
              )),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('மீண்டும் பதிவு செய்'), // record again
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: result.candidates.isEmpty
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                store: store,
                                candidates: result.candidates,
                              ),
                            ),
                          ),
                  child: const Text(TS.reviewTitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
