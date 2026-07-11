import 'package:flutter/material.dart';

import '../../core/constants/tamil_strings.dart';
import '../../data/database/db_helper.dart';
import 'compare_screen.dart';
import 'record_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  List<String> _productNames = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final names = await DbHelper.instance.distinctProductNames();
    setState(() => _productNames = names);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _searchController.text.isEmpty
        ? _productNames
        : _productNames
            .where((n) =>
                n.toLowerCase().contains(_searchController.text.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(title: const Text(TS.appName)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.videocam),
        label: const Text(TS.recordStore),
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecordScreen()),
          );
          _loadProducts();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: TS.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            if (_productNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  TS.noDataYet,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            else ...[
              Text(TS.frequentlyBought, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...filtered.map((name) => Card(
                    child: ListTile(
                      title: Text(name, style: const TextStyle(fontSize: 20)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CompareScreen(productNameEnglish: name),
                        ),
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
