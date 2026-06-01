import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coba1/services/printer_service.dart';

class LihatHasilBarangMasukPage extends StatefulWidget {
  const LihatHasilBarangMasukPage({super.key});

  @override
  State<LihatHasilBarangMasukPage> createState() =>
      _LihatHasilBarangMasukPageState();
}

class _LihatHasilBarangMasukPageState extends State<LihatHasilBarangMasukPage> {
  List<dynamic> hasil = [];
  List<dynamic> filteredHasil = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  Future<String> getApiLink() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_link') ?? 'http://192.168.8.177:8000';
  }

  // Method to show edit dialog for editing stok_real and update on API
  void showEditDialog(dynamic id, dynamic stokReal) {
    final TextEditingController stokController = TextEditingController(
      text: stokReal?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit Stok Real'),
            content: TextField(
              controller: stokController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stok Real'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newStok = int.tryParse(stokController.text);
                  if (newStok == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stok tidak valid')),
                    );
                    return;
                  }

                  if (!mounted) return;
                  Navigator.pop(dialogContext); // Tutup dialog

                  setState(() {
                    _isLoading = true;
                  });

                  final apiLink = await getApiLink();
                  final url = Uri.parse('$apiLink/api/barang-masuk/$id');
                  final response = await http.put(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'stok_real': newStok}),
                  );

                  if (response.statusCode == 200 ||
                      response.statusCode == 204) {
                    await fetchData(); // Ambil data fresh dari server
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   const SnackBar(content: Text('Stok berhasil diperbarui')),
                    // );
                  } else {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gagal memperbarui stok')),
                    );
                  }

                  setState(() {
                    _isLoading = false;
                  });
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
  }

  void showPrintDialog(dynamic item) {
    final String productId = (item['product_id'] ?? '').toString();
    final String productName = (item['product_name'] ?? '').toString();
    final String? barcode = item['barcode']?.toString();

    final TextEditingController priceController = TextEditingController();
    int copies = 1;

    showDialog(
      context: context,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product info header
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
                          border: Border.all(
                            color: const Color(0xFFEF4444).withAlpha(40),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
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
                                  Navigator.pushNamed(
                                    context,
                                    '/printer_setup',
                                  ).then((_) {
                                    // Refresh state
                                    setState(() {});
                                  });
                                },
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Buka Pengaturan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                      decoration: InputDecoration(
                        hintText: 'Masukkan harga (misal: 15000)',
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
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      !isPrinterConnected
                          ? null
                          : () async {
                            final inputPrice = double.tryParse(
                              priceController.text.trim(),
                            );
                            if (inputPrice == null || inputPrice <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Silakan masukkan harga jual yang valid! ❌',
                                  ),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(dialogContext); // Close dialog

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mengirim data to printer... 📤'),
                                duration: Duration(seconds: 1),
                              ),
                            );

                            final success = await PrinterService()
                                .printPriceLabel(
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
                                  content: Text(
                                    'Label harga berhasil dicetak! ✅',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Gagal mencetak. Silakan cek koneksi printer! ❌',
                                  ),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
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
                  child: const Text('Cetak'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiLink = await getApiLink();
      final url = Uri.parse('$apiLink/api/barang-masuk');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List) {
          hasil = List<dynamic>.from(data);
        } else {
          hasil = [];
        }
      } else {
        hasil = [];
      }
    } catch (e) {
      hasil = [];
    }
    _filterResults();
    setState(() {
      _isLoading = false;
    });
  }

  void _filterResults() {
    if (_searchQuery.isEmpty) {
      filteredHasil = List<dynamic>.from(hasil);
    } else {
      filteredHasil =
          hasil.where((item) {
            final productName =
                (item['product_name'] ?? '').toString().toLowerCase();
            final productId =
                (item['product_id'] ?? '').toString().toLowerCase();
            return productName.contains(_searchQuery.toLowerCase()) ||
                productId.contains(_searchQuery.toLowerCase());
          }).toList();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchData();
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _filterResults();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Method to confirm and handle deletion of an item
  void confirmHapus(dynamic id) async {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Konfirmasi Hapus'),
            content: const Text('Apakah Anda yakin ingin menghapus item ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(dialogContext); // Close dialog first
                  final apiLink = await getApiLink();
                  final url = Uri.parse('$apiLink/api/barang-masuk/$id');
                  final response = await http.delete(url);
                  if (!mounted) return;
                  if (response.statusCode == 200 ||
                      response.statusCode == 204) {
                    setState(() {
                      hasil.removeWhere((item) => item['id'] == id);
                      _filterResults();
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gagal menghapus data di server'),
                      ),
                    );
                  }
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Barang Masuk')),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari berdasarkan ID atau nama produk...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF64748B),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              ),
            ),

            // Results list
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filteredHasil.isEmpty
                      ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inbox_rounded,
                              size: 64,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Tidak ada data ditemukan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
                        itemCount: filteredHasil.length,
                        itemBuilder: (context, index) {
                          final item = filteredHasil[index];
                          final id = item['id'];
                          final stokReal = item['stok_real'];
                          final productName = item['product_name'];
                          final productId = item['product_id'];

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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                decoration: const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: Color(
                                        0xFF5F5AF6,
                                      ), // Left Indigo Strip
                                      width: 5,
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    "$productId",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      "$productName\nStok Real: $stokReal",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder:
                                          (dialogContext) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                            ),
                                            title: const Text('Detail Produk'),
                                            content: Text(
                                              'Product ID: $productId\n'
                                              'Nama Produk: $productName\n'
                                              'Jumlah Stok Real: $stokReal',
                                              style: const TextStyle(
                                                height: 1.5,
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      dialogContext,
                                                    ),
                                                child: const Text('Tutup'),
                                              ),
                                            ],
                                          ),
                                    );
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Print Button Wrapper
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF5F5AF6,
                                          ).withAlpha(20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.print_rounded,
                                            color: Color(0xFF5F5AF6),
                                            size: 18,
                                          ),
                                          onPressed:
                                              () => showPrintDialog(item),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Edit Button Wrapper
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3B82F6,
                                          ).withAlpha(20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit_rounded,
                                            color: Color(0xFF3B82F6),
                                            size: 18,
                                          ),
                                          onPressed:
                                              () =>
                                                  showEditDialog(id, stokReal),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete Button Wrapper
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFFEF4444,
                                          ).withAlpha(20),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete_rounded,
                                            color: Color(0xFFEF4444),
                                            size: 18,
                                          ),
                                          onPressed: () => confirmHapus(id),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
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
