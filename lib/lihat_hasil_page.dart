import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LihatHasilPage extends StatefulWidget {
  const LihatHasilPage({super.key});

  @override
  State<LihatHasilPage> createState() => _LihatHasilPageState();
}

class _LihatHasilPageState extends State<LihatHasilPage> {
  List<dynamic> hasil = [];

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  Future<void> fetchData() async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink/api/stok-opname');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        hasil = json.decode(response.body);
      });
    }
  }

  Future<void> hapusData(int id) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink/api/stok-opname/$id');

    final response = await http.delete(url);

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data berhasil dihapus')));
      fetchData();
    }
  }

  Future<void> updateData(int id, int stok_real) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink/api/stok-opname/$id');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'stok_real': stok_real}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data berhasil diupdate')));
      fetchData();
    }
  }

  void showEditDialog(int id, int jumlahAwal) {
    final controller = TextEditingController(text: jumlahAwal.toString());

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Edit Jumlah'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah Real'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  final jumlahBaru = int.tryParse(controller.text);
                  if (jumlahBaru != null) {
                    updateData(id, jumlahBaru);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
  }

  void confirmHapus(int id) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text('Yakin ingin menghapus data ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  hapusData(id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Stok Opname'),
        foregroundColor: Colors.white,
        backgroundColor: const Color.fromARGB(255, 41, 41, 41),
      ),
      body:
          hasil.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: hasil.length,
                itemBuilder: (context, index) {
                  final item = hasil[index];
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
                          builder:
                              (_) => AlertDialog(
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
    );
  }
}
