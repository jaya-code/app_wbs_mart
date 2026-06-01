import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'services/printer_service.dart';

class PrinterSetupPage extends StatefulWidget {
  const PrinterSetupPage({super.key});

  @override
  State<PrinterSetupPage> createState() => _PrinterSetupPageState();
}

class _PrinterSetupPageState extends State<PrinterSetupPage> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  String _statusMessage = 'Mengecek bluetooth...';

  @override
  void initState() {
    super.initState();
    _checkStatusAndLoadDevices();
  }

  Future<void> _checkStatusAndLoadDevices() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Mencari perangkat terpasang...';
    });
    
    await _printerService.checkConnection();
    final paired = await _printerService.getPairedDevices();
    
    setState(() {
      _devices = paired;
      _isScanning = false;
      _statusMessage = paired.isEmpty 
          ? 'Tidak ada perangkat bluetooth terpasang (paired).' 
          : 'Berhasil menemukan perangkat.';
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Menghubungkan ke ${device.name}...';
    });

    final success = await _printerService.connect(device);

    setState(() {
      _isScanning = false;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil terhubung ke ${device.name} ✅'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _checkStatusAndLoadDevices(); // Refresh state
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal terhubung ke ${device.name} ❌. Pastikan printer menyala.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _disconnectDevice() async {
    final name = _printerService.connectedDevice?.name ?? 'Printer';
    setState(() {
      _isScanning = true;
      _statusMessage = 'Memutuskan koneksi...';
    });

    final success = await _printerService.disconnect();

    setState(() {
      _isScanning = false;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Koneksi terputus dari $name'),
          backgroundColor: const Color(0xFF64748B),
        ),
      );
      _checkStatusAndLoadDevices(); // Refresh state
    }
  }

  Future<void> _testPrint() async {
    setState(() {
      _statusMessage = 'Mencetak halaman uji coba...';
    });
    final success = await _printerService.printTest();
    
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perintah cetak uji coba terkirim! 🖨️'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mencetak. Printer tidak terhubung ❌'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
    _checkStatusAndLoadDevices();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _printerService.isConnected;
    final activeDevice = _printerService.connectedDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Bluetooth'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Connection Status Header Card
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: isConnected
                      ? const LinearGradient(
                          colors: [Color(0xFF5F5AF6), Color(0xFF8B5CF6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF475569), Color(0xFF64748B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (isConnected ? const Color(0xFF5F5AF6) : const Color(0xFF475569))
                          .withAlpha(50),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Printer',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  isConnected ? 'TERHUBUNG' : 'BELUM TERHUBUNG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Dynamic pulse/dot indicator
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isConnected ? const Color(0xFF34D399) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isConnected ? const Color(0xFF34D399) : const Color(0xFF94A3B8))
                                    .withAlpha(120),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (isConnected && activeDevice != null) ...[
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        activeDevice.name ?? 'Unknown Device',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mac Address: ${activeDevice.address}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _testPrint,
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              label: const Text('Cetak Tes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withAlpha(40),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _disconnectDevice,
                              icon: const Icon(Icons.link_off_rounded, size: 18),
                              label: const Text('Putuskan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),

            // Scanning state or guidance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _isScanning ? 'Mencari...' : _statusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: _isScanning ? FontWeight.w600 : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isScanning)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5F5AF6)),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: _checkStatusAndLoadDevices,
                      child: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF5F5AF6)),
                          SizedBox(width: 4),
                          Text(
                            'Scan Ulang',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5F5AF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Device List Container
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bluetooth_searching_rounded,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Belum Ada Perangkat Bluetooth',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pasangkan (pair) printer thermal Anda terlebih dahulu di pengaturan Bluetooth bawaan HP Anda, kemudian kembali ke halaman ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isThisConnected = isConnected && activeDevice?.address == device.address;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isThisConnected 
                                  ? const Color(0xFF5F5AF6).withAlpha(100) 
                                  : const Color(0xFFF1F5F9),
                              width: isThisConnected ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withAlpha(5),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isThisConnected 
                                    ? const Color(0xFF5F5AF6).withAlpha(20) 
                                    : const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.print_rounded,
                                color: isThisConnected ? const Color(0xFF5F5AF6) : const Color(0xFF64748B),
                                size: 22,
                              ),
                            ),
                            title: Text(
                              device.name ?? 'Nama Tidak Diketahui',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isThisConnected ? const Color(0xFF5F5AF6) : const Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'MAC: ${device.address}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            trailing: isThisConnected
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Aktif',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _isScanning ? null : () => _connectToDevice(device),
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      foregroundColor: const Color(0xFF0F172A),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Hubungkan',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
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
