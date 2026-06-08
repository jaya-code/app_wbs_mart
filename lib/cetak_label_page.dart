import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/printer_service.dart';
import 'package:coba1/services/api_client.dart';

class PrintQueueItem {
  String productId;
  String productName;
  String? barcode;
  double price;
  double? memberPrice;
  String? kodeRak;
  int copies;
  String templateType; // 'label' or 'pricetag'
  String? periodeReturn;

  PrintQueueItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.price,
    this.memberPrice,
    this.kodeRak,
    required this.copies,
    required this.templateType,
    this.periodeReturn,
  });
}

class CetakLabelPage extends StatefulWidget {
  const CetakLabelPage({super.key});

  @override
  State<CetakLabelPage> createState() => _CetakLabelPageState();
}

class _CetakLabelPageState extends State<CetakLabelPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isLoading = false;
  bool _scanned = false;
  String? _statusMessage;

  // Search manual state
  List<dynamic> _searchResults = [];
  bool _isLoadingSearch = false;
  String? _searchError;

  // Print Queue
  final List<PrintQueueItem> _printQueue = [];
  String _defaultReturnPeriod = '7 Hari';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _defaultReturnPeriod =
          prefs.getString('pricetag_default_return') ?? '7 Hari';
    });
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
    }
  }

  // Fetch product detail for scanning
  Future<void> _fetchProductForScan(String code) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Mencari data produk...';
    });

    try {
      final response = await ApiClient.get(
        '/api/product/$code',
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          setState(() {
            _isLoading = false;
            _statusMessage = null;
          });

          _showAddToQueueDialog(responseData['data'], isFromScan: true);
          return;
        }
      }

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
      Future.delayed(const Duration(seconds: 2), () {
        _resumeScanner();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Terjadi kesalahan: $e';
      });
      Future.delayed(const Duration(seconds: 2), () {
        _resumeScanner();
      });
    }
  }

  // Search product manually
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
      final response = await ApiClient.get(
        '/api/products/search?q=$query',
      ).timeout(const Duration(seconds: 8));

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
        _searchError = 'Gagal memuat hasil pencarian.';
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

  // Add Product to Queue Dialog
  void _showAddToQueueDialog(
    dynamic product, {
    bool isFromScan = false,
    PrintQueueItem? existingItem,
  }) {
    final String productId = (product['product_id'] ?? '').toString();
    final String productName = (product['product_name'] ?? '').toString();
    final String? barcode = product['barcode']?.toString();
    final String? kodeRak = product['kode_rak']?.toString();
    final double sellingPrice =
        double.tryParse(product['selling_price'].toString()) ?? 0.0;
    final double? sellingPriceMember =
        product['selling_price_member'] != null
            ? double.tryParse(product['selling_price_member'].toString())
            : null;

    final TextEditingController priceController = TextEditingController(
      text:
          existingItem != null
              ? existingItem.price.toStringAsFixed(0)
              : sellingPrice.toStringAsFixed(0),
    );
    final TextEditingController memberPriceController = TextEditingController(
      text:
          existingItem != null
              ? (existingItem.memberPrice?.toStringAsFixed(0) ?? '')
              : (sellingPriceMember?.toStringAsFixed(0) ?? ''),
    );
    final String defaultReturn =
        existingItem != null
            ? (existingItem.periodeReturn ?? _defaultReturnPeriod)
            : (product['periode_return']?.toString() ?? _defaultReturnPeriod);
    final TextEditingController returnPeriodController = TextEditingController(
      text: defaultReturn,
    );

    int copies = existingItem != null ? existingItem.copies : 1;
    String templateType =
        existingItem != null ? existingItem.templateType : 'label';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
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
                    child: Icon(
                      existingItem != null
                          ? Icons.edit_rounded
                          : Icons.add_to_photos_rounded,
                      color: const Color(0xFF5F5AF6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    existingItem != null
                        ? 'Edit Item Antrian'
                        : 'Tambah ke Antrian',
                    style: const TextStyle(
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
                    // Info Produk
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
                          if (kodeRak != null && kodeRak.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Rak: $kodeRak',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opsi Tipe Cetak
                    const Text(
                      'Tipe Cetakan Label',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: templateType,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'label',
                          child: Text('Label Harga (Rak)'),
                        ),
                        DropdownMenuItem(
                          value: 'pricetag',
                          child: Text('Price Tag (Gantung)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            templateType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Harga Umum
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
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF5F5AF6),
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // Harga Member (Hanya muncul jika Pricetag)
                    if (templateType == 'pricetag') ...[
                      const Text(
                        'Harga Member (Rupiah)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: memberPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF5F5AF6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Periode Return',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: returnPeriodController,
                        decoration: InputDecoration(
                          hintText: 'e.g. 7 Hari',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF5F5AF6),
                              width: 1.5,
                            ),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Jumlah Copies
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jumlah Cetak',
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
                                child: const Icon(
                                  Icons.remove,
                                  size: 18,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
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
                                child: const Icon(
                                  Icons.add,
                                  size: 18,
                                  color: Color(0xFF475569),
                                ),
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
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (isFromScan) {
                      _resumeScanner();
                    }
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final double? parsedPrice = double.tryParse(
                      priceController.text.trim(),
                    );
                    final double? parsedMemberPrice =
                        templateType == 'pricetag'
                            ? double.tryParse(memberPriceController.text.trim())
                            : null;

                    if (parsedPrice == null || parsedPrice <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Masukkan harga jual yang valid! ❌'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    setState(() {
                      if (existingItem != null) {
                        // Edit existing
                        existingItem.price = parsedPrice;
                        existingItem.memberPrice = parsedMemberPrice;
                        existingItem.copies = copies;
                        existingItem.templateType = templateType;
                        existingItem.periodeReturn =
                            templateType == 'pricetag'
                                ? returnPeriodController.text.trim()
                                : null;
                      } else {
                        // Add new to queue
                        _printQueue.add(
                          PrintQueueItem(
                            productId: productId,
                            productName: productName,
                            barcode: barcode,
                            price: parsedPrice,
                            memberPrice: parsedMemberPrice,
                            kodeRak: kodeRak,
                            copies: copies,
                            templateType: templateType,
                            periodeReturn:
                                templateType == 'pricetag'
                                    ? returnPeriodController.text.trim()
                                    : null,
                          ),
                        );
                      }
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existingItem != null
                              ? 'Item antrian diperbarui! 📝'
                              : 'Produk ditambahkan ke antrian! 📥',
                        ),
                        backgroundColor: const Color(0xFF5F5AF6),
                      ),
                    );

                    if (isFromScan) {
                      _resumeScanner();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F5AF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(existingItem != null ? 'Perbarui' : 'Tambah'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Print all items in queue
  Future<void> _printAllQueue() async {
    final isPrinterConnected = PrinterService().isConnected;
    if (!isPrinterConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Printer terputus! Sambungkan printer di pengaturan. ❌',
          ),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    if (_printQueue.isEmpty) return;

    // Show Progress Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5F5AF6)),
              ),
              SizedBox(width: 24),
              Expanded(
                child: Text(
                  'Sedang mencetak antrian label...',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );

    int printedCount = 0;
    bool success = true;

    for (final item in _printQueue) {
      if (item.templateType == 'label') {
        success = await PrinterService().printPriceLabel(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          barcode: item.barcode,
          copies: item.copies,
        );
      } else {
        success = await PrinterService().printPricetag(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          memberPrice: item.memberPrice,
          kodeRak: item.kodeRak,
          barcode: item.barcode,
          periodeReturn: item.periodeReturn,
          copies: item.copies,
        );
      }

      if (!success) {
        break;
      }
      printedCount++;
      // Sleep a bit to prevent print buffer overflow
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (!mounted) return;
    Navigator.pop(context); // Close progress dialog

    if (success) {
      setState(() {
        _printQueue.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Semua label berhasil dicetak! 🎉'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Koneksi terputus! Hanya mencetak $printedCount item. ❌',
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                        'Cetak Label & Price Tag',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Printer Status Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isConnected
                          ? const Color(0xFF10B981).withAlpha(15)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isConnected
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
                          isConnected
                              ? Icons.print_rounded
                              : Icons.print_disabled_rounded,
                          color:
                              isConnected
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isConnected
                              ? 'Terhubung: $printerName'
                              : 'Printer belum terhubung',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isConnected
                                    ? const Color(0xFF047857)
                                    : const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/printer_setup').then((
                          _,
                        ) {
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

            // Tab bar for Mode Scan vs Cari Manual vs Antrian
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
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  tabs: [
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Pindai'),
                          ],
                        ),
                      ),
                    ),
                    const Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded, size: 14),
                            SizedBox(width: 4),
                            Text('Cari'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.list_alt_rounded, size: 14),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Antrian (${_printQueue.length})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  KeepAliveWrapper(child: _buildScannerView()),
                  _buildManualSearchView(),
                  _buildQueueView(),
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
                          _fetchProductForScan(code);
                          break;
                        }
                      }
                    },
                  ),
                  Center(
                    child: Container(
                      width: 250,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  if (_isLoading)
                    Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Mengambil data...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
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
            _statusMessage ?? 'Arahkan kamera pada barcode produk.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color:
                  _statusMessage != null &&
                          _statusMessage!.contains('tidak ditemukan')
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

  // Tab 2 UI: Manual Search
  Widget _buildManualSearchView() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => _searchProducts(val),
            decoration: InputDecoration(
              hintText: 'Cari produk berdasarkan nama atau barcode...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
              ),
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: Color(0xFF64748B),
                        ),
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
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF5F5AF6),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),

        // List Results
        Expanded(
          child:
              _isLoadingSearch
                  ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF5F5AF6),
                      ),
                    ),
                  )
                  : _searchError != null
                  ? Center(
                    child: Text(
                      _searchError!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  : _searchResults.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchController.text.isEmpty
                              ? Icons.search_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 48,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Ketik nama barang untuk mencari'
                              : 'Barang tidak ditemukan',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final name = product['product_name'] ?? '-';
                      final barcode = product['barcode'] ?? '-';
                      final price =
                          double.tryParse(
                            product['selling_price'].toString(),
                          ) ??
                          0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
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
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Barcode: $barcode\nHarga: Rp ${price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: Color(0xFF5F5AF6),
                              size: 28,
                            ),
                            onTap: () => _showAddToQueueDialog(product),
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  // Tab 3 UI: Print Queue List
  Widget _buildQueueView() {
    if (_printQueue.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.playlist_remove_rounded,
              size: 64,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 16),
            const Text(
              'Antrian cetak kosong',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
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

    final int totalCopies = _printQueue.fold(
      0,
      (sum, item) => sum + item.copies,
    );

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            itemCount: _printQueue.length,
            itemBuilder: (context, index) {
              final item = _printQueue[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Section: Texts and details (Expanded to prevent overflow)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Barcode: ${item.barcode ?? "-"}  •  Rak: ${item.kodeRak ?? "-"}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          item.templateType == 'label'
                                              ? const Color(0xFF3B82F6).withAlpha(20)
                                              : const Color(0xFF5F5AF6).withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.templateType == 'label'
                                          ? 'Label Rak'
                                          : 'Price Tag',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            item.templateType == 'label'
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF5F5AF6),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Rp ${item.price.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (item.templateType == 'pricetag') ...[
                                    if (item.memberPrice != null)
                                      Text(
                                        '(Mem: Rp ${item.memberPrice!.toStringAsFixed(0)})',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF10B981),
                                        ),
                                      ),
                                    Text(
                                      '(Ret: ${item.periodeReturn ?? "7 Hari"})',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Right Section: Copies & Compact Action Buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'x${item.copies}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              icon: const Icon(
                                Icons.edit_rounded,
                                color: Color(0xFF3B82F6),
                                size: 18,
                              ),
                              onPressed: () {
                                final productMap = {
                                  'product_id': item.productId,
                                  'product_name': item.productName,
                                  'barcode': item.barcode,
                                  'kode_rak': item.kodeRak,
                                  'selling_price': item.price,
                                  'selling_price_member': item.memberPrice,
                                  'periode_return': item.periodeReturn,
                                };
                                _showAddToQueueDialog(
                                  productMap,
                                  existingItem: item,
                                );
                              },
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFEF4444),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _printQueue.removeAt(index);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Action panel at bottom
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _printQueue.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Hapus Semua',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _printAllQueue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5F5AF6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Cetak ($totalCopies)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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

