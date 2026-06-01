import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;

  // Initialize service, check connection, and try to auto-connect if possible
  Future<void> init() async {
    bool? isConnected = await _bluetooth.isConnected;
    _isConnected = isConnected ?? false;
    
    if (!_isConnected) {
      await autoConnect();
    }
  }

  // Get list of paired bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  // Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
      _connectedDevice = device;
      _isConnected = true;
      
      // Save printer to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('printer_name', device.name ?? '');
      await prefs.setString('printer_address', device.address ?? '');
      
      return true;
    } catch (e) {
      _connectedDevice = null;
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from device
  Future<bool> disconnect() async {
    try {
      await _bluetooth.disconnect();
      _connectedDevice = null;
      _isConnected = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  // Try to connect to saved printer automatically
  Future<bool> autoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddress = prefs.getString('printer_address');
      if (savedAddress == null || savedAddress.isEmpty) return false;

      final devices = await getPairedDevices();
      final targetDevice = devices.firstWhere(
        (d) => d.address == savedAddress,
        orElse: () => throw Exception('Device not found'),
      );

      return await connect(targetDevice);
    } catch (e) {
      return false;
    }
  }

  // Check state dynamically
  Future<bool> checkConnection() async {
    bool? state = await _bluetooth.isConnected;
    _isConnected = state ?? false;
    if (!_isConnected) {
      _connectedDevice = null;
    }
    return _isConnected;
  }

  // Clean String for printing (removes non-ascii characters to avoid print errors)
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  // Print a test page
  Future<bool> printTest() async {
    if (!await checkConnection()) return false;

    try {
      _bluetooth.printNewLine();
      _bluetooth.printCustom("================================", 0, 1);
      _bluetooth.printCustom("WBS MART", 3, 1);
      _bluetooth.printCustom("PRINTER TEST OK", 1, 1);
      _bluetooth.printCustom("Koneksi Bluetooth Berhasil!", 0, 1);
      _bluetooth.printCustom("================================", 0, 1);
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Print Price Label
  Future<bool> printPriceLabel({
    required String productId,
    required String productName,
    required double price,
    String? barcode,
    int copies = 1,
  }) async {
    if (!await checkConnection()) return false;

    try {
      final String formattedPrice = _formatRupiah(price);
      final String cleanedName = _cleanText(productName);
      final String cleanedId = _cleanText(productId);
      final String? cleanedBarcode = barcode != null ? _cleanText(barcode) : null;

      for (int i = 0; i < copies; i++) {
        _bluetooth.printNewLine();
        // Store Header
        _bluetooth.printCustom("WBS MART", 2, 1); // size 2 = bold/large
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Product Name (wrapped if too long)
        if (cleanedName.length > 22) {
          _bluetooth.printCustom(cleanedName.substring(0, 22), 1, 1);
          if (cleanedName.length > 44) {
            _bluetooth.printCustom(cleanedName.substring(22, 44), 1, 1);
          } else {
            _bluetooth.printCustom(cleanedName.substring(22), 1, 1);
          }
        } else {
          _bluetooth.printCustom(cleanedName, 1, 1); // size 1 = medium
        }
        
        // Product ID or Barcode
        if (cleanedBarcode != null && cleanedBarcode.isNotEmpty && cleanedBarcode != cleanedId) {
          _bluetooth.printCustom("ID: $cleanedId", 0, 1);
          _bluetooth.printCustom("Barcode: $cleanedBarcode", 0, 1);
        } else {
          _bluetooth.printCustom("Kode: $cleanedId", 0, 1);
        }
        
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Large price
        _bluetooth.printCustom(formattedPrice, 2, 1); // Large Centered Price
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Paper feed space for manual tearing
        _bluetooth.printNewLine();
        _bluetooth.printNewLine();
        _bluetooth.printNewLine();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Formatting utility for Rupiah
  String _formatRupiah(double number) {
    String str = number.round().toString();
    String result = '';
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      result = '${str[i]}$result';
      count++;
      if (count % 3 == 0 && i != 0) {
        result = '.$result';
      }
    }
    return 'Rp $result';
  }
}
