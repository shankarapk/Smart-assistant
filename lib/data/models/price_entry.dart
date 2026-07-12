import 'store.dart';

/// One product price observed from a screen recording of a specific store's app.
/// This is manually confirmed by the user after OCR extraction before it is saved,
/// so `verified` should always be true by the time it reaches the database.
class PriceEntry {
  final int? id;
  final String productNameTamil;
  final String productNameEnglish;
  final String quantity; // e.g. "1 kg", "500 ml"
  final Store store;
  final double price;
  final double? discount;
  final DateTime capturedAt;
  final bool verified;

  PriceEntry({
    this.id,
    required this.productNameTamil,
    required this.productNameEnglish,
    required this.quantity,
    required this.store,
    required this.price,
    this.discount,
    required this.capturedAt,
    this.verified = false,
  });

  double get effectivePrice => price - (discount ?? 0);

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_name_ta': productNameTamil,
        'product_name_en': productNameEnglish,
        'quantity': quantity,
        'store': store.key,
        'price': price,
        'discount': discount,
        'captured_at': capturedAt.toIso8601String(),
        'verified': verified ? 1 : 0,
      };

  factory PriceEntry.fromMap(Map<String, dynamic> map) => PriceEntry(
        id: map['id'] as int?,
        productNameTamil: map['product_name_ta'] as String,
        productNameEnglish: map['product_name_en'] as String,
        quantity: map['quantity'] as String,
        store: StoreX.fromKey(map['store'] as String),
        price: (map['price'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble(),
        capturedAt: DateTime.parse(map['captured_at'] as String),
        verified: (map['verified'] as int) == 1,
      );

  PriceEntry copyWith({
    String? productNameTamil,
    String? productNameEnglish,
    String? quantity,
    double? price,
    double? discount,
    bool? verified,
  }) =>
      PriceEntry(
        id: id,
        productNameTamil: productNameTamil ?? this.productNameTamil,
        productNameEnglish: productNameEnglish ?? this.productNameEnglish,
        quantity: quantity ?? this.quantity,
        store: store,
        price: price ?? this.price,
        discount: discount ?? this.discount,
        capturedAt: capturedAt,
        verified: verified ?? this.verified,
      );
}

/// A raw, unconfirmed line pulled off an OCR'd video frame.
/// Lives only in memory during the review screen, never written to the DB
/// until the user confirms/edits it into a PriceEntry.
class ExtractedCandidate {
  String rawText;
  String guessedName;
  String guessedQuantity;
  double? guessedPrice;
  bool accepted;
  bool lowConfidence;

  ExtractedCandidate({
    required this.rawText,
    required this.guessedName,
    required this.guessedQuantity,
    this.guessedPrice,
    this.accepted = true,
    this.lowConfidence = false,
  });
}
