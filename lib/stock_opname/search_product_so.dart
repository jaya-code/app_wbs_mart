import 'package:flutter/material.dart';

class SearchProductStockOpname extends StatelessWidget {
  const SearchProductStockOpname({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cari Produk'),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.all(8.0), child: TextField()),
        ],
      ),
    );
  }
}
