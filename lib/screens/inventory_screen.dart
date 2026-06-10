// File: lib/screens/inventory_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
// ignore: deprecated_member_use
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import 'add_product_page.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _showSellPrice = true;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamProducts().listen((data) {
      if (mounted) {
        setState(() {
          _products = data;
          _filteredProducts = data;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Hàng hóa", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => InventorySearchPage(products: _products)));
            },
          ),
          IconButton(icon: const Icon(Icons.sort), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildQuickFilter(),
          _buildSummary(),
          Expanded(child: _buildProductList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
        },
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildQuickFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.white,
      child: Row(children: [
        const Icon(Icons.filter_list, color: Colors.grey, size: 20),
        const SizedBox(width: 10),
        _buildChip("Hàng hóa thường"),
        const SizedBox(width: 10),
        GestureDetector(onTap: () => setState(() => _showSellPrice = !_showSellPrice), child: _buildChip(_showSellPrice ? "Giá bán" : "Giá vốn")),
      ]),
    );
  }

  Widget _buildChip(String text) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)), child: Row(children: [Text(text, style: const TextStyle(fontSize: 13)), const Icon(Icons.arrow_drop_down, size: 18)]));
  }

  Widget _buildSummary() {
    double totalValue = 0;
    for (var p in _filteredProducts) totalValue += (p.quantity * (_showSellPrice ? p.price : p.importPrice));
    return Container(
      padding: const EdgeInsets.all(16), color: Colors.grey[100],
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("Tổng tồn (${_filteredProducts.length} mặt hàng)", style: const TextStyle(fontWeight: FontWeight.w500)),
        Text(currencyFormat.format(totalValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ]),
    );
  }

  Widget _buildProductList() {
    if (_filteredProducts.isEmpty) return const Center(child: Text("Chưa có hàng hóa nào"));
    return ListView.separated(
      itemCount: _filteredProducts.length,
      separatorBuilder: (ctx, i) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final p = _filteredProducts[i];
        return ListTile(
          leading: p.imagePath.isNotEmpty && File(p.imagePath).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p.imagePath), width: 50, height: 50, fit: BoxFit.cover)) : Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image)),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Mã: ${p.barcode} | Tồn: ${p.quantity}"),
          trailing: Text(currencyFormat.format(_showSellPrice ? p.price : p.importPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: p)));
          },
        );
      },
    );
  }
}

// --- TRANG CHI TIẾT SẢN PHẨM ---
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Product _currentP;
  final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _currentP = widget.product;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(_currentP.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'print', child: Row(children: [Icon(Icons.print, size: 20), SizedBox(width: 10), Text("In tem mã")])),
              const PopupMenuItem(value: 'stop', child: Row(children: [Icon(Icons.block, size: 20), SizedBox(width: 10), Text("Ngừng kinh doanh")])),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 10), Text("Xóa", style: TextStyle(color: Colors.red))])),
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            width: double.infinity, height: 250, color: Colors.white,
            child: _currentP.imagePath.isNotEmpty && File(_currentP.imagePath).existsSync() ? Image.file(File(_currentP.imagePath), fit: BoxFit.contain) : const Icon(Icons.image, size: 100, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), color: Colors.white,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Thông tin cơ bản", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(onPressed: _editProduct, child: const Text("Sửa", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
          ),
          const Divider(height: 1),
          _buildDetailRow("Mã hàng", _currentP.id),
          _buildDetailRow("Mã vạch", _currentP.barcode),
          _buildDetailRow("Nhóm hàng", _currentP.category),
          _buildDetailRow("Thương hiệu", _currentP.brand),
          _buildDetailRow("Giá vốn", fmt.format(_currentP.importPrice), color: Colors.red),
          _buildDetailRow("Giá bán", fmt.format(_currentP.price), color: Colors.blue),
          _buildDetailRow("Tồn kho", _currentP.quantity.toString(), color: Colors.green),
          _buildDetailRow("Đơn vị", _currentP.unit),
          _buildDetailRow("Bán trực tiếp", _currentP.isDirectSale ? "Có" : "Không"),
          _buildDetailRow("Tích điểm", _currentP.isPointAccumulation ? "Có" : "Không"),
          const SizedBox(height: 10),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Mô tả", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_currentP.description.isEmpty ? "Không có mô tả" : _currentP.description, style: const TextStyle(color: Colors.black87)),
            ]),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), color: Colors.white,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }

  void _editProduct() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProductPage(product: _currentP)));
    if (res is Product && mounted) {
      setState(() { _currentP = res; });
    }
  }

  void _handleMenuAction(String v) {
    if (v == 'delete') _deleteProduct();
  }

  void _deleteProduct() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận"), content: const Text("Xóa sản phẩm này?"),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Xóa", style: TextStyle(color: Colors.red)))]
    ));
    if (confirm == true) {
      await _firestoreService.deleteProduct(_currentP.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

// --- TRANG SỬA SẢN PHẨM ---
class EditProductPage extends StatefulWidget {
  final Product product;
  const EditProductPage({super.key, required this.product});
  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final FirestoreService _firestoreService = FirestoreService();
  late TextEditingController _idCtrl, _barcodeCtrl, _nameCtrl, _importPriceCtrl, _priceCtrl, _quantityCtrl, _descriptionCtrl, _unitCtrl, _minStockCtrl, _otherInfoCtrl;
  late String _category, _brand;
  late bool _isDirectSale, _isPointAccumulation;
  String? _imagePath;

  final List<String> _categories = ["Chưa phân loại", "Đồ uống", "Thực phẩm", "Khác"];
  final List<String> _brands = ["Không có", "Coca Cola", "Pepsi", "Khác"];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _idCtrl = TextEditingController(text: p.id);
    _barcodeCtrl = TextEditingController(text: p.barcode);
    _nameCtrl = TextEditingController(text: p.name);
    _importPriceCtrl = TextEditingController(text: p.importPrice.toInt().toString());
    _priceCtrl = TextEditingController(text: p.price.toInt().toString());
    _quantityCtrl = TextEditingController(text: p.quantity.toString());
    _descriptionCtrl = TextEditingController(text: p.description);
    _unitCtrl = TextEditingController(text: p.unit);
    _minStockCtrl = TextEditingController(text: p.minStock.toString());
    _otherInfoCtrl = TextEditingController(text: p.otherInfo);

    _category = _categories.contains(p.category) ? p.category : _categories[0];
    _brand = _brands.contains(p.brand) ? p.brand : _brands[0];

    _isDirectSale = p.isDirectSale;
    _isPointAccumulation = p.isPointAccumulation;
    _imagePath = p.imagePath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: const Text("Sửa hàng hóa"),
        actions: [TextButton(onPressed: _save, child: const Text("LƯU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          GestureDetector(
              onTap: _pickImage,
              child: Container(
                  height: 120, width: 120,
                  decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      image: (_imagePath != null && _imagePath!.isNotEmpty && File(_imagePath!).existsSync()) ? DecorationImage(image: FileImage(File(_imagePath!)), fit: BoxFit.cover) : null
                  ),
                  child: (_imagePath == null || _imagePath!.isEmpty || !File(_imagePath!).existsSync()) ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey) : null
              )
          ),
          const SizedBox(height: 20),
          _buildField("Mã hàng", _idCtrl, readOnly: true),
          _buildField("Mã vạch", _barcodeCtrl, hasScan: true),
          _buildField("Tên hàng (*)", _nameCtrl),
          _buildSelect("Nhóm hàng", _category, _categories, (v) => setState(() => _category = v!)),
          _buildSelect("Thương hiệu", _brand, _brands, (v) => setState(() => _brand = v!)),
          _buildField("Giá vốn", _importPriceCtrl, keyboardType: TextInputType.number),
          _buildField("Giá bán", _priceCtrl, keyboardType: TextInputType.number),
          _buildField("Tồn kho", _quantityCtrl, keyboardType: TextInputType.number),
          const Divider(height: 32),
          _buildField("Thêm mô tả", _descriptionCtrl),
          _buildField("Thêm đơn vị tính", _unitCtrl),
          _buildField("Thêm định mức tồn kho", _minStockCtrl, keyboardType: TextInputType.number),
          _buildField("Thêm thông tin khác", _otherInfoCtrl),
          const Divider(height: 32),
          SwitchListTile(title: const Text("Bán trực tiếp"), value: _isDirectSale, onChanged: (v) => setState(() => _isDirectSale = v), activeColor: Colors.blue),
          SwitchListTile(title: const Text("Tích điểm"), value: _isPointAccumulation, onChanged: (v) => setState(() => _isPointAccumulation = v), activeColor: Colors.blue),
        ]),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {bool readOnly = false, bool hasScan = false, TextInputType? keyboardType}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, readOnly: readOnly, keyboardType: keyboardType, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: hasScan ? IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.blue), onPressed: () => _scan(ctrl)) : null)));
  }

  Widget _buildSelect(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: value, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await showModalBottomSheet<XFile?>(context: context, builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Chụp ảnh mới"), onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.camera))),
      ListTile(leading: const Icon(Icons.photo_library), title: const Text("Chọn từ thư viện"), onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.gallery))),
    ]));
    if (res != null) setState(() => _imagePath = res.path);
  }

  Future<void> _scan(TextEditingController ctrl) async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') ctrl.text = res;
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) return;
    final updated = Product(
      id: _idCtrl.text, name: _nameCtrl.text,
      price: double.tryParse(_priceCtrl.text) ?? 0,
      importPrice: double.tryParse(_importPriceCtrl.text) ?? 0,
      quantity: int.tryParse(_quantityCtrl.text) ?? 0,
      barcode: _barcodeCtrl.text, imagePath: _imagePath ?? "",
      category: _category, brand: _brand, description: _descriptionCtrl.text,
      unit: _unitCtrl.text, minStock: int.tryParse(_minStockCtrl.text) ?? 0,
      otherInfo: _otherInfoCtrl.text, isDirectSale: _isDirectSale, isPointAccumulation: _isPointAccumulation,
    );

    await _firestoreService.addProduct(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu thay đổi"), backgroundColor: Colors.green));
      Navigator.pop(context, updated);
    }
  }
}

// --- TRANG TÌM KIẾM HÀNG HÓA ---
class InventorySearchPage extends StatefulWidget {
  final List<Product> products;
  const InventorySearchPage({super.key, required this.products});

  @override
  State<InventorySearchPage> createState() => _InventorySearchPageState();
}

class _InventorySearchPageState extends State<InventorySearchPage> {
  List<Product> _results = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _searchByNote = false;

  @override
  void initState() {
    super.initState();
    _results = widget.products;
  }

  void _onSearch(String v) {
    setState(() {
      _results = widget.products.where((p) {
        if (_searchByNote) {
          return p.description.toLowerCase().contains(v.toLowerCase()) || p.otherInfo.toLowerCase().contains(v.toLowerCase());
        }
        return p.name.toLowerCase().contains(v.toLowerCase()) || p.barcode.contains(v) || p.id.toLowerCase().contains(v.toLowerCase());
      }).toList();
    });
  }

  // HÀM QUÉT MÃ TRONG TÌM KIẾM: Mở chi tiết hoặc hỏi thêm mới
  Future<void> _scanBarcode() async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      try {
        final product = widget.products.firstWhere((p) => p.barcode == res);
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: product)));
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Không tìm thấy hàng"),
              content: Text("Mã vạch: $res\nBạn có muốn thêm sản phẩm mới này vào kho không?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final newP = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddProductPage(initialBarcode: res)));
                    if (newP is Product && mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: newP)));
                    }
                  },
                  child: const Text("Thêm mới"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Container(
          height: 40,
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
          child: TextField(
            controller: _ctrl, autofocus: true, onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: "Tìm kiếm...",
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                onPressed: _scanBarcode,
              ),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), color: Colors.white,
            child: Row(children: [
              const Text("Tìm theo:", style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 12),
              _buildSearchTypeChip("Hàng hóa", !_searchByNote),
              const SizedBox(width: 8),
              _buildSearchTypeChip("Ghi chú", _searchByNote),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (ctx, i) {
              final p = _results[i];
              return ListTile(
                leading: p.imagePath.isNotEmpty && File(p.imagePath).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p.imagePath), width: 45, height: 45, fit: BoxFit.cover)) : const Icon(Icons.image),
                title: Text(p.name),
                subtitle: Text("Mã: ${p.barcode} | Tồn: ${p.quantity}"),
                trailing: Text(NumberFormat.decimalPattern('vi_VN').format(p.price), style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(product: p)));
                },
              );
            },
          )),
        ],
      ),
    );
  }

  Widget _buildSearchTypeChip(String label, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _searchByNote = (label == "Ghi chú")),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: active ? Colors.blue : Colors.grey[200], borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black, fontSize: 13, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}