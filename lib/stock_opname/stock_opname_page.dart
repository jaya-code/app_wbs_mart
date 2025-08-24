import 'package:flutter/material.dart';

class StokOpnamePage extends StatelessWidget {
  const StokOpnamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: const Text('Stok Opname')),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildMenuButton(
              icon: Icons.qr_code_scanner,
              label: 'Mulai Scan',
              onTap: () {
                Navigator.pushNamed(context, '/scan_stock_opname');
              },
            ),
            _buildMenuButton(
              icon: Icons.input_outlined,
              label: 'Input Barcode',
              onTap: () {
                Navigator.pushNamed(context, '/scan');
              },
            ),
            _buildMenuButton(
              icon: Icons.search,
              label: 'Cari Barang',
              onTap: () {
                Navigator.pushNamed(context, '/scan');
              },
            ),
            _buildMenuButton(
              icon: Icons.list_alt,
              label: 'Lihat Hasil',
              onTap: () {
                Navigator.pushNamed(context, '/hasil');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 237, 196, 62),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(16),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
