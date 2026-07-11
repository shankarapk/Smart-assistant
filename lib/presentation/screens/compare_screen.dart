import 'package:flutter/material.dart';

import '../../core/constants/tamil_strings.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/price_entry.dart';
import '../../data/models/store.dart';

class CompareScreen extends StatefulWidget {
  final String productNameEnglish;

  const CompareScreen({super.key, required this.productNameEnglish});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  List<PriceEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await DbHelper.instance.comparePrices(widget.productNameEnglish);
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final cheapest = _entries.isNotEmpty ? _entries.first : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.productNameEnglish)),
      body: _entries.isEmpty
          ? const Center(child: Text(TS.noDataYet))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (cheapest != null)
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(TS.cheapestAt, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 6),
                          Text(
                            '${cheapest.store.label} — ₹${cheapest.effectivePrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Text(TS.compareTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._entries.map((e) => Card(
                      child: ListTile(
                        title: Text(e.store.label, style: const TextStyle(fontSize: 20)),
                        subtitle: Text(
                          e.quantity,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: Text(
                          '₹${e.effectivePrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: e == cheapest ? FontWeight.bold : FontWeight.normal,
                            color: e == cheapest
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                    )),
              ],
            ),
    );
  }
}
