// File: lib/screens/return_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// ignore: deprecated_member_use
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import để dùng FieldValue.increment
import '../services/firestore_service.dart'; // Đổi sang dùng FirestoreService
import '../models/order_model.dart';
import '../models/transaction_model.dart';

class ReturnScreen extends StatefulWidget {
  const ReturnScreen({super.key});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenOrders(); // Lắng nghe dữ liệu realtime thay vì load 1 lần
  }

  void _listenOrders() {
    // Lấy đơn completed, sắp xếp mới nhất lên đầu
    _firestoreService.streamOrders('completed').listen((orders) {
      if (mounted) {
        orders.sort((a, b) => b.date.compareTo(a.date));
        setState(() {
          _allOrders = orders;
          _filterOrders(_searchController.text); // Áp dụng lại bộ lọc hiện tại
        });
      }
    });
  }

  void _filterOrders(String query) {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        final matchesSearch = order.id.toLowerCase().contains(query.toLowerCase()) ||
            order.customerName.toLowerCase().contains(query.toLowerCase());
        bool matchesDate = true;
        if (_selectedDateRange != null) {
          matchesDate = order.date.isAfter(_selectedDateRange!.start) &&
              order.date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
        }
        return matchesSearch && matchesDate;
      }).toList();
    });
  }

  // TỐI ƯU: Quét sản phẩm để tìm ngay hóa đơn chứa sản phẩm đó (Dùng hàm của FirestoreService)
  Future<void> _scanProductToFindInvoice() async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      try {
        final p = await _firestoreService.getProductByBarcode(res);
        if (p != null) {
          setState(() {
            _filteredOrders = _allOrders.where((o) => o.items.any((item) => item.productId == p.id)).toList();
          });
          if (_filteredOrders.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không có hóa đơn nào chứa sản phẩm này")));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sản phẩm không tồn tại")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Có lỗi xảy ra khi tìm sản phẩm")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Chọn hóa đơn trả hàng"),
        actions: [
          IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: _scanProductToFindInvoice, tooltip: "Tìm đơn qua sản phẩm"),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _filteredOrders.isEmpty
                ? const Center(child: Text("Không tìm thấy hóa đơn phù hợp"))
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _filteredOrders.length,
              itemBuilder: (context, index) {
                final order = _filteredOrders[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.id, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                        Text(currencyFormat.format(order.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ],
                    ),
                    subtitle: Text("${order.customerName}\n${DateFormat('dd/MM/yyyy HH:mm').format(order.date)}"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ReturnDetailScreen(order: order)),
                      );
                      // Không cần _loadOrders() nữa vì Stream tự động cập nhật
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: "Tìm mã HD, SĐT...",
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _filterOrders(''); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.grey[50],
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: _filterOrders,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
              if (picked != null) {
                setState(() => _selectedDateRange = picked);
                _filterOrders(_searchController.text);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(_selectedDateRange == null
                    ? "Lọc theo ngày"
                    : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                if (_selectedDateRange != null)
                  IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () { setState(() => _selectedDateRange = null); _filterOrders(_searchController.text); }),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- MÀN HÌNH CHI TIẾT TRẢ HÀNG (TRẢ LẺ HOẶC TRẢ HẾT) ---
class ReturnDetailScreen extends StatefulWidget {
  final OrderModel order;
  const ReturnDetailScreen({super.key, required this.order});

  @override
  State<ReturnDetailScreen> createState() => _ReturnDetailScreenState();
}

class _ReturnDetailScreenState extends State<ReturnDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, int> _returnQty = {};
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    for (var item in widget.order.items) {
      _returnQty[item.productId] = 0;
    }
  }

  double get _totalRefund {
    double total = 0;
    for (var item in widget.order.items) {
      total += item.price * (_returnQty[item.productId] ?? 0);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chọn hàng trả"),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                for (var item in widget.order.items) { _returnQty[item.productId] = item.quantity; }
              });
            },
            child: const Text("Trả hết", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: widget.order.items.length,
        itemBuilder: (ctx, i) {
          final item = widget.order.items[i];
          int qty = _returnQty[item.productId] ?? 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text("Giá bán: ${currencyFormat.format(item.price)} | Đã mua: ${item.quantity}"),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Số lượng trả:", style: TextStyle(fontWeight: FontWeight.w500)),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: qty > 0 ? () => setState(() => _returnQty[item.productId] = qty - 1) : null),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                            child: Text("$qty", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: qty < item.quantity ? () => setState(() => _returnQty[item.productId] = qty + 1) : null),
                        ],
                      )
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TỔNG TIỀN HOÀN:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(currencyFormat.format(_totalRefund), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _totalRefund > 0 ? _confirmReturn : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("XÁC NHẬN TRẢ HÀNG", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  bool _isProcessing = false;

  void _confirmReturn() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // GỌI HÀM BATCH TỪ FIRESTORE SERVICE (Đã bao gồm Trừ Kho, Sổ Quỹ, Thu hồi điểm)
      await _firestoreService.processReturn(
        originalOrder: widget.order,
        returnQty: _returnQty,
        totalRefund: _totalRefund,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Trả hàng & Hoàn tiền thành công!"), backgroundColor: Colors.green)
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lỗi khi xử lý trả hàng!"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
