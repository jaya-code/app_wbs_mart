import 'package:coba1/barang_masuk/barang_masuk_page.dart';
import 'package:coba1/barang_masuk/lihat_hasil_barang_masuk_page.dart';
import 'package:coba1/barang_masuk/scan_barang_masuk_page.dart';
import 'package:coba1/stock_opname/scan_stock_opname_page.dart';
import 'package:coba1/stock_opname/stock_opname_page.dart';
import 'package:flutter/material.dart';
import 'package:coba1/stock_opname/lihat_hasil_page.dart';
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
        '/scan_stock_opname': (context) => const ScanStockOpnamePage(),
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
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.white,
        selectedLabelStyle: const TextStyle(
          color: Color.fromARGB(255, 0, 0, 0),
        ),
        unselectedLabelStyle: const TextStyle(color: Colors.white),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Barang Masuk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'Stok Opname',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
