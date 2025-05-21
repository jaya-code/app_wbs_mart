import 'package:coba1/lihat_hasil_page.dart';
import 'package:coba1/pengaturan_page.dart';
import 'package:coba1/scan_page.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Menu Stok Opname',
      debugShowCheckedModeBanner: false,
      home: const StokOpnameMenuPage(),
      routes: {
        '/scan': (context) => const ScanPage(),
        '/hasil': (context) => const LihatHasilPage(),
        '/pengaturan': (context) => const PengaturanPage(),
      },
    );
  }
}

class StokOpnameMenuPage extends StatelessWidget {
  const StokOpnameMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wbs Mart')),
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
                // Aksi saat tombol ditekan
                Navigator.pushNamed(context, '/scan');
              },
            ),
            _buildMenuButton(
              icon: Icons.list_alt,
              label: 'Lihat Hasil',
              onTap: () {
                // Aksi lihat hasil
                Navigator.pushNamed(context, '/hasil');
              },
            ),
            _buildMenuButton(
              icon: Icons.upload_file,
              label: 'Upload Data',
              onTap: () {
                // Aksi upload
              },
            ),
            _buildMenuButton(
              icon: Icons.settings,
              label: 'Pengaturan',
              onTap: () {
                // Aksi pengaturan
                Navigator.pushNamed(context, '/pengaturan');
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
        backgroundColor: const Color.fromARGB(255, 34, 34, 34),
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
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
