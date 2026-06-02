import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:coba1/services/printer_service.dart';

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final TextEditingController _controller = TextEditingController();
  
  // Label Settings
  final TextEditingController _labelStoreNameController = TextEditingController();
  bool _labelShowStoreName = true;
  bool _labelShowProductId = true;
  bool _labelShowBarcode = true;
  bool _labelShowBarcodeImage = true;
  int _labelFeedLines = 3;

  // Pricetag Settings
  final TextEditingController _pricetagStoreNameController = TextEditingController();
  final TextEditingController _pricetagDefaultReturnController = TextEditingController();
  bool _pricetagShowStoreName = true;
  bool _pricetagShowProductId = true;
  bool _pricetagShowBarcode = true;
  bool _pricetagShowRak = true;
  bool _pricetagShowBarcodeImage = true;
  int _pricetagFeedLines = 3;

  // Configuration Segment
  int _selectedSettingTab = 0; // 0: Label Harga, 1: Price Tag

  @override
  void initState() {
    super.initState();
    _loadSavedSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    _labelStoreNameController.dispose();
    _pricetagStoreNameController.dispose();
    _pricetagDefaultReturnController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _controller.text = prefs.getString('api_link') ?? '';
      
      // Label Settings
      _labelStoreNameController.text = prefs.getString('label_store_name') ?? 'WBS MART';
      _labelShowStoreName = prefs.getBool('label_show_store_name') ?? true;
      _labelShowProductId = prefs.getBool('label_show_product_id') ?? true;
      _labelShowBarcode = prefs.getBool('label_show_barcode') ?? true;
      _labelShowBarcodeImage = prefs.getBool('label_show_barcode_image') ?? true;
      _labelFeedLines = prefs.getInt('label_feed_lines') ?? 3;

      // Pricetag Settings
      _pricetagStoreNameController.text = prefs.getString('pricetag_store_name') ?? 'WBS MART';
      _pricetagDefaultReturnController.text = prefs.getString('pricetag_default_return') ?? '7 Hari';
      _pricetagShowStoreName = prefs.getBool('pricetag_show_store_name') ?? true;
      _pricetagShowProductId = prefs.getBool('pricetag_show_product_id') ?? true;
      _pricetagShowBarcode = prefs.getBool('pricetag_show_barcode') ?? true;
      _pricetagShowRak = prefs.getBool('pricetag_show_rak') ?? true;
      _pricetagShowBarcodeImage = prefs.getBool('pricetag_show_barcode_image') ?? true;
      _pricetagFeedLines = prefs.getInt('pricetag_feed_lines') ?? 3;
    });
  }

  String _normalizeUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return url;

    // Remove trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    // Remove trailing /api
    if (url.endsWith('/api')) {
      url = url.substring(0, url.length - 4);
    }
    // Remove trailing slashes again
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  Future<void> _saveLink() async {
    final prefs = await SharedPreferences.getInstance();
    final url = _normalizeUrl(_controller.text);
    await prefs.setString('api_link', url);
    setState(() {
      _controller.text = url;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link API berhasil disimpan')));
  }

  Future<void> _savePrintSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save Label Settings
    await prefs.setString('label_store_name', _labelStoreNameController.text.trim());
    await prefs.setBool('label_show_store_name', _labelShowStoreName);
    await prefs.setBool('label_show_product_id', _labelShowProductId);
    await prefs.setBool('label_show_barcode', _labelShowBarcode);
    await prefs.setBool('label_show_barcode_image', _labelShowBarcodeImage);
    await prefs.setInt('label_feed_lines', _labelFeedLines);

    // Save Pricetag Settings
    await prefs.setString('pricetag_store_name', _pricetagStoreNameController.text.trim());
    await prefs.setString('pricetag_default_return', _pricetagDefaultReturnController.text.trim());
    await prefs.setBool('pricetag_show_store_name', _pricetagShowStoreName);
    await prefs.setBool('pricetag_show_product_id', _pricetagShowProductId);
    await prefs.setBool('pricetag_show_barcode', _pricetagShowBarcode);
    await prefs.setBool('pricetag_show_rak', _pricetagShowRak);
    await prefs.setBool('pricetag_show_barcode_image', _pricetagShowBarcodeImage);
    await prefs.setInt('pricetag_feed_lines', _pricetagFeedLines);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pengaturan cetak berhasil disimpan')));
  }

  Future<void> _tesKoneksi() async {
    final rawUrl = _controller.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link API tidak boleh kosong')),
      );
      return;
    }

    final baseUrl = _normalizeUrl(rawUrl);
    final testUrl = '$baseUrl/api';

    try {
      final response = await http
          .get(Uri.parse(testUrl))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 500) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Koneksi berhasil (HTTP ${response.statusCode}) ✅')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${response.statusCode} ❌')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Koneksi gagal: $e')));
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Konfirmasi Keluar', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)))),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final apiLink = prefs.getString('api_link') ?? 'http://192.168.8.177:8000';

      if (token != null) {
        await http.post(
          Uri.parse('$apiLink/api/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 4));
      }
    } catch (_) {
      // Ignore network errors on logout to allow offline/best-effort local logout
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('username');
    await prefs.remove('user_id');

    if (!mounted) return;
    Navigator.pop(context); // Close spinner
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Konfigurasi Server API',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sesuaikan alamat endpoint API server backend untuk memproses data inventaris WBS Mart.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Form Container Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.dns_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Alamat Endpoint API',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        hintText: 'http://192.168.1.1:8000',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveLink,
                      icon: const Icon(Icons.save_rounded, size: 20),
                      label: const Text('Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _tesKoneksi,
                      icon: const Icon(Icons.wifi_rounded, size: 20),
                      label: const Text('Tes Koneksi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const Text(
                'Konfigurasi Hardware',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hubungkan perangkat dengan printer thermal bluetooth untuk mencetak label harga barang.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              
              // Bluetooth Printer card
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/printer_setup').then((_) {
                    setState(() {}); // Refresh status when returning
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withAlpha(10),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5F5AF6).withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.print_rounded,
                          color: Color(0xFF5F5AF6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Printer Thermal Bluetooth',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PrinterService().isConnected
                                  ? 'Terhubung: ${PrinterService().connectedDevice?.name ?? "Printer"}'
                                  : 'Belum terhubung',
                              style: TextStyle(
                                fontSize: 13,
                                color: PrinterService().isConnected
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF64748B),
                                fontWeight: PrinterService().isConnected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Tampilan Cetak Label & Pricetag',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sesuaikan dan tinjau langsung elemen informasi yang tercetak pada printer thermal.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Card Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withAlpha(10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Segment Selector
                    Container(
                      height: 42,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedSettingTab = 0),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _selectedSettingTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedSettingTab == 0
                                      ? [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Label Harga (Rak)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedSettingTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                    color: _selectedSettingTab == 0 ? const Color(0xFF5F5AF6) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedSettingTab = 1),
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _selectedSettingTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _selectedSettingTab == 1
                                      ? [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2))]
                                      : null,
                                ),
                                child: Text(
                                  'Price Tag (Gantung)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedSettingTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                    color: _selectedSettingTab == 1 ? const Color(0xFF5F5AF6) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // LIVE PREVIEW CONTAINER
                    _selectedSettingTab == 0 ? _buildLabelPreview() : _buildPricetagPreview(),
                    const SizedBox(height: 24),

                    // DYNAMIC FORM FIELDS
                    if (_selectedSettingTab == 0) ...[
                      // LABEL HARGA FIELDS
                      const Text(
                        'Nama Toko di Label',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _labelStoreNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'WBS MART',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Tampilkan Nama Toko', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _labelShowStoreName,
                        onChanged: (val) => setState(() => _labelShowStoreName = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan ID Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _labelShowProductId,
                        onChanged: (val) => setState(() => _labelShowProductId = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan Barcode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _labelShowBarcode,
                        onChanged: (val) => setState(() => _labelShowBarcode = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan Gambar Barcode (bisa di-scan)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _labelShowBarcodeImage,
                        onChanged: (val) => setState(() => _labelShowBarcodeImage = val),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Jarak Potong Kertas (Feed Lines)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _labelFeedLines,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: List.generate(5, (index) => index + 1).map((val) {
                          return DropdownMenuItem<int>(value: val, child: Text('$val Baris'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _labelFeedLines = val);
                        },
                      ),
                    ] else ...[
                      // PRICE TAG FIELDS
                      const Text(
                        'Nama Toko di Price Tag',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pricetagStoreNameController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'WBS MART',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Default Periode Return',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _pricetagDefaultReturnController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'e.g. 7 Hari',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
                          ),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        title: const Text('Tampilkan Nama Toko', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _pricetagShowStoreName,
                        onChanged: (val) => setState(() => _pricetagShowStoreName = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan ID Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _pricetagShowProductId,
                        onChanged: (val) => setState(() => _pricetagShowProductId = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan Barcode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _pricetagShowBarcode,
                        onChanged: (val) => setState(() => _pricetagShowBarcode = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan Kode Rak', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _pricetagShowRak,
                        onChanged: (val) => setState(() => _pricetagShowRak = val),
                      ),
                      SwitchListTile(
                        title: const Text('Tampilkan Gambar Barcode (bisa di-scan)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        contentPadding: EdgeInsets.zero,
                        value: _pricetagShowBarcodeImage,
                        onChanged: (val) => setState(() => _pricetagShowBarcodeImage = val),
                      ),
                      const SizedBox(height: 12),

                      const Text(
                        'Jarak Potong Kertas (Feed Lines)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _pricetagFeedLines,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                        items: List.generate(5, (index) => index + 1).map((val) {
                          return DropdownMenuItem<int>(value: val, child: Text('$val Baris'));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _pricetagFeedLines = val);
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Simpan Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savePrintSettings,
                  icon: const Icon(Icons.save_rounded, color: Colors.white),
                  label: const Text('Simpan Pengaturan Cetak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Keluar Akun (Logout) Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  label: const Text('Keluar Akun (Logout)', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabelPreview() {
    final storeName = _labelStoreNameController.text.isEmpty ? 'WBS MART' : _labelStoreNameController.text;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6), // Warm white / paper color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          const Text('[ PREVIEW LABEL HARGA ]', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_labelShowStoreName) ...[
            Text(storeName.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          ],
          const Text('MINYAK GORENG SANIA 2L', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 4),
          if (_labelShowProductId && _labelShowBarcode) ...[
            const Text('ID: 10245', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
            const Text('Barcode: 899222333444', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
          ] else if (_labelShowProductId) ...[
            const Text('Kode: 10245', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
          ] else if (_labelShowBarcode) ...[
            const Text('Barcode: 899222333444', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
          ],
          if (_labelShowBarcodeImage) ...[
            const SizedBox(height: 6),
            _buildMockBarcodeImage(),
            const SizedBox(height: 6),
          ],
          const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          const Text('Rp 35.000', style: TextStyle(fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          // Feed lines visualization
          for (int i = 0; i < _labelFeedLines; i++)
            const Text('[ Kertas Kosong ]', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildPricetagPreview() {
    final storeName = _pricetagStoreNameController.text.isEmpty ? 'WBS MART' : _pricetagStoreNameController.text;
    final returnPeriod = _pricetagDefaultReturnController.text.isEmpty ? '7 Hari' : _pricetagDefaultReturnController.text;
    
    final DateTime now = DateTime.now();
    final String printDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().substring(2)}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6), // Warm white / paper color
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          const Text('[ PREVIEW PRICE TAG ]', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 12),
          if (_pricetagShowStoreName) ...[
            Text(storeName.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ],
          const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          
          // PLU & RET Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_pricetagShowProductId ? 'PLU: 10245' : '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
              Text('RET: $returnPeriod', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
            ],
          ),
          const SizedBox(height: 4),

          // Product Name (Uppercase)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('MINYAK GORENG SANIA 2L', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          ),
          const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          
          // Prices
          const Text('HARGA UMUM: Rp 35.000', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          const Text('MEMBER: Rp 34.000', style: TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
          const Text('--------------------------------', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),

          // RAK & TGL Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_pricetagShowRak ? 'RAK: A-04' : '', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
              Text('TGL: $printDate', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
            ],
          ),

          if (_pricetagShowBarcodeImage) ...[
            const SizedBox(height: 6),
            _buildMockBarcodeImage(),
          ] else if (_pricetagShowBarcode) ...[
            const SizedBox(height: 4),
            const Text('899222333444', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF475569))),
          ],
          
          const Text('================================', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFF64748B))),
          // Feed lines visualization
          for (int i = 0; i < _pricetagFeedLines; i++)
            const Text('[ Kertas Kosong ]', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFCBD5E1))),
        ],
      ),
    );
  }

  Widget _buildMockBarcodeImage() {
    return Container(
      width: 150,
      height: 45,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(35, (index) {
                final isBlack = index % 2 == 0 || index % 5 == 0;
                final width = (index % 3 == 0) ? 3.0 : ((index % 7 == 0) ? 1.5 : 2.0);
                return Container(
                  width: width,
                  color: isBlack ? Colors.black : Colors.transparent,
                );
              }),
            ),
          ),
          const SizedBox(height: 2),
          const Text('899222333444', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: Colors.black, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
