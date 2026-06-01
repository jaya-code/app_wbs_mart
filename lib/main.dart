import 'package:coba1/barang_masuk/barang_masuk_page.dart';
import 'package:coba1/barang_masuk/lihat_hasil_barang_masuk_page.dart';
import 'package:coba1/barang_masuk/scan_barang_masuk_page.dart';
import 'package:coba1/stock_opname/scan_stock_opname_page.dart';
import 'package:coba1/stock_opname/search_product_so.dart';
import 'package:coba1/stock_opname/stock_opname_page.dart';
import 'package:flutter/material.dart';
import 'package:coba1/stock_opname/hasil_stock_opname_page.dart';
import 'package:coba1/pengaturan_page.dart';
import 'package:coba1/printer_setup_page.dart';
import 'package:coba1/services/printer_service.dart';
import 'package:coba1/cetak_label_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PrinterService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wbs Mart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5F5AF6),
          primary: const Color(0xFF5F5AF6),
          secondary: const Color(0xFF10B981),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ),
      home: const MainMenuPage(),
      routes: {
        '/scan_stock_opname': (context) => const ScanStockOpnamePage(),
        '/hasil_stock_opname': (context) => const HasilStockOpnamePage(),
        '/search_product_stock_opname':
            (context) => const SearchProductStockOpname(),
        '/scan_bm': (context) => const ScanBarangMasukPage(),
        '/hasil_bm': (context) => const LihatHasilBarangMasukPage(),
        '/pengaturan': (context) => const PengaturanPage(),
        '/printer_setup': (context) => const PrinterSetupPage(),
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
    CetakLabelPage(),
    PengaturanPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Padding bottom to ensure pages don't cover behind the floating bar
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _pages[_currentIndex],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A), // Slate Dark
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withAlpha(46),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.input_outlined, 'Barang Masuk'),
                    _buildNavItem(1, Icons.check_sharp, 'Stok Opname'),
                    _buildNavItem(2, Icons.print_rounded, 'Cetak Label'),
                    _buildNavItem(3, Icons.settings, 'Pengaturan'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5F5AF6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white60,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
