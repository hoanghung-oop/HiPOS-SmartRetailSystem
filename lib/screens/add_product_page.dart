// File: lib/screens/add_product_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Đã thêm để dùng TextInputFormatter
import 'package:intl/intl.dart'; // Đã thêm để dùng định dạng số có dấu chấm
import 'package:image_picker/image_picker.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
// ignore: deprecated_member_use
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;


class AddProductPage extends StatefulWidget {
  final String? initialBarcode;
  const AddProductPage({super.key, this.initialBarcode});
  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _firestoreService = FirestoreService();
  final _idCtrl = TextEditingController(text: "SP${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}");
  final _barcodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  // ĐÃ SỬA: Bỏ giá trị '0' mặc định để người dùng nhập liền không cần xóa
  final _importPriceCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();

  final _descriptionCtrl = TextEditingController();
  final _otherInfoCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();

  String _category = "Chưa phân loại";
  String _brand = "Không có";
  String? _imagePath;
  bool _isDirectSale = true;
  bool _isPointAccumulation = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) _barcodeCtrl.text = widget.initialBarcode!;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Chụp ảnh mới"),
            // Nén ảnh trực tiếp xuống kích thước 300x300, chất lượng 70%
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: 300,
              maxHeight: 300,
              imageQuality: 70,
            )),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Chọn từ thư viện"),
            onTap: () async => Navigator.pop(ctx, await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 300,
              maxHeight: 300,
              imageQuality: 70,
            )),
          ),
        ],
      ),
    );

    if (res != null) {
      // Đọc bytes và chuyển đổi sang chuỗi Base64 siêu nhẹ
      final bytes = await res.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _imagePath = "data:image/jpeg;base64,$base64String";
      });
    }
  }

  Future<void> _scanBarcode(TextEditingController ctrl) async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') ctrl.text = res;
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) return;

    final p = Product(
      id: _idCtrl.text, name: _nameCtrl.text,
      // ĐÃ SỬA: Xóa dấu chấm đi (replaceAll) trước khi chuyển thành số để lưu vào database
      price: double.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0,
      importPrice: double.tryParse(_importPriceCtrl.text.replaceAll('.', '')) ?? 0,
      quantity: int.tryParse(_quantityCtrl.text.replaceAll('.', '')) ?? 0,
      minStock: int.tryParse(_minStockCtrl.text.replaceAll('.', '')) ?? 0,

      barcode: _barcodeCtrl.text, imagePath: _imagePath ?? "",
      category: _category, brand: _brandCtrl.text.isEmpty ? _brand : _brandCtrl.text,
      description: _descriptionCtrl.text,
      unit: _unitCtrl.text,
      otherInfo: _otherInfoCtrl.text, isDirectSale: _isDirectSale, isPointAccumulation: _isPointAccumulation,
    );
    try {
      await _firestoreService.addProduct(p);
      if (mounted) Navigator.pop(context, p);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Lỗi mạng hoặc máy chủ. Vui lòng kiểm tra lại kết nối!"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            )
        );
      }
    }
  }

  ImageProvider? _getPreviewImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('data:image')) {
      return MemoryImage(base64Decode(path.split(',').last));
    }
    if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return NetworkImage(path);
    }
    try {
      if (File(path).existsSync()) return FileImage(File(path));
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text("Hàng hóa mới"), actions: [TextButton(onPressed: _save, child: const Text("LƯU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 500 : screenWidth),
            child: Column(children: [
              GestureDetector(onTap: _pickImage, child: Container(height: 120, width: 120, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), image: _getPreviewImageProvider(_imagePath) != null
                  ? DecorationImage(image: _getPreviewImageProvider(_imagePath)!, fit: BoxFit.cover)
                  : null,), child: _imagePath == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null)),
              const SizedBox(height: 20),
              _buildFieldWithScan("Mã hàng", _idCtrl),
              _buildFieldWithScan("Mã vạch", _barcodeCtrl),
              _buildTextField("Tên hàng (*)", _nameCtrl),
              _buildSelectField("Nhóm hàng", _category, ["Chưa phân loại", "Đồ uống", "Thực phẩm", "Khác"], (v) => setState(() => _category = v)),
              _buildSelectField("Thương hiệu", _brand, ["Không có", "Coca Cola", "Pepsi", "Khác"], (v) {
                setState(() {
                  _brand = v;
                  if (v != "Khác") _brandCtrl.clear();
                });
              }),
              if (_brand == "Khác") _buildTextField("Nhập thương hiệu khác", _brandCtrl),

              _buildTextField("Giá vốn", _importPriceCtrl, keyboardType: TextInputType.number),
              _buildTextField("Giá bán", _priceCtrl, keyboardType: TextInputType.number),
              _buildTextField("Tồn kho", _quantityCtrl, keyboardType: TextInputType.number),

              const Divider(height: 32),
              _buildTextField("Thêm mô tả", _descriptionCtrl),
              _buildTextField("Thêm đơn vị tính", _unitCtrl),
              _buildTextField("Thêm định mức tồn kho", _minStockCtrl, keyboardType: TextInputType.number),
              _buildTextField("Thêm thông tin khác", _otherInfoCtrl),
              const Divider(height: 32),
              SwitchListTile(title: const Text("Bán trực tiếp"), value: _isDirectSale, onChanged: (v) => setState(() => _isDirectSale = v), activeColor: Colors.blue),
              SwitchListTile(title: const Text("Tích điểm"), value: _isPointAccumulation, onChanged: (v) => setState(() => _isPointAccumulation = v), activeColor: Colors.blue),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldWithScan(String label, TextEditingController ctrl) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.blue), onPressed: () => _scanBarcode(ctrl)))));
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            // ĐÃ SỬA: Chèn bộ lọc format tiền tệ nếu là ô nhập số
            inputFormatters: keyboardType == TextInputType.number ? [CurrencyInputFormatter()] : [],
            decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())
        )
    );
  }

  Widget _buildSelectField(String label, String value, List<String> items, Function(String) onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => onChanged(v!)));
  }
}

// === BỘ ĐỊNH DẠNG SỐ THÔNG MINH ===
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Xóa mọi ký tự không phải là số (bao gồm cả dấu chấm cũ)
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    // Chuyển thành số nguyên (tự động xóa số 0 ở đầu) và format có dấu chấm
    final int value = int.parse(digitsOnly);
    final String formatted = NumberFormat.decimalPattern('vi_VN').format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length), // Giữ con trỏ ở cuối
    );
  }
}