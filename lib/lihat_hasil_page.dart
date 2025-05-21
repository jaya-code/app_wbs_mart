import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LihatHasilPage extends StatefulWidget {
  const LihatHasilPage({Key? key}) : super(key: key);

  @override
  _LihatHasilPageState createState() => _LihatHasilPageState();
}

class _LihatHasilPageState extends State<LihatHasilPage> {
  List<dynamic> hasil = [];
  List<dynamic> filteredHasil = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  // Method to show edit dialog for editing stok_real
  void showEditDialog(dynamic id, dynamic stokReal) {
    final TextEditingController _stokController =
        TextEditingController(text: stokReal?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Stok Real'),
        content: TextField(
          controller: _stokController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Stok Real',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Implement your update logic here, e.g., send to API
              // For now, just update locally for demonstration
              setState(() {
                final index = hasil.indexWhere((item) => item['id'] == id);
                if (index != -1) {
                  hasil[index]['stok_real'] = int.tryParse(_stokController.text) ?? stokReal;
                  _filterResults();
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiLink = await getApiLink();
      final url = Uri.parse('$apiLink/api/stok-opname');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          hasil = List<dynamic>.from(data);
        } else {
          hasil = [];
        }
      } else {
        hasil = [];
      }
    } catch (e) {
      hasil = [];
    }
    _filterResults();
    setState(() {
      _isLoading = false;
    });
  }

  void _filterResults() {
    if (_searchQuery.isEmpty) {
      filteredHasil = List<dynamic>.from(hasil);
    } else {
      filteredHasil = hasil.where((item) {
        final productName = (item['product_name'] ?? '').toString().toLowerCase();
        final productId = (item['product_id'] ?? '').toString().toLowerCase();
        return productName.contains(_searchQuery.toLowerCase()) ||
            productId.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchData();
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _filterResults();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Method to confirm and handle deletion of an item
  void confirmHapus(dynamic id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus item ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                hasil.removeWhere((item) => item['id'] == id);
                _filterResults();
              });
              Navigator.pop(context);
            },
            child: const Text('Hapus'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Stok Opname'),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 41, 41, 41),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Cari produk',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredHasil.isEmpty
                    ? const Center(child: Text('Tidak ada data'))
                    : ListView.builder(
                        itemCount: filteredHasil.length,
                        itemBuilder: (context, index) {
                          final item = filteredHasil[index];
                          final id = item['id'];
                          final stok_real = item['stok_real'];
                          final product_name = item['product_name'];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text("${item['product_id']}"),
                              subtitle: Text("$product_name\nStok Real: $stok_real"),
                              isThreeLine: true,
                              contentPadding: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              tileColor: const Color.fromARGB(255, 237, 196, 62),
                              textColor: Colors.black,
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Detail'),
                                    content: Text(
                                      'Product ID: ${item['product_id']}\n'
                                      'Product Name: $product_name\n'
                                      'Stok Real: $stok_real',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Tutup'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => showEditDialog(id, stok_real),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => confirmHapus(id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
