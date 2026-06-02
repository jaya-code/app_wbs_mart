import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coba1/services/api_client.dart';

class SearchProductStockOpname extends StatefulWidget {
  const SearchProductStockOpname({super.key});

  @override
  State<SearchProductStockOpname> createState() => _SearchProductStockOpnameState();
}

class _SearchProductStockOpnameState extends State<SearchProductStockOpname> {
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoadingSession = true;
  int? _activeSessionId;
  String? _sessionError;

  bool _isLoadingProducts = false;
  List<dynamic> _products = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _checkActiveSession();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.1.150:8000';
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

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _products = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isLoadingProducts = true;
      _searchError = null;
    });

    try {
      final response = await ApiClient.get('/api/products/search?q=$query').timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _products = List<dynamic>.from(data['data']);
            _isLoadingProducts = false;
          });
          return;
        }
      }

      setState(() {
        _products = [];
        _searchError = 'Gagal memuat produk dari server.';
        _isLoadingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _products = [];
        _searchError = 'Terjadi kesalahan: $e';
        _isLoadingProducts = false;
      });
    }
  }

  void _showInputStockDialog(dynamic product) {
    final String productId = (product['product_id'] ?? '').toString();
    final String productName = (product['product_name'] ?? '').toString();
    final String? barcode = product['barcode']?.toString();
    final int systemStock = int.tryParse(product['stock'].toString()) ?? 0;

    final TextEditingController stockRealController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5F5AF6).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF5F5AF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Input Stok Real',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        barcode != null && barcode.isNotEmpty
                            ? 'ID: $productId • Barcode: $barcode'
                            : 'ID: $productId',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Stok Sistem: $systemStock',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Jumlah Stok Fisik (Real)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: stockRealController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Masukkan jumlah stok fisik',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF5F5AF6), width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final inputStock = double.tryParse(stockRealController.text.trim());
                if (inputStock == null || inputStock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Silakan masukkan jumlah stok yang valid! ❌'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext); // Close dialog

                _saveStockOpnameDetail(productId, inputStock);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5F5AF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveStockOpnameDetail(String prodId, double stokReal) async {
    if (_activeSessionId == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Menyimpan data ke server... 📤'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final response = await ApiClient.post(
        '/api/stok-opname/$_activeSessionId/scan',
        body: {
          'product_id': prodId,
          'stok_real': stokReal,
          'user_id': 1,
          'tanggal': DateTime.now().toIso8601String().split('T').first,
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data stok opname berhasil disimpan! ✅'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _searchProducts(_searchController.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan data ke server! ❌'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e ❌'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Produk'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _checkActiveSession,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingSession
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
                              'Sesi Aktif ID: $_activeSessionId (Dapat Menginput)',
                              style: const TextStyle(
                                color: Color(0xFF047857),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => _searchProducts(val),
                          decoration: InputDecoration(
                            hintText: 'Ketik nama produk atau barcode...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _searchController.clear();
                                      _searchProducts('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF5F5AF6),
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: _isLoadingProducts
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5F5AF6)),
                                ),
                              )
                            : _searchError != null
                                ? Center(
                                    child: Text(
                                      _searchError!,
                                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                    ),
                                  )
                                : _products.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _searchController.text.isEmpty
                                                  ? Icons.search_rounded
                                                  : Icons.hourglass_empty_rounded,
                                              size: 64,
                                              color: const Color(0xFFCBD5E1),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchController.text.isEmpty
                                                  ? 'Mulai ketik untuk mencari produk'
                                                  : 'Produk tidak ditemukan',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                                        itemCount: _products.length,
                                        itemBuilder: (context, index) {
                                          final product = _products[index];
                                          final name = product['product_name'] ?? '-';
                                          final barcode = product['barcode'] ?? '-';
                                          final id = product['product_id'] ?? '-';
                                          final sysStock = product['stock'] ?? 0;

                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: const Color(0xFFF1F5F9),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF0F172A).withAlpha(5),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 10,
                                              ),
                                              title: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 6.0),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'ID: $id  •  Barcode: $barcode',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF64748B),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Stok Sistem: $sysStock',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Color(0xFF047857),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              trailing: const Icon(
                                                Icons.add_circle_outline_rounded,
                                                color: Color(0xFF5F5AF6),
                                                size: 28,
                                              ),
                                              onTap: () => _showInputStockDialog(product),
                                            ),
                                          );
                                        },
                                      ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
