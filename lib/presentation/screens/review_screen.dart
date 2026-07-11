import 'package:flutter/material.dart';

import '../../core/constants/tamil_strings.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/price_entry.dart';
import '../../data/models/store.dart';
import 'home_screen.dart';

class ReviewScreen extends StatefulWidget {
  final Store store;
  final List<ExtractedCandidate> candidates;

  const ReviewScreen({super.key, required this.store, required this.candidates});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<ExtractedCandidate> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.candidates;
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item.guessedName);
    final qtyCtrl = TextEditingController(text: item.guessedQuantity);
    final priceCtrl = TextEditingController(text: item.guessedPrice?.toString() ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(TS.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: TS.productName),
            ),
            TextField(
              controller: qtyCtrl,
              decoration: const InputDecoration(labelText: TS.quantity),
            ),
            TextField(
              controller: priceCtrl,
              decoration: const InputDecoration(labelText: TS.price),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(TS.confirm),
          ),
        ],
      ),
    );

    if (saved == true) {
      setState(() {
        item.guessedName = nameCtrl.text.trim();
        item.guessedQuantity = qtyCtrl.text.trim();
        item.guessedPrice = double.tryParse(priceCtrl.text.trim());
      });
    }
  }

  Future<void> _saveAll() async {
    final db = DbHelper.instance;
    for (final item in _items) {
      if (!item.accepted || item.guessedPrice == null) continue;
      await db.insertEntry(PriceEntry(
        productNameTamil: item.guessedName,
        productNameEnglish: item.guessedName, // user can retype in English if needed
        quantity: item.guessedQuantity,
        store: widget.store,
        price: item.guessedPrice!,
        capturedAt: DateTime.now(),
        verified: true,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${TS.reviewTitle} — ${widget.store.label}')),
      body: _items.isEmpty
          ? const Center(child: Text('எந்த விலையும் கண்டறியப்படவில்லை'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  child: ListTile(
                    title: Text(item.guessedName, style: const TextStyle(fontSize: 20)),
                    subtitle: Text(
                      '${item.guessedQuantity}  •  ₹${item.guessedPrice?.toStringAsFixed(2) ?? "-"}',
                      style: const TextStyle(fontSize: 17),
                    ),
                    leading: Checkbox(
                      value: item.accepted,
                      onChanged: (v) => setState(() => item.accepted = v ?? true),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editItem(index),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _items.isEmpty ? null : _saveAll,
            child: const Text(TS.saveAll),
          ),
        ),
      ),
    );
  }
}
