// File: lib/screens/sales_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
// ignore: deprecated_member_use
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'order_management_screen.dart';
import 'return_screen.dart';
import 'add_customer_page.dart';
import 'add_product_page.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> _products = [];
  final Map<String, OrderItem> _cart = {};
  Customer? _selectedCustomer;
  bool _isSalesMode = true;
  int _draftCount = 0;
  int _pendingCount = 0;

  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamProducts().listen((data) {
      if (mounted) setState(() => _products = data);
    });

    _firestoreService.countOrdersByStatus('draft').listen((count) {
      if (mounted) setState(() => _draftCount = count);
    });

    _firestoreService.countOrdersByStatus('pending').listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });
  }

  void _addToCart(Product p, {int qty = 1}) {
    if (_isSalesMode && p.quantity < ((_cart[p.id]?.quantity ?? 0) + qty)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không đủ hàng trong kho!"), duration: Duration(milliseconds: 500)));
      return;
    }
    setState(() {
      if (_cart.containsKey(p.id)) {
        _cart[p.id]!.quantity += qty;
      } else {
        _cart[p.id] = OrderItem(productId: p.id, productName: p.name, price: p.price, importPrice: p.importPrice, quantity: qty);
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!.quantity > 1) {
          _cart[productId]!.quantity -= 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  double get _totalPrice {
    double t = 0;
    _cart.forEach((id, item) => t += item.totalAmount);
    return t;
  }

  int get _totalQuantity {
    int q = 0;
    _cart.forEach((k, item) => q += item.quantity);
    return q;
  }

  Future<void> _processOrder({required String status}) async {
    if (_cart.isEmpty) return;
    List<OrderItem> items = _cart.values.toList();

    OrderModel newOrder = OrderModel(
      id: "HD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
      date: DateTime.now(),
      totalPrice: _totalPrice,
      customerName: _selectedCustomer?.name ?? 'Khách lẻ',
      customerPhone: _selectedCustomer?.phone ?? '',
      items: items,
      status: status,
    );

    try {
      await _firestoreService.saveOrder(newOrder);

      if (mounted) {
        setState(() { _cart.clear(); _selectedCustomer = null; });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thành công!"), backgroundColor: Colors.green)
        );
      }
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

  void _openOrderList(String status, String title) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OrderManagementScreen(statusFilter: status, title: title)));
    if (result is OrderModel && mounted) {
      setState(() {
        _cart.clear();
        _selectedCustomer = Customer(id: "temp", name: result.customerName, phone: result.customerPhone);
        for (var item in result.items) {
          _cart[item.productId] = item;
        }
      });
      await _firestoreService.deleteOrder(result.id);
    }
  }

  Future<void> _scanToSell() async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      try {
        final product = _products.firstWhere((p) => p.barcode == res);
        _addToCart(product);
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Không tìm thấy hàng"),
              content: Text("Mã vạch: $res\nBạn có muốn thêm sản phẩm mới này không?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final newP = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddProductPage(initialBarcode: res)));
                    if (newP is Product) {
                      _addToCart(newP);
                    }
                  },
                  child: const Text("Thêm"),
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
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchTrigger(),
            Expanded(child: _buildCartList()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        children: [
          Container(
            height: 40, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25)),
            child: Row(
              children: [
                _buildToggleBtn("Bán hàng", _isSalesMode, () => setState(() => _isSalesMode = true)),
                _buildToggleBtn("Đặt hàng", !_isSalesMode, () => setState(() => _isSalesMode = false)),
              ],
            ),
          ),

          const Spacer(), // Tự động đẩy 3 nút icon về bên phải

          // 3 Nút chức năng đã được căn chỉnh khoảng cách hợp lý
          _buildActionIcon(Icons.save_as, Colors.orange, "Đơn lưu tạm", () => _openOrderList('draft', 'Đơn Lưu Tạm'), count: _draftCount),
          const SizedBox(width: 8),
          _buildActionIcon(Icons.assignment, Colors.blue, "Đơn đặt hàng", () => _openOrderList('pending', 'Đơn Đặt Hàng'), count: _pendingCount),
          const SizedBox(width: 8),
          _buildActionIcon(Icons.keyboard_return, Colors.red, "Trả hàng", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey[600], fontSize: 13)),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, String tooltip, VoidCallback onTap, {int count = 0}) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  "$count",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchTrigger() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), color: Colors.white,
      child: Row(children: [
        InkWell(
          onTap: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
            if (res is Product) {
              _addToCart(res);
            }
          },
          child: Container(height: 45, width: 45, decoration: BoxDecoration(color: Colors.blue[600], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add, color: Colors.white)),
        ),
        const SizedBox(width: 12),
        Expanded(child: InkWell(
          onTap: () async {
            final Product? selected = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductSearchPage(products: _products)));
            if (selected != null) { _addToCart(selected); }
          },
          child: Container(
              height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [Icon(Icons.search, color: Colors.grey), SizedBox(width: 10), Text("Tìm hàng hóa...", style: TextStyle(color: Colors.grey))])
          ),
        )),
        const SizedBox(width: 8),
        InkWell(onTap: _scanToSell, child: Container(height: 45, width: 45, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, color: Colors.black87))),
      ]),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.black12), Text("Chưa có sản phẩm")]));
    return ListView.builder(itemCount: _cart.length, itemBuilder: (ctx, i) {
      String id = _cart.keys.elementAt(i);
      OrderItem item = _cart.values.elementAt(i);
      Product? p = _products.firstWhere((e) => e.id == id, orElse: () => Product(id: "", name: "Lỗi", price: 0, quantity: 0));

      return ListTile(
        leading: p.imagePath.isNotEmpty && File(p.imagePath).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p.imagePath), width: 50, height: 50, fit: BoxFit.cover)) : Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image)),
        title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(currencyFormat.format(item.sellingPrice)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeFromCart(id)),
          InkWell(
            onTap: () => _showEditItemDialog(item, p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
              child: Text("${item.quantity}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _addToCart(p)),
        ]),
        onTap: () => _showEditItemDialog(item, p),
      );
    });
  }

  void _showEditItemDialog(OrderItem item, Product p) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => ItemEditSheet(
          item: item,
          product: p,
          onUpdate: (updatedItem) {
            setState(() { _cart[item.productId] = updatedItem; });
          },
        )
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerSearchPage()));
                if (result is Customer) setState(() => _selectedCustomer = result);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text(_selectedCustomer?.name ?? "Khách lẻ", style: const TextStyle(fontWeight: FontWeight.bold))),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedCustomer != null)
            IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => setState(() => _selectedCustomer = null)),
        ]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text("Tổng tiền", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_basket_outlined, color: Colors.blue, size: 28),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text("$_totalQuantity", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
              ],
            ),
          ]),
          Text(currencyFormat.format(_totalPrice), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
        const SizedBox(height: 12),

        // Cụm nút "LƯU TẠM" và "THANH TOÁN" được căn tỷ lệ 4:6, chống tràn chữ
        Row(children: [
          Expanded(
              flex: 4,
              child: ElevatedButton(
                  onPressed: _cart.isNotEmpty ? () => _processOrder(status: 'draft') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4), // Giảm padding 2 bên
                  ),
                  child: const FittedBox( // Ép chữ vừa khít 1 dòng
                    fit: BoxFit.scaleDown,
                    child: Text("LƯU TẠM", maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold)),
                  )
              )
          ),
          const SizedBox(width: 8),
          Expanded(
              flex: 6,
              child: ElevatedButton(
                  onPressed: _cart.isNotEmpty ? () => _processOrder(status: _isSalesMode ? 'completed' : 'pending') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSalesMode ? Colors.blue[700] : Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_isSalesMode ? "THANH TOÁN" : "ĐẶT HÀNG", maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                  )
              )
          ),
        ]),
      ]),
    );
  }
}

class ItemEditSheet extends StatefulWidget {
  final OrderItem item;
  final Product product;
  final Function(OrderItem) onUpdate;
  const ItemEditSheet({super.key, required this.item, required this.product, required this.onUpdate});

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<ItemEditSheet> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _noteCtrl;
  late bool _isPercent;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _priceCtrl = TextEditingController(text: widget.item.price.toInt().toString());
    _discountCtrl = TextEditingController(text: widget.item.discount.toInt().toString());
    _noteCtrl = TextEditingController(text: widget.item.note);
    _isPercent = widget.item.isDiscountPercentage;
  }

  double get _sellingPrice {
    double p = double.tryParse(_priceCtrl.text) ?? 0;
    double d = double.tryParse(_discountCtrl.text) ?? 0;
    if (_isPercent) return p * (1 - d / 100);
    return p - d;
  }

  @override
  Widget build(BuildContext context) {
    double sellingPrice = _sellingPrice;
    int qty = int.tryParse(_qtyCtrl.text) ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            widget.product.imagePath.isNotEmpty && File(widget.product.imagePath).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(widget.product.imagePath), width: 60, height: 60, fit: BoxFit.cover)) : Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Mã: ${widget.product.barcode} | Kho: ${widget.product.quantity}", style: const TextStyle(color: Colors.grey)),
              Text("Giá: ${currencyFormat.format(widget.product.price)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ]),
          const Divider(height: 32),
          _buildRow("Số lượng", Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
              int v = int.tryParse(_qtyCtrl.text) ?? 1;
              if (v > 1) {
                _qtyCtrl.text = (v - 1).toString();
                setState(() {});
              }
            }),
            SizedBox(width: 80, child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (_) => setState((){}), decoration: const InputDecoration(border: OutlineInputBorder()))),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
              int v = int.tryParse(_qtyCtrl.text) ?? 0;
              _qtyCtrl.text = (v + 1).toString();
              setState(() {});
            }),
          ])),
          _buildRow("Đơn giá", SizedBox(width: 150, child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right, onChanged: (_) => setState((){}), decoration: const InputDecoration(suffixText: "đ")))),
          _buildRow("Giảm giá", Row(children: [
            ToggleButtons(
              isSelected: [_isPercent, !_isPercent],
              onPressed: (i) {
                setState(() => _isPercent = i == 0);
              },
              constraints: const BoxConstraints(minWidth: 40, minHeight: 35),
              children: const [Text("%"), Text("đ")],
            ),
            const SizedBox(width: 12),
            SizedBox(width: 100, child: TextField(controller: _discountCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right, onChanged: (_) => setState((){}))),
          ])),
          _buildRow("Thành tiền", Text(currencyFormat.format(sellingPrice * qty), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 20))),
          const SizedBox(height: 12),
          TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: "Ghi chú", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () {
            widget.onUpdate(OrderItem(
                productId: widget.item.productId,
                productName: widget.item.productName,
                price: double.tryParse(_priceCtrl.text) ?? 0,
                importPrice: widget.item.importPrice,
                quantity: int.tryParse(_qtyCtrl.text) ?? 1,
                discount: double.tryParse(_discountCtrl.text) ?? 0,
                isDiscountPercentage: _isPercent,
                note: _noteCtrl.text
            ));
            Navigator.pop(context);
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("XÁC NHẬN"))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildRow(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 16)), child]),
    );
  }
}

class ProductSearchPage extends StatefulWidget {
  final List<Product> products;
  const ProductSearchPage({super.key, required this.products});
  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  late List<Product> _allProducts;
  List<Product> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tất cả";
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _allProducts = widget.products;
    _filtered = _allProducts;
  }

  void _runFilter() {
    String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allProducts.where((p) {
        bool matchSearch = p.name.toLowerCase().contains(query) || p.barcode.contains(query) || p.id.toLowerCase().contains(query);
        bool matchCat = _selectedCategory == "Tất cả" || p.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  void _showCategoryFilter() {
    Set<String> categories = {"Tất cả", ..._allProducts.map((e) => e.category)};
    showModalBottomSheet(
        context: context,
        builder: (ctx) => ListView(
          children: categories.map((c) => ListTile(
            title: Text(c),
            trailing: _selectedCategory == c ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              setState(() { _selectedCategory = c; });
              _runFilter();
              Navigator.pop(ctx);
            },
          )).toList(),
        )
    );
  }

  Future<void> _scanBarcode() async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      _searchCtrl.text = res;
      _runFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white, elevation: 0.5, titleSpacing: 0,
        title: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchCtrl, autofocus: true, onChanged: (_) => _runFilter(), decoration: const InputDecoration(hintText: "Tìm sản phẩm...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8))))),
          IconButton(icon: const Icon(Icons.add, color: Colors.blue), onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
            if (res is Product) Navigator.pop(context, res);
          }),
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.blue), onPressed: _showCategoryFilter),
          IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.blue), onPressed: _scanBarcode),
        ]),
      ),
      body: _filtered.isEmpty ? const Center(child: Text("Không có sản phẩm nào")) : ListView.builder(itemCount: _filtered.length, itemBuilder: (ctx, i) {
        final p = _filtered[i];
        return ListTile(
          leading: p.imagePath.isNotEmpty && File(p.imagePath).existsSync() ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(p.imagePath), width: 50, height: 50, fit: BoxFit.cover)) : Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.image)),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Mã: ${p.barcode} | Kho: ${p.quantity}"),
          trailing: Text(currencyFormat.format(p.price), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
          onTap: () => Navigator.pop(context, p),
        );
      }),
    );
  }
}

class CustomerSearchPage extends StatefulWidget {
  const CustomerSearchPage({super.key});
  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Customer> _all = [];
  List<Customer> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenCustomers();
  }

  void _listenCustomers() {
    _firestoreService.streamCustomers().listen((data) {
      if (mounted) {
        setState(() {
          _all = data;
          _runFilter(_searchCtrl.text);
        });
      }
    });
  }

  void _runFilter(String v) {
    setState(() => _filtered = _all.where((c) => c.name.toLowerCase().contains(v.toLowerCase()) || c.phone.contains(v)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, backgroundColor: Colors.white, elevation: 0.5, titleSpacing: 0,
        title: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchCtrl, autofocus: true, onChanged: _runFilter, decoration: const InputDecoration(hintText: "Tìm tên hoặc SĐT...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8))))),
          IconButton(icon: const Icon(Icons.person_add, color: Colors.blue), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCustomerPage()));
          }),
        ]),
      ),
      body: Column(
        children: [
          ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: const Text("Khách lẻ (Mặc định)"), onTap: () => Navigator.pop(context, null)),
          const Divider(height: 1),
          Expanded(child: ListView.builder(itemCount: _filtered.length, itemBuilder: (ctx, i) {
            final c = _filtered[i];
            return ListTile(
              leading: CircleAvatar(backgroundImage: (c.imagePath.isNotEmpty && File(c.imagePath).existsSync()) ? FileImage(File(c.imagePath)) : null, child: (c.imagePath.isEmpty || !File(c.imagePath).existsSync()) ? Text(c.name[0].toUpperCase()) : null),
              title: Text(c.name), subtitle: Text(c.phone), onTap: () => Navigator.pop(context, c),
            );
          })),
        ],
      ),
    );
  }
}