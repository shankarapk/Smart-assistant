import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';

import '../models/price_entry.dart';

/// One sampled frame plus everything OCR found on it, price-shaped or not.
/// Used purely for troubleshooting when extraction finds nothing useful.
class DebugFrame {
  final String framePath;
  final int timeMs;
  final List<String> rawTextBlocks;

  DebugFrame({required this.framePath, required this.timeMs, required this.rawTextBlocks});
}

class OcrExtractionResult {
  final List<ExtractedCandidate> candidates;
  final List<DebugFrame> debugFrames;
  final int frameCount;

  OcrExtractionResult({
    required this.candidates,
    required this.debugFrames,
    required this.frameCount,
  });
}

/// Pulls still frames out of a locally recorded video and runs on-device
/// OCR (Google ML Kit — nothing leaves the phone) to guess product name,
/// quantity, and price. Results are *candidates only*; nothing here writes
/// to the database. The user always reviews/edits/confirms on the Review
/// screen before anything is saved.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Matches "₹42", "Rs 42", "Rs. 42.50", "42.00" near a rupee symbol.
  static final _priceRegex = RegExp(r'(?:₹|Rs\.?\s?)\s?(\d+(?:\.\d{1,2})?)');

  // Google ML Kit's Latin recognizer frequently misreads the ₹ glyph as a
  // plain letter — most often R or Z — glued directly to the number with
  // no space (e.g. "R64900", "Z899"). This fallback only fires when the
  // primary pattern above finds nothing, and matches are flagged
  // lowConfidence so the Review screen can call them out for extra
  // scrutiny. Deliberately excludes digits like '3' as trigger characters —
  // that misfires on ordinary numbers that happen to start with 3 (e.g.
  // "300" would get chopped into a fake "00").
  static final _priceMisreadRegex =
      RegExp(r'(?<![A-Za-z0-9])[RZ](\d{2,6})(?:\.(\d{1,2}))?(?![A-Za-z0-9])');

  // Matches common Indian grocery quantity units.
  static final _qtyRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s?(kg|g|ml|l|litre|liter|pcs|pack|dozen)',
    caseSensitive: false,
  );

  /// Samples one frame every [intervalMs] milliseconds across the video
  /// duration and OCRs each one.
  ///
  /// When [debug] is true, sampled frame images and *every* recognized text
  /// block (not just ones that matched the price pattern) are kept and
  /// returned so you can see exactly what the recording captured and why
  /// nothing may have been picked up as a price. When false (normal use
  /// once things are working), frames and the source video are deleted as
  /// soon as they've been processed.
  Future<OcrExtractionResult> extractFromVideo(
    String videoPath, {
    bool debug = false,
    int intervalMs = 1500,
    int maxFrames = 40,
  }) async {
    final candidates = <ExtractedCandidate>[];
    final debugFrames = <DebugFrame>[];
    int framesProcessed = 0;

    final outDir = debug
        ? await _debugFrameDir()
        : await getTemporaryDirectory();

    for (int i = 0; i < maxFrames; i++) {
      final timeMs = i * intervalMs;
      final framePath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outDir.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 85,
      );
      if (framePath == null) break; // past end of video

      framesProcessed++;
      final input = InputImage.fromFilePath(framePath);
      final result = await _recognizer.processImage(input);
      candidates.addAll(_parseBlocks(result));

      if (debug) {
        debugFrames.add(DebugFrame(
          framePath: framePath,
          timeMs: timeMs,
          rawTextBlocks: result.blocks.map((b) => b.text.replaceAll('\n', ' ')).toList(),
        ));
        // frame kept on disk for inspection in debug mode
      } else {
        final f = File(framePath);
        if (await f.exists()) await f.delete();
      }
    }

    // In normal (non-debug) mode we never keep the raw recording around
    // longer than it takes to process it. In debug mode we keep it too,
    // so you can re-run extraction against it or inspect it directly.
    if (!debug) {
      final source = File(videoPath);
      if (await source.exists()) await source.delete();
    }

    return OcrExtractionResult(
      candidates: _dedupe(candidates),
      debugFrames: debugFrames,
      frameCount: framesProcessed,
    );
  }

  Future<Directory> _debugFrameDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/debug_frames/${DateTime.now().millisecondsSinceEpoch}');
    await dir.create(recursive: true);
    return dir;
  }

  /// Deletes all previously saved debug frame directories. Call this once
  /// you're done troubleshooting so debug images don't pile up on disk.
  Future<void> clearDebugData() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/debug_frames');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  // Leftover "name" text that's clearly not a real product name — UI badge
  // labels, buttons, and pure numbers that sometimes end up alone in a
  // block after the price/qty substrings are stripped out.
  static final _junkNames = {
    'off', 'add', 'new', 'sale', 'save', 'mrp', 'see all', 'buy', 'best',
    'deal', 'deals', 'flat', 'extra', 'combo', 'free', 'offer', 'offers',
  };

  bool _looksLikeJunk(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return true;
    if (_junkNames.contains(n)) return true;
    if (RegExp(r'^[\d\.\-\s%]+$').hasMatch(n)) return true; // digits/symbols only
    if (n.length < 3) return true;
    return false;
  }

  List<ExtractedCandidate> _parseBlocks(RecognizedText result) {
    final out = <ExtractedCandidate>[];
    for (final block in result.blocks) {
      final text = block.text.replaceAll('\n', ' ').trim();
      if (text.isEmpty) continue;

      final qtyMatch = _qtyRegex.firstMatch(text);

      double? price;
      String matchedSpan = '';
      bool lowConfidence = false;

      final strictMatch = _priceRegex.firstMatch(text);
      if (strictMatch != null) {
        price = double.tryParse(strictMatch.group(1) ?? '');
        matchedSpan = strictMatch.group(0) ?? '';
      } else {
        // Primary pattern found nothing — try the misread-₹ fallback.
        final fallbackMatch = _priceMisreadRegex.firstMatch(text);
        if (fallbackMatch != null) {
          final whole = fallbackMatch.group(1) ?? '';
          final frac = fallbackMatch.group(2);
          price = double.tryParse(frac != null ? '$whole.$frac' : whole);
          matchedSpan = fallbackMatch.group(0) ?? '';
          lowConfidence = true;
        }
      }

      if (price == null) continue; // nothing price-shaped in this block

      // Best-effort product name: strip out the matched price/qty substrings.
      var name = text
          .replaceAll(matchedSpan, '')
          .replaceAll(qtyMatch?.group(0) ?? '', '')
          .trim();
      if (name.length > 60) name = name.substring(0, 60);

      // Skip candidates whose "name" is obviously just badge/button text or
      // leftover digits rather than an actual product name — saving these
      // does more harm than good since there's no real name to correct.
      if (_looksLikeJunk(name)) continue;

      out.add(ExtractedCandidate(
        rawText: text,
        guessedName: name,
        guessedQuantity: qtyMatch?.group(0) ?? '',
        guessedPrice: price,
        lowConfidence: lowConfidence,
        // Low-confidence (misread-symbol) matches start unchecked so they
        // require a deliberate opt-in during review, rather than being
        // bulk-saved by default alongside high-confidence matches.
        accepted: !lowConfidence,
      ));
    }
    return out;
  }

  /// Collapses near-duplicate candidates that show up across consecutive
  /// frames (since the user is scrolling slowly, the same product often
  /// gets OCR'd 3-4 times in a row). When the same product+price appears
  /// more than once, a clean strict-match read is always kept over a
  /// misread-fallback read of the same thing — otherwise a later, worse
  /// frame could silently downgrade an already-good match to lowConfidence.
  List<ExtractedCandidate> _dedupe(List<ExtractedCandidate> input) {
    final seen = <String, ExtractedCandidate>{};
    for (final c in input) {
      final key = '${c.guessedName.toLowerCase()}_${c.guessedPrice}';
      final existing = seen[key];
      if (existing == null || (existing.lowConfidence && !c.lowConfidence)) {
        seen[key] = c;
      }
    }
    return seen.values.toList();
  }

  void dispose() => _recognizer.close();
}
