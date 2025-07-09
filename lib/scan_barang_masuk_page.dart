import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanBarangMasukPage extends StatefulWidget {
  const ScanBarangMasukPage({super.key});

  @override
  State<ScanBarangMasukPage> createState() => _ScanBarangMasukPageState();
}

class _ScanBarangMasukPageState extends State<ScanBarangMasukPage> {
  String? productId;
  String? productName;
  int? stock;
  bool scanned = false;

  final TextEditingController jumlahController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();

  Future<void> getBarang(String productKode) async {
    final prefs = await SharedPreferences.getInstance();
    final apiLink = prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
    final url = Uri.parse('$apiLink/api/product/$productKode');
    final response = await http.get(url);

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        productId = data['product_id'].toString();
        productName = data['product_name'];
        stock = data['stock'];
        scanned = true;
      });
    } else {
      setState(() {
        productId = '';
        productName = 'Barang tidak ditemukan';
        stock = null;
        scanned = true;
      });
    }
  }

  Future<void> simpanOpname() async {
    final prefs = await SharedPreferences.getInstance();
    final apiLink = prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
    final url = Uri.parse('$apiLink/api/stok-opname');

    final stokReal = double.tryParse(jumlahController.text.trim()) ?? 0;

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'product_id': productId,
        'stok_real': stokReal,
        'tanggal':
            DateTime.now()
                .toIso8601String()
                .split('T')
                .first, // Format: YYYY-MM-DD
      }),
    );

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');

    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data berhasil disimpan')));
      setState(() {
        scanned = false;
        jumlahController.clear();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal menyimpan data')));
    }
  }

  @override
  void dispose() {
    jumlahController.dispose();
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barang Masuk'),
        backgroundColor: Color.fromARGB(255, 41, 41, 41),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  final String? code = barcode.rawValue;
                  if (code != null && !scanned) {
                    getBarang(code);
                    break;
                  }
                }
              },
            ),
          ),
          if (scanned)
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('product id: $productId'),
                    Text('product name: $productName'),
                    Text('Stock: $stock'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah stock real',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              scanned = false;
                              productId = null;
                              productName = null;
                              stock = null;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: Colors.red,
                            foregroundColor:
                                Colors.white, // text color set to white
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // ensure text color is white
                            ),
                          ),
                          child: const Text('Scan Ulang'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            if (jumlahController.text.trim().isNotEmpty) {
                              simpanOpname();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Jumlah stock tidak boleh kosong',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            backgroundColor: Colors.green, // warna hijau
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: const Text('Simpan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
