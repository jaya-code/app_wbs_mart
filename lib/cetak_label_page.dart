import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/printer_service.dart';

class CetakLabelPage extends StatefulWidget {
  const CetakLabelPage({super.key});

  @override
  State<CetakLabelPage> createState() => _CetakLabelPageState();
}

class _CetakLabelPageState extends State<CetakLabelPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();
  
  bool _isLoading = false;
  bool _scanned = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  void _resumeScanner() {
    if (mounted) {
      setState(() {
        _scanned = false;
        _isLoading = false;
      });
      try {
        _scannerController.start();
      } catch (e) {
        debugPrint('Error starting scanner: $e');
      }
    }
  }

  // Fetch product by barcode / product ID from API
  Future<void> _fetchAndPrintProduct(String code, {bool isFromScan = false}) async {
    if (isFromScan) {
      try {
        await _scannerController.stop();
      } catch (e) {
        debugPrint('Error stopping scanner: $e');
      }
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Mencari data produk...';
    });

    try {
      final apiLink = await getApiLink();
      final url = Uri.parse('$apiLink/api/product/$code');
      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });

        // Open print dialog with the fetched data
        _showPrintDialog(data, isFromScan: isFromScan);
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Produk dengan kode "$code" tidak ditemukan.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Produk "$code" tidak ditemukan ❌'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );

        if (isFromScan) {
          Future.delayed(const Duration(seconds: 2), () {
            _resumeScanner();
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Terjadi kesalahan: $e';
      });
      if (isFromScan) {
        Future.delayed(const Duration(seconds: 2), () {
          _resumeScanner();
        });
      }
    }
  }

  // Show premium print price label dialog
  void _showPrintDialog(dynamic product, {bool isFromScan = false}) {
    final String productId = (product['product_id'] ?? '').toString();
    final String productName = (product['product_name'] ?? '').toString();
    final String? barcode = product['barcode']?.toString();

    final TextEditingController priceController = TextEditingController();
    int copies = 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isPrinterConnected = PrinterService().isConnected;

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
                      Icons.print_rounded,
                      color: Color(0xFF5F5AF6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Cetak Label Harga',
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
                    // Product info header card
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isPrinterConnected) ...[
                      // Warning printer not connected
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withAlpha(15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444).withAlpha(40)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Printer Terputus',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Hubungkan printer bluetooth terlebih dahulu di halaman Pengaturan Printer.',
                              style: TextStyle(
                                color: Color(0xFF7F1D1D),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(dialogContext); // Close dialog
                                  Navigator.pushNamed(context, '/printer_setup').then((_) {
                                    if (mounted) setState(() {});
                                  });
                                },
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Buka Pengaturan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Input Price field
                    const Text(
                      'Harga Jual (Rupiah)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      autofocus: isPrinterConnected,
                      decoration: InputDecoration(
                        hintText: 'Masukkan harga (misal: 15000)',
                        prefixText: 'Rp ',
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
                    const SizedBox(height: 16),

                    // Copy Count selector with beautiful + / - buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Cetak Label',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (copies > 1) {
                                  setDialogState(() {
                                    copies--;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.remove, size: 18, color: Color(0xFF475569)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              child: Text(
                                '$copies',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  copies++;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add, size: 18, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                  onPressed: !isPrinterConnected
                      ? null
                      : () async {
                          final inputPrice = double.tryParse(priceController.text.trim());
                          if (inputPrice == null || inputPrice <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Silakan masukkan harga jual yang valid! ❌'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(dialogContext); // Close dialog

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mengirim data ke printer... 📤'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          final success = await PrinterService().printPriceLabel(
                            productId: productId,
                            productName: productName,
                            price: inputPrice,
                            barcode: barcode,
                            copies: copies,
                          );

                          if (!mounted) return;

                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Label harga berhasil dicetak! ✅'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gagal mencetak. Silakan cek koneksi printer! ❌'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F5AF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cetak'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      if (isFromScan) {
        _resumeScanner();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = PrinterService().isConnected;
    final printerName = PrinterService().connectedDevice?.name ?? 'Printer';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WBS MART',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Cetak Label Harga',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Printer Status Quick Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isConnected 
                      ? const Color(0xFF10B981).withAlpha(15) 
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected 
                        ? const Color(0xFF10B981).withAlpha(40) 
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                          color: isConnected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isConnected ? 'Terhubung: $printerName' : 'Printer belum terhubung',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isConnected ? const Color(0xFF047857) : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/printer_setup').then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      child: Text(
                        isConnected ? 'Ubah' : 'Hubungkan',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tab bar for Mode Scan vs Cari Manual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withAlpha(10),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Pindai Barcode'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Cari Manual'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Tab View Contents
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // Prevent swipe to scan while typing
                children: [
                  // Tab 1: Scanner View
                  _buildScannerView(),

                  // Tab 2: Manual Search View
                  _buildManualSearchView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tab 1 UI: Barcode Scanner
  Widget _buildScannerView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          flex: 4,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        final String? code = barcode.rawValue;
                        if (code != null && !_scanned && !_isLoading) {
                          _scanned = true;
                          _fetchAndPrintProduct(code, isFromScan: true);
                          break;
                        }
                      }
                    },
                  ),
                  
                  // Scanning target box overlay
                  Center(
                    child: Container(
                      width: 250,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Loading overlay inside scanner
                  if (_isLoading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Mengambil data...',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _statusMessage ?? 'Arahkan kamera pada barcode label harga barang.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: _statusMessage != null && _statusMessage!.contains('tidak ditemukan') 
                  ? const Color(0xFFEF4444) 
                  : const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Tab 2 UI: Manual Search Lookup Form
  Widget _buildManualSearchView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kode Produk atau Barcode',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          
          // Lookup Textfield
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: BRG001 / Barcode ID',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              
              // Lookup Button
              ElevatedButton(
                onPressed: _isLoading 
                    ? null 
                    : () {
                        final code = _searchController.text.trim();
                        if (code.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode barang tidak boleh kosong')),
                          );
                          return;
                        }
                        _fetchAndPrintProduct(code);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Icon(Icons.search_rounded),
              ),
            ],
          ),

          const SizedBox(height: 24),
          
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _statusMessage!.contains('tidak ditemukan') 
                    ? const Color(0xFFEF4444).withAlpha(15) 
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _statusMessage!.contains('tidak ditemukan') 
                      ? const Color(0xFFEF4444).withAlpha(30) 
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusMessage!.contains('tidak ditemukan') ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                    color: _statusMessage!.contains('tidak ditemukan') ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _statusMessage!.contains('tidak ditemukan') ? const Color(0xFFB91C1C) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
