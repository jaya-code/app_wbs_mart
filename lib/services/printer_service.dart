import 'dart:convert';
import 'dart:typed_data';
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
      final prefs = await SharedPreferences.getInstance();
      final String storeName = prefs.getString('label_store_name') ?? 'WBS MART';
      final bool showStoreName = prefs.getBool('label_show_store_name') ?? true;
      final bool showProductId = prefs.getBool('label_show_product_id') ?? true;
      final bool showBarcode = prefs.getBool('label_show_barcode') ?? true;
      final bool showBarcodeImage = prefs.getBool('label_show_barcode_image') ?? true;
      final int feedLines = prefs.getInt('label_feed_lines') ?? 3;

      final String formattedPrice = _formatRupiah(price);
      final String cleanedName = _cleanText(productName);
      final String cleanedId = _cleanText(productId);
      final String? cleanedBarcode = barcode != null ? _cleanText(barcode) : null;

      for (int i = 0; i < copies; i++) {
        _bluetooth.printNewLine();
        // Store Header
        if (showStoreName) {
          _bluetooth.printCustom(storeName, 2, 1); // size 2 = bold/large
          _bluetooth.printCustom("--------------------------------", 0, 1);
        }
        
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
        if (showProductId && showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty && cleanedBarcode != cleanedId) {
          _bluetooth.printCustom("ID: $cleanedId", 0, 1);
          _bluetooth.printCustom("Barcode: $cleanedBarcode", 0, 1);
        } else if (showProductId) {
          _bluetooth.printCustom("Kode: $cleanedId", 0, 1);
        } else if (showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          _bluetooth.printCustom("Barcode: $cleanedBarcode", 0, 1);
        }

        // Print Barcode Image
        if (showBarcodeImage && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          await _printRawBarcode(cleanedBarcode);
        }
        
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Large price
        _bluetooth.printCustom(formattedPrice, 2, 1); // Large Centered Price
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // Paper feed space for manual tearing
        for (int j = 0; j < feedLines; j++) {
          _bluetooth.printNewLine();
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Format two columns to align with left and right margins of 32 characters wide (standard 58mm paper)
  String _formatTwoColumns(String left, String right, {int width = 32}) {
    int spaceNeeded = width - left.length - right.length;
    if (spaceNeeded <= 0) {
      return "$left $right";
    }
    return left + (" " * spaceNeeded) + right;
  }

  // Print Pricetag (New Template with member price, shelf location, and return period)
  Future<bool> printPricetag({
    required String productId,
    required String productName,
    required double price,
    double? memberPrice,
    String? kodeRak,
    String? barcode,
    String? periodeReturn,
    int copies = 1,
  }) async {
    if (!await checkConnection()) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String storeName = prefs.getString('pricetag_store_name') ?? 'WBS MART';
      final bool showStoreName = prefs.getBool('pricetag_show_store_name') ?? true;
      final bool showProductId = prefs.getBool('pricetag_show_product_id') ?? true;
      final bool showBarcode = prefs.getBool('pricetag_show_barcode') ?? true;
      final bool showRak = prefs.getBool('pricetag_show_rak') ?? true;
      final bool showBarcodeImage = prefs.getBool('pricetag_show_barcode_image') ?? true;
      final int feedLines = prefs.getInt('pricetag_feed_lines') ?? 3;

      final String formattedPrice = _formatRupiah(price);
      final String formattedMemberPrice = memberPrice != null ? _formatRupiah(memberPrice) : '-';
      final String cleanedName = _cleanText(productName).toUpperCase(); // Indomaret style uppercase product names
      final String cleanedId = _cleanText(productId);
      final String? cleanedBarcode = barcode != null ? _cleanText(barcode) : null;
      final String cleanedRak = kodeRak != null ? _cleanText(kodeRak) : '-';
      final String returnPeriod = _cleanText(periodeReturn ?? '7 Hari');
      
      final DateTime now = DateTime.now();
      final String printDate = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year.toString().substring(2)}";

      for (int i = 0; i < copies; i++) {
        _bluetooth.printNewLine();
        
        // 1. Header Store Name
        if (showStoreName) {
          _bluetooth.printCustom(storeName, 1, 1); // Centered, size 1 (medium bold)
        }
        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // 2. Metadata: PLU and Return Period (left-right aligned)
        final String leftMeta = showProductId ? "PLU: $cleanedId" : "";
        final String rightMeta = "RET: $returnPeriod";
        _bluetooth.printCustom(_formatTwoColumns(leftMeta, rightMeta), 0, 1);
        
        // 3. Product Name (wrapped to max 22 chars for size 1)
        if (cleanedName.length > 22) {
          _bluetooth.printCustom(cleanedName.substring(0, 22), 1, 1);
          if (cleanedName.length > 44) {
            _bluetooth.printCustom(cleanedName.substring(22, 44), 1, 1);
          } else {
            _bluetooth.printCustom(cleanedName.substring(22), 1, 1);
          }
        } else {
          _bluetooth.printCustom(cleanedName, 1, 1);
        }

        _bluetooth.printCustom("--------------------------------", 0, 1);
        
        // 4. Pricing
        _bluetooth.printCustom("HARGA UMUM: $formattedPrice", 1, 1);
        if (memberPrice != null && memberPrice > 0) {
          _bluetooth.printCustom("MEMBER: $formattedMemberPrice", 1, 1);
        }
        
        _bluetooth.printCustom("--------------------------------", 0, 1);

        // 5. Rak Location & Print Date (left-right aligned)
        final String leftBottom = showRak ? "RAK: $cleanedRak" : "";
        final String rightBottom = "TGL: $printDate";
        _bluetooth.printCustom(_formatTwoColumns(leftBottom, rightBottom), 0, 1);

        // 6. Barcode Image & Text
        if (showBarcodeImage && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          await _printRawBarcode(cleanedBarcode);
          _bluetooth.printCustom(cleanedBarcode, 0, 1);
        } else if (showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          _bluetooth.printCustom("Barcode: $cleanedBarcode", 0, 1);
        }

        _bluetooth.printCustom("================================", 0, 1);
        
        for (int j = 0; j < feedLines; j++) {
          _bluetooth.printNewLine();
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  // Print Barcode Image (using ESC/POS commands)
  Future<void> _printRawBarcode(String barcode) async {
    try {
      // 1. Set barcode height: GS h n -> 1D 68 n (e.g. n = 60 dots height)
      await _bluetooth.writeBytes(Uint8List.fromList([0x1D, 0x68, 60]));
      
      // 2. Set barcode width: GS w n -> 1D 77 n (e.g. n = 2 width ratio)
      await _bluetooth.writeBytes(Uint8List.fromList([0x1D, 0x77, 2]));
  
      // 3. Print barcode using CODE128 (Format 2: m=73)
      // For CODE128, the data starts with code set selector: {B -> 0x7B, 0x42
      final List<int> barcodeBytes = utf8.encode(barcode);
      final List<int> payload = [];
      payload.addAll([0x1D, 0x6B, 73]); // GS k 73
      payload.add(barcodeBytes.length + 2); // n (length of selector + barcode data)
      payload.addAll([0x7B, 0x42]); // {B
      payload.addAll(barcodeBytes); // barcode data
  
      await _bluetooth.writeBytes(Uint8List.fromList(payload));
    } catch (e) {
      // Fallback or ignore print barcode errors
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
