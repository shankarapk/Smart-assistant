import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../models/price_entry.dart';

/// Pulls still frames out of a locally recorded video and runs on-device
/// OCR (Google ML Kit — nothing leaves the phone) to guess product name,
/// quantity, and price. Results are *candidates only*; nothing here writes
/// to the database. The user always reviews/edits/confirms on the Review
/// screen before anything is saved.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Matches "₹42", "Rs 42", "Rs. 42.50", "42.00" near a rupee symbol.
  static final _priceRegex = RegExp(r'(?:₹|Rs\.?\s?)\s?(\d+(?:\.\d{1,2})?)');
  // Matches common Indian grocery quantity units.
  static final _qtyRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s?(kg|g|ml|l|litre|liter|pcs|pack|dozen)',
    caseSensitive: false,
  );

  /// Samples one frame every [intervalMs] milliseconds across the video
  /// duration and OCRs each one. Returns raw candidates for user review.
  Future<List<ExtractedCandidate>> extractFromVideo(
    String videoPath, {
    int intervalMs = 1500,
    int maxFrames = 40,
  }) async {
    final candidates = <ExtractedCandidate>[];
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < maxFrames; i++) {
      final timeMs = i * intervalMs;
      final framePath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 85,
      );
      if (framePath == null) break; // past end of video

      final input = InputImage.fromFilePath(framePath);
      final result = await _recognizer.processImage(input);
      candidates.addAll(_parseBlocks(result));

      // Clean up the temp frame immediately; we only need the extracted text.
      final f = File(framePath);
      if (await f.exists()) await f.delete();
    }

    // Delete the source recording once every frame has been processed —
    // we never keep raw screen-recording video around longer than needed.
    final source = File(videoPath);
    if (await source.exists()) await source.delete();

    return _dedupe(candidates);
  }

  List<ExtractedCandidate> _parseBlocks(RecognizedText result) {
    final out = <ExtractedCandidate>[];
    for (final block in result.blocks) {
      final text = block.text.replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;

      final priceMatch = _priceRegex.firstMatch(text);
      final qtyMatch = _qtyRegex.firstMatch(text);
      if (priceMatch == null) continue; // no price -> not useful as a candidate

      final price = double.tryParse(priceMatch.group(1) ?? '');
      if (price == null) continue;

      // Best-effort product name: strip out the matched price/qty substrings.
      var name = text
          .replaceAll(priceMatch.group(0) ?? '', '')
          .replaceAll(qtyMatch?.group(0) ?? '', '')
          .trim();
      if (name.length > 60) name = name.substring(0, 60);

      out.add(ExtractedCandidate(
        rawText: text,
        guessedName: name.isEmpty ? 'தெரியவில்லை' : name,
        guessedQuantity: qtyMatch?.group(0) ?? '',
        guessedPrice: price,
      ));
    }
    return out;
  }

  /// Collapses near-duplicate candidates that show up across consecutive
  /// frames (since the user is scrolling slowly, the same product often
  /// gets OCR'd 3-4 times in a row).
  List<ExtractedCandidate> _dedupe(List<ExtractedCandidate> input) {
    final seen = <String, ExtractedCandidate>{};
    for (final c in input) {
      final key = '${c.guessedName.toLowerCase()}_${c.guessedPrice}';
      seen[key] = c;
    }
    return seen.values.toList();
  }

  void dispose() => _recognizer.close();
}
