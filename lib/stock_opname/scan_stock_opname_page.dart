import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:coba1/services/api_client.dart';

class ScanStockOpnamePage extends StatefulWidget {
  const ScanStockOpnamePage({super.key});

  @override
  State<ScanStockOpnamePage> createState() => _ScanStockOpnamePageState();
}

class _ScanStockOpnamePageState extends State<ScanStockOpnamePage> {
  String? productId;
  String? productName;
  String? barcode;
  int? stock;
  bool scanned = false;

  bool _isLoadingSession = true;
  int? _activeSessionId;
  String? _sessionError;

  final TextEditingController jumlahController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  Future<void> _checkActiveSession() async {
    setState(() {
      _isLoadingSession = true;
      _sessionError = null;
    });

    try {
      final response = await ApiClient.get('/api/stok-opname/active').timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _activeSessionId = int.tryParse(data['data']['id'].toString());
            _isLoadingSession = false;
          });
          return;
        }
      }

      setState(() {
        _activeSessionId = null;
        _sessionError = 'Tidak ada sesi stock opname yang aktif di server.';
        _isLoadingSession = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activeSessionId = null;
        _sessionError = 'Gagal terhubung ke server: $e';
        _isLoadingSession = false;
      });
    }
  }

  Future<void> getBarang(String productKode) async {
    final response = await ApiClient.get('/api/product/$productKode');

    if (!mounted) return;

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true && responseData['data'] != null) {
        final data = responseData['data'];
        setState(() {
          productId = data['product_id'].toString();
          barcode = data['barcode'];
          productName = data['product_name'];
          stock = int.tryParse(data['stock'].toString());
          scanned = true;
        });
        return;
      }
    }
    
    setState(() {
      productId = '';
      barcode = productKode;
      productName = 'Barang tidak ditemukan';
      stock = null;
      scanned = true;
    });
  }

  Future<void> simpanOpname() async {
    if (_activeSessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada sesi stock opname yang aktif!')),
      );
      return;
    }

    final stokReal = double.tryParse(jumlahController.text.trim()) ?? 0;

    final response = await ApiClient.post(
      '/api/stok-opname/$_activeSessionId/scan',
      body: {
        'product_id': productId,
        'stok_real': stokReal,
        'user_id': 1,
        'tanggal': DateTime.now().toIso8601String().split('T').first,
      },
    );

    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('Response Body: ${response.body}');

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
        title: const Text('Scan Stock Opname'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkActiveSession,
          )
        ],
      ),
      body: _isLoadingSession
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5F5AF6)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memeriksa sesi aktif...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : _sessionError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFEF4444),
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Sesi Tidak Aktif',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sessionError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _checkActiveSession,
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Periksa Ulang Sesi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5F5AF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFF10B981).withAlpha(20),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Sesi Aktif ID: $_activeSessionId (Sedang Berjalan)',
                            style: const TextStyle(
                              color: Color(0xFF047857),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                              Text('barcode: $barcode'),
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
                                      foregroundColor: Colors.white,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
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
                                      backgroundColor: Colors.green,
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
