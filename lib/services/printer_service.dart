import 'dart:convert';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Custom BluetoothDevice wrapper class to maintain API compatibility
class BluetoothDevice {
  final String? name;
  final String? address;
  BluetoothDevice({this.name, this.address});
}

// Helper to build standard ESC/POS bytes for print commands
class PrinterBytesBuilder {
  final List<int> _bytes = [];

  void init() {
    _bytes.addAll([0x1B, 0x40]); // ESC @ (Initialize printer)
  }

  void printNewLine() {
    _bytes.addAll([0x0A]);
  }

  void printCustom(String text, int size, int align) {
    // 1. Set Alignment
    // ESC a n -> 0x1B, 0x61, align
    int alignByte = 0;
    if (align == 1) alignByte = 1; // Center
    if (align == 2) alignByte = 2; // Right
    _bytes.addAll([0x1B, 0x61, alignByte]);

    // 2. Set Size and Bold
    int sizeByte = 0x00;
    int boldByte = 0;
    if (size == 1) {
      sizeByte = 0x00;
      boldByte = 1; // Bold, normal size
    } else if (size == 2) {
      sizeByte = 0x11; // Double height & width
      boldByte = 1;
    } else if (size == 3) {
      sizeByte = 0x22; // Triple height & width
      boldByte = 1;
    }
    
    // ESC E n (Bold)
    _bytes.addAll([0x1B, 0x45, boldByte]);
    // GS ! n (Size)
    _bytes.addAll([0x1D, 0x21, sizeByte]);

    // 3. Write Text
    _bytes.addAll(utf8.encode(text));
    
    // 4. Line feed
    _bytes.addAll([0x0A]);
    
    // Reset bold and size to default after printing this line
    _bytes.addAll([0x1B, 0x45, 0]);
    _bytes.addAll([0x1D, 0x21, 0]);
  }

  void writeBytes(List<int> bytes) {
    _bytes.addAll(bytes);
  }

  void setReversePrint(bool enable) {
    _bytes.addAll([0x1D, 0x42, enable ? 1 : 0]);
  }

  List<int> get bytes => _bytes;
}

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  BluetoothDevice? _connectedDevice;
  bool _isConnected = false;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _isConnected;

  // Initialize service, check connection, and try to auto-connect if possible
  Future<void> init() async {
    try {
      // Check if Bluetooth is enabled
      final bool bluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!bluetoothEnabled) return;
      
      // Check runtime permissions  
      final bool permissionGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permissionGranted) return;
      
      await checkConnection();
      if (!_isConnected) {
        await autoConnect();
      }
    } catch (e) {
      // Silently handle init errors
    }
  }

  // Get list of paired bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      // Verify permissions before scanning
      final bool permissionGranted = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!permissionGranted) return [];
      
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices.map((d) => BluetoothDevice(name: d.name, address: d.macAdress)).toList();
    } catch (e) {
      return [];
    }
  }

  // Connect to a device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (device.address == null || device.address!.isEmpty) return false;
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: device.address!);
      if (result) {
        _connectedDevice = device;
        _isConnected = true;
        
        // Save printer to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printer_name', device.name ?? '');
        await prefs.setString('printer_address', device.address ?? '');
        
        return true;
      }
      _connectedDevice = null;
      _isConnected = false;
      return false;
    } catch (e) {
      _connectedDevice = null;
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from device
  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      if (result) {
        _connectedDevice = null;
        _isConnected = false;
      }
      return result;
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
    try {
      final bool state = await PrintBluetoothThermal.connectionStatus;
      _isConnected = state;
      if (!_isConnected) {
        _connectedDevice = null;
      }
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // Clean String for printing (removes non-ascii characters to avoid print errors)
  String _cleanText(String text) {
    return text.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  // Print a test page
  Future<bool> printTest() async {
    if (!await checkConnection()) return false;

    try {
      final builder = PrinterBytesBuilder();
      builder.init();
      builder.printNewLine();
      builder.printCustom("================================", 0, 1);
      builder.printCustom("WBS MART", 3, 1);
      builder.printCustom("PRINTER TEST OK", 1, 1);
      builder.printCustom("Koneksi Bluetooth Berhasil!", 0, 1);
      builder.printCustom("================================", 0, 1);
      builder.printNewLine();
      builder.printNewLine();
      builder.printNewLine();

      final result = await PrintBluetoothThermal.writeBytes(builder.bytes);
      return result;
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

      final builder = PrinterBytesBuilder();
      builder.init();

      for (int i = 0; i < copies; i++) {
        builder.printNewLine();
        // Store Header
        if (showStoreName) {
          builder.printCustom(storeName, 2, 1); // size 2 = bold/large
          builder.printCustom("--------------------------------", 0, 1);
        }
        
        // Product Name (wrapped if too long)
        if (cleanedName.length > 22) {
          builder.printCustom(cleanedName.substring(0, 22), 1, 1);
          if (cleanedName.length > 44) {
            builder.printCustom(cleanedName.substring(22, 44), 1, 1);
          } else {
            builder.printCustom(cleanedName.substring(22), 1, 1);
          }
        } else {
          builder.printCustom(cleanedName, 1, 1); // size 1 = medium
        }
        
        // Product ID or Barcode
        if (showProductId && showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty && cleanedBarcode != cleanedId) {
          builder.printCustom("ID: $cleanedId", 0, 1);
          builder.printCustom("Barcode: $cleanedBarcode", 0, 1);
        } else if (showProductId) {
          builder.printCustom("Kode: $cleanedId", 0, 1);
        } else if (showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          builder.printCustom("Barcode: $cleanedBarcode", 0, 1);
        }

        // Print Barcode Image
        if (showBarcodeImage && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          builder.writeBytes(await _generateRawBarcodeBytes(cleanedBarcode));
        }
        
        builder.printCustom("--------------------------------", 0, 1);
        
        // Large price
        builder.printCustom(formattedPrice, 2, 1); // Large Centered Price
        builder.printCustom("--------------------------------", 0, 1);
        
        // Paper feed space for manual tearing
        for (int j = 0; j < feedLines; j++) {
          builder.printNewLine();
        }
      }

      final result = await PrintBluetoothThermal.writeBytes(builder.bytes);
      return result;
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

  // Wrap text and pad each line to maxLength
  List<String> _wrapAndPadText(String text, int maxLength) {
    List<String> lines = [];
    List<String> words = text.split(' ');
    String currentLine = '';
    
    for (var word in words) {
      if (word.isEmpty) continue;
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if ('$currentLine $word'.length <= maxLength) {
        currentLine = '$currentLine $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines.map((line) {
      if (line.length < maxLength) {
        line = '$line${' ' * (maxLength - line.length)}';
      } else if (line.length > maxLength) {
        line = line.substring(0, maxLength);
      }
      return line;
    }).toList();
  }

  // Center text and pad to maxLength
  String _centerAndPadText(String text, int maxLength) {
    if (text.length >= maxLength) {
      return text.substring(0, maxLength);
    }
    int leftPadding = (maxLength - text.length) ~/ 2;
    int rightPadding = maxLength - text.length - leftPadding;
    return '${' ' * leftPadding}$text${' ' * rightPadding}';
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

      final String formattedPrice = 'Rp. ${_formatRupiah(price).replaceFirst('Rp ', '')}';
      final String cleanedName = _cleanText(productName).toUpperCase(); // Indomaret style uppercase product names
      final String cleanedId = _cleanText(productId);
      final String? cleanedBarcode = barcode != null ? _cleanText(barcode) : null;
      final String cleanedRak = kodeRak != null ? _cleanText(kodeRak) : '';
      
      // Parse return period (extract digits or default to 0)
      String returnDigit = '0';
      if (periodeReturn != null) {
        final match = RegExp(r'\d+').firstMatch(periodeReturn);
        if (match != null) {
          returnDigit = match.group(0)!;
        }
      }
      final String rightMeta = "RT. ($returnDigit)";

      // Left metadata format: "productId / kodeRak" (e.g. "103538299 / R-")
      final String leftMeta = showProductId 
          ? (showRak && cleanedRak.isNotEmpty ? "$cleanedId / $cleanedRak" : cleanedId)
          : (showRak && cleanedRak.isNotEmpty ? cleanedRak : "");

      final DateTime now = DateTime.now();
      final String printDate = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";

      final builder = PrinterBytesBuilder();
      builder.init();

      for (int i = 0; i < copies; i++) {
        // 1. Header Product Name (Normal text, no black background block)
        final List<String> headerLines = _wrapAndPadText(cleanedName, 32);
        for (final line in headerLines) {
          builder.printCustom(line.trimRight(), 1, 0); // left-aligned, size 1 (bold, normal size)
        }

        // 2. Metadata: PLU and Return Period (left-right aligned)
        builder.printCustom(_formatTwoColumns(leftMeta, rightMeta), 0, 1);
        
        // 3. Price (Centered, Large)
        builder.printCustom(formattedPrice, 2, 1); // Size 2 (double size)
        
        if (memberPrice != null && memberPrice > 0) {
          final String formattedMemberPrice = 'Rp. ${_formatRupiah(memberPrice).replaceFirst('Rp ', '')}';
          builder.printCustom("MEMBER: $formattedMemberPrice", 1, 1);
        }

        // 4. Date (Left aligned)
        builder.printCustom(printDate, 0, 0);

        // 5. Barcode Image & Text (if enabled in settings)
        if (showBarcodeImage && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          builder.writeBytes(await _generateRawBarcodeBytes(cleanedBarcode));
          builder.printCustom(cleanedBarcode, 0, 1);
        } else if (showBarcode && cleanedBarcode != null && cleanedBarcode.isNotEmpty) {
          builder.printCustom("Barcode: $cleanedBarcode", 0, 1);
        }

        // 6. Footer Store Name (Black background, white text)
        if (showStoreName) {
          builder.setReversePrint(true);
          final String footerLine = _centerAndPadText(storeName, 32);
          builder.printCustom(footerLine, 1, 0);
          builder.setReversePrint(false);
        }
        
        for (int j = 0; j < feedLines; j++) {
          builder.printNewLine();
        }
      }

      final result = await PrintBluetoothThermal.writeBytes(builder.bytes);
      return result;
    } catch (e) {
      return false;
    }
  }

  // Generate Barcode Image bytes (using ESC/POS commands)
  Future<List<int>> _generateRawBarcodeBytes(String barcode) async {
    final List<int> bytes = [];
    try {
      // 1. Set barcode height: GS h n -> 1D 68 n (e.g. n = 60 dots height)
      bytes.addAll([0x1D, 0x68, 60]);
      
      // 2. Set barcode width: GS w n -> 1D 77 n (e.g. n = 2 width ratio)
      bytes.addAll([0x1D, 0x77, 2]);
  
      // 3. Print barcode using CODE128 (Format 2: m=73)
      // For CODE128, the data starts with code set selector: {B -> 0x7B, 0x42
      final List<int> barcodeBytes = utf8.encode(barcode);
      bytes.addAll([0x1D, 0x6B, 73]); // GS k 73
      bytes.add(barcodeBytes.length + 2); // n (length of selector + barcode data)
      bytes.addAll([0x7B, 0x42]); // {B
      bytes.addAll(barcodeBytes); // barcode data
    } catch (e) {
      // Fallback
    }
    return bytes;
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
