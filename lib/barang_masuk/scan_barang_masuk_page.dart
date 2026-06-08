import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coba1/services/api_client.dart';

class ScanBarangMasukPage extends StatefulWidget {
  const ScanBarangMasukPage({super.key});

  @override
  State<ScanBarangMasukPage> createState() => _ScanBarangMasukPageState();
}

class _ScanBarangMasukPageState extends State<ScanBarangMasukPage> with SingleTickerProviderStateMixin {
  // Navigation & Step Control
  bool _isSessionStarted = false;
  String? _nofaktur;
  dynamic _selectedSupplier;
  String? _selectedSupplierStatusPpn; // 'include' or 'exclude'

  // Suppliers List
  bool _isLoadingSuppliers = true;
  List<dynamic> _suppliers = [];
  String? _supplierError;

  // Form Controllers
  final TextEditingController _nofakController = TextEditingController();
  final TextEditingController _searchProductController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  // Tab controller for Scan vs Search vs Cart
  TabController? _tabController;

  // Selected Product State
  bool _isLoadingProduct = false;
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  String? _searchError;

  // Cart State
  List<dynamic> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchSuppliers();
  }

  @override
  void dispose() {
    _nofakController.dispose();
    _searchProductController.dispose();
    _scannerController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  Future<void> _fetchSuppliers() async {
    setState(() {
      _isLoadingSuppliers = true;
      _supplierError = null;
    });

    try {
      final response = await ApiClient.get('/api/suppliers').timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _suppliers = List<dynamic>.from(data['data']);
            _isLoadingSuppliers = false;
          });
          return;
        }
      }

      setState(() {
        _supplierError = 'Gagal memuat daftar supplier.';
        _isLoadingSuppliers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _supplierError = 'Gagal terhubung ke server: $e';
        _isLoadingSuppliers = false;
      });
    }
  }

  void _startPembelianSession() {
    if (_selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih Supplier terlebih dahulu! ❌')),
      );
      return;
    }

    setState(() {
      _isSessionStarted = true;
      _nofaktur = _nofakController.text.trim().isNotEmpty
          ? _nofakController.text.trim()
          : 'MOB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _selectedSupplierStatusPpn = _selectedSupplier['status_ppn'];
      _cartItems = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sesi Input Lokal $_nofaktur dimulai! ✅')),
    );
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isLoadingSearch = true;
      _searchError = null;
    });

    try {
      final response = await ApiClient.get('/api/products/search?q=$query').timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _searchResults = List<dynamic>.from(data['data']);
            _isLoadingSearch = false;
          });
          return;
        }
      }

      setState(() {
        _searchResults = [];
        _searchError = 'Gagal memuat produk.';
        _isLoadingSearch = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _searchError = 'Error: $e';
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _getBarangFromScan(String barcode) async {
    setState(() {
      _isLoadingProduct = true;
    });

    try {
      final response = await ApiClient.get('/api/products/barcode/$barcode');

      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _showInputItemDialog(data['data']);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk "$barcode" tidak ditemukan ❌'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e ❌')),
      );
    }
  }

  void _showInputItemDialog(dynamic product) {
    final String productId = (product['product_id'] ?? '').toString();
    final String productName = (product['product_name'] ?? '').toString();
    final String? barcodeStr = product['barcode']?.toString();
    final int systemStock = int.tryParse(product['stock'].toString()) ?? 0;
    
    // Cost Price PPN adjustment
    double rawCostPrice = double.tryParse(product['cost_price'].toString()) ?? 0.0;
    double calculatedCostPrice = rawCostPrice;

    if (_selectedSupplierStatusPpn == 'exclude') {
      calculatedCostPrice = rawCostPrice - (rawCostPrice * 0.11);
    }

    final TextEditingController qtyController = TextEditingController();
    final TextEditingController priceController = TextEditingController(
      text: calculatedCostPrice.toStringAsFixed(0),
    );

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
                  color: const Color(0xFF10B981).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_shopping_cart_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Tambah Item',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Box
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
                        barcodeStr != null && barcodeStr.isNotEmpty
                            ? 'ID: $productId • Barcode: $barcodeStr'
                            : 'ID: $productId',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Stok Sistem: $systemStock',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedSupplierStatusPpn == 'exclude'
                                  ? const Color(0xFFF59E0B).withAlpha(20)
                                  : const Color(0xFF10B981).withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _selectedSupplierStatusPpn == 'exclude' ? 'Exclude PPN (-11%)' : 'Include PPN',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _selectedSupplierStatusPpn == 'exclude'
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Qty Field
                const Text(
                  'Jumlah Barang Masuk (Qty)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Masukkan jumlah barang',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // Price Field
                const Text(
                  'Harga Beli Satuan (Rp)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Masukkan harga beli',
                    prefixText: 'Rp ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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
                final double? qty = double.tryParse(qtyController.text.trim());
                final double? price = double.tryParse(priceController.text.trim());

                if (qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Masukkan jumlah beli yang valid! ❌'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                if (price == null || price < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Masukkan harga beli yang valid! ❌'), backgroundColor: Color(0xFFEF4444)),
                  );
                  return;
                }

                Navigator.pop(dialogContext); // Close dialog
                _addItemToPembelian(product, qty, price);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _addItemToPembelian(dynamic product, double qty, double price) {
    final String productId = (product['product_id'] ?? '').toString();
    final String productName = (product['product_name'] ?? '').toString();
    final String? barcodeStr = product['barcode']?.toString();

    setState(() {
      final index = _cartItems.indexWhere((item) => item['product_id'].toString() == productId);
      if (index != -1) {
        _cartItems[index]['qty_beli'] = (_cartItems[index]['qty_beli'] ?? 0.0) + qty;
        _cartItems[index]['harga_beli'] = price;
        _cartItems[index]['sub_total'] = _cartItems[index]['qty_beli'] * price;
      } else {
        _cartItems.add({
          'product_id': productId,
          'product_name': productName,
          'barcode': barcodeStr,
          'qty_beli': qty,
          'harga_beli': price,
          'sub_total': qty * price,
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"$productName" ditambahkan ke keranjang! 🛒'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _finalizePembelian() async {
    if (_cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keranjang masih kosong! ❌'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menyimpan dan memproses ${_cartItems.length} barang masuk ke server?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
            child: const Text('Ya, Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoadingProduct = true;
    });

    try {
      final createRes = await ApiClient.post(
        '/api/pembelian',
        body: {
          'tgl_beli': DateTime.now().toIso8601String().split('T').first,
          'supplier_id': _selectedSupplier['supplier_id'],
          'user_id': 1,
          'nofak_beli': _nofakController.text.trim().isNotEmpty
              ? _nofakController.text.trim()
              : null,
        },
      );

      if (createRes.statusCode != 201) {
        throw Exception('Gagal membuat sesi pembelian di server (Status: ${createRes.statusCode})');
      }

      final createData = json.decode(createRes.body);
      if (createData['success'] != true || createData['data'] == null) {
        throw Exception('Respon server tidak valid saat membuat sesi');
      }

      final int pembelianId = int.parse(createData['data']['pembelian_id'].toString());
      final String generatedNofaktur = createData['data']['nofak_beli'];

      for (final item in _cartItems) {
        final addRes = await ApiClient.post(
          '/api/pembelian/$pembelianId/add-item',
          body: {
            'product_id': item['product_id'],
            'qty_beli': item['qty_beli'],
            'harga_beli': item['harga_beli'],
            'disc': 0,
          },
        );

        if (addRes.statusCode != 200) {
          throw Exception('Gagal menambahkan produk "${item['product_name']}" ke server');
        }
      }

      final finalizeRes = await ApiClient.post('/api/pembelian/$pembelianId/finalize');

      if (finalizeRes.statusCode != 200) {
        throw Exception('Gagal memproses finalisasi stok di server');
      }

      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
        _isSessionStarted = false;
        _nofaktur = null;
        _selectedSupplier = null;
        _selectedSupplierStatusPpn = null;
        _nofakController.clear();
        _searchResults = [];
        _searchProductController.clear();
        _cartItems = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi $generatedNofaktur berhasil disimpan ke server! ✅'),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProduct = false;
      });
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Error', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('Terjadi kesalahan saat menyimpan transaksi:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barang Masuk'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: _isSessionStarted
            ? [
                TextButton.icon(
                  onPressed: _finalizePembelian,
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: const Text('Selesai', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: _isLoadingSuppliers
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))),
                    SizedBox(height: 16),
                    Text('Memuat daftar supplier...', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            : _supplierError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 48),
                          const SizedBox(height: 16),
                          Text(_supplierError!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
                          const SizedBox(height: 24),
                          ElevatedButton(onPressed: _fetchSuppliers, child: const Text('Coba Lagi')),
                        ],
                      ),
                    ),
                  )
                : !_isSessionStarted
                    ? _buildCreateSessionForm()
                    : _buildInputProductSection(),
      ),
    );
  }

  Widget _buildCreateSessionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mulai Transaksi Barang Masuk',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih supplier dan isi nomor faktur pembelian terlebih dahulu untuk memulai sesi input.',
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 32),

          // Supplier Selection Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withAlpha(10), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text('Pilih Supplier', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<dynamic>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  hint: const Text('Pilih salah satu supplier'),
                  initialValue: _selectedSupplier,
                  items: _suppliers.map((s) {
                    return DropdownMenuItem<dynamic>(
                      value: s,
                      child: Text("${s['supplier_name']} (${s['status_ppn'] == 'exclude' ? 'Excl PPN' : 'Incl PPN'})"),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSupplier = val;
                    });
                  },
                ),
                const SizedBox(height: 24),

                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Text('Nomor Faktur (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nofakController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: FAK-99201',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _startPembelianSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Mulai Input Barang', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputProductSection() {
    return Column(
      children: [
        // Session Banner Details
        Container(
          width: double.infinity,
          color: const Color(0xFF10B981).withAlpha(20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Supplier: ${_selectedSupplier['supplier_name']}',
                    style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    'Faktur: ${_nofaktur ?? "-"}',
                    style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Status PPN: ${_selectedSupplierStatusPpn == 'exclude' ? "Exclude PPN (-11%)" : "Include PPN (As Is)"}',
                    style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                  Text(
                    'Sesi ID: Lokal',
                    style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14)),
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withAlpha(10), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            labelColor: const Color(0xFF0F172A),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            tabs: [
              const Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.qr_code_scanner_rounded, size: 14), SizedBox(width: 4), Text('Pindai')],
                  ),
                ),
              ),
              const Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.search_rounded, size: 14), SizedBox(width: 4), Text('Cari')],
                  ),
                ),
              ),
              Tab(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_cart_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text('Keranjang (${_cartItems.length})'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab View Contents
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(), // disable swipe
            children: [
              KeepAliveWrapper(child: _buildScannerTab()),
              _buildSearchTab(),
              _buildCartTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScannerTab() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null && !_isLoadingProduct) {
                          _getBarangFromScan(code);
                          break;
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Arahkan kamera pada barcode produk barang masuk.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        if (_isLoadingProduct)
          Container(
            color: Colors.black45,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  SizedBox(height: 16),
                  Text('Memproses produk...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchProductController,
            onChanged: (val) => _searchProducts(val),
            decoration: InputDecoration(
              hintText: 'Cari produk berdasarkan nama atau barcode...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
              suffixIcon: _searchProductController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                      onPressed: () {
                        _searchProductController.clear();
                        _searchProducts('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5)),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),

        // List Results
        Expanded(
          child: _isLoadingSearch
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981))))
              : _searchError != null
                  ? Center(child: Text(_searchError!, style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)))
                  : _searchResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchProductController.text.isEmpty ? Icons.search_rounded : Icons.hourglass_empty_rounded,
                                size: 48,
                                color: const Color(0xFFCBD5E1),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchProductController.text.isEmpty ? 'Ketik nama barang untuk mencari' : 'Barang tidak ditemukan',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 4, 24, 80),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final product = _searchResults[index];
                            final name = product['product_name'] ?? '-';
                            final barcode = product['barcode'] ?? '-';
                            final id = product['product_id'] ?? '-';
                            final sysStock = product['stock'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                                boxShadow: [
                                  BoxShadow(color: const Color(0xFF0F172A).withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                title: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('ID: $id  •  Barcode: $barcode\nStok Sistem: $sysStock', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4)),
                                ),
                                trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981), size: 28),
                                onTap: () => _showInputItemDialog(product),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildCartTab() {
    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'Keranjang Kosong',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pindai atau cari produk untuk menambahkannya.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      );
    }

    final double grandTotal = _cartItems.fold(0.0, (sum, item) => sum + (item['sub_total'] ?? 0.0));

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            itemCount: _cartItems.length,
            itemBuilder: (context, index) {
              final item = _cartItems[index];
              final String name = item['product_name'] ?? '-';
              final String barcode = item['barcode'] ?? '-';
              final String id = item['product_id'] ?? '-';
              final double qty = double.tryParse(item['qty_beli'].toString()) ?? 0.0;
              final double price = double.tryParse(item['harga_beli'].toString()) ?? 0.0;
              final double subTotal = double.tryParse(item['sub_total'].toString()) ?? 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF0F172A).withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: $id  •  Barcode: $barcode',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} pcs',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '@ Rp ${price.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            Text(
                              'Rp ${subTotal.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                    onPressed: () {
                      setState(() {
                        _cartItems.removeAt(index);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('"$name" dihapus dari keranjang lokal 🗑️'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Belanja:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  Text(
                    'Rp ${grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoadingProduct ? null : _finalizePembelian,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoadingProduct
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Selesai & Simpan Ke Server',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  bool get wantKeepAlive => true;
}

