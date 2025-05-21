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
    return prefs.getString('api_link') ?? 'https://default-link.com';
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

  Future<void> updateData(int id, int jumlah) async {
    final apiLink = await getApiLink();
    final url = Uri.parse('$apiLink/api/stok-opname/$id');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'jumlah': jumlah}),
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
      appBar: AppBar(title: const Text('Hasil Stok Opname')),
      body:
          hasil.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                itemCount: hasil.length,
                itemBuilder: (context, index) {
                  final item = hasil[index];
                  final id = item['id'];
                  final jumlah = item['jumlah'];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      title: Text("Kode: ${item['kode_barang']}"),
                      subtitle: Text("Jumlah Real: $jumlah"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => showEditDialog(id, jumlah),
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
