import 'package:coba1/lihat_hasil_barang_masuk_page.dart';
import 'package:coba1/scan_barang_masuk_page.dart';
import 'package:flutter/material.dart';
import 'package:coba1/scan_page.dart';
import 'package:coba1/lihat_hasil_page.dart';
import 'package:coba1/pengaturan_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wbs Mart',
      debugShowCheckedModeBanner: false,
      home: const MainMenuPage(),
      routes: {
        '/scan': (context) => const ScanPage(),
        '/hasil': (context) => const LihatHasilPage(),
        '/scan_bm': (context) => const ScanBarangMasukPage(),
        '/hasil_bm': (context) => const LihatHasilBarangMasukPage(),
        '/pengaturan': (context) => const PengaturanPage(),
      },
    );
  }
}

class MainMenuPage extends StatefulWidget {
  const MainMenuPage({super.key});

  @override
  State<MainMenuPage> createState() => _MainMenuPageState();
}

class _MainMenuPageState extends State<MainMenuPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    BarangMasukPage(),
    StokOpnamePage(),
    PengaturanPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.orange,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        selectedLabelStyle: const TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
        ),
        unselectedLabelStyle: const TextStyle(color: Colors.white),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory, color: Colors.white),
            label: 'Barang Masuk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code, color: Colors.white),
            label: 'Stok Opname',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings, color: Colors.white),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}

// ==========================
// Halaman Barang Masuk
// ==========================
class BarangMasukPage extends StatelessWidget {
  const BarangMasukPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang Masuk'),
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
                Navigator.pushNamed(context, '/scan_bm');
              },
            ),
            _buildMenuButton(
              icon: Icons.list_alt,
              label: 'Lihat Hasil',
              onTap: () {
                Navigator.pushNamed(context, '/hasil_bm');
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

// ==========================
// Halaman Stok Opname
// ==========================
class StokOpnamePage extends StatelessWidget {
  const StokOpnamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok Opname'),
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
