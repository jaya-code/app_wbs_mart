import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  String? kode;
  String? nama;
  int? stok;
  bool scanned = false;

  final TextEditingController jumlahController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();

  Future<void> getBarang(String kodeBarang) async {
    final prefs = await SharedPreferences.getInstance();
    final apiLink = prefs.getString('api_link') ?? 'https://default-link.com';
    final url = Uri.parse('$apiLink/api/barang/$kodeBarang');
    final response = await http.get(url);

    if (!mounted) return;

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        kode = data['kode'];
        nama = data['nama'];
        stok = data['stok'];
        scanned = true;
      });
    } else {
      setState(() {
        kode = null;
        nama = 'Barang tidak ditemukan';
        stok = null;
        scanned = true;
      });
    }
  }

  Future<void> simpanOpname() async {
    final prefs = await SharedPreferences.getInstance();
    final apiLink = prefs.getString('api_link') ?? 'https://default-link.com';
    final url = Uri.parse('$apiLink/api/stok-opname');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'kode_barang': kode,
        'jumlah': int.tryParse(jumlahController.text) ?? 0,
      }),
    );

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
        title: const Text('Scan Stok Opname'),
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
                    Text('Kode: $kode'),
                    Text('Nama: $nama'),
                    Text('Stok: $stok'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah stok real',
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
                              kode = null;
                              nama = null;
                              stok = null;
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
                                    'Jumlah stok tidak boleh kosong',
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
