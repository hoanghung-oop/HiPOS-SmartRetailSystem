// File: lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart'; // 1. Đổi sang import FirestoreService

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService(); // 2. Khởi tạo service
  List<OrderModel> _orders = [];
  List<OrderModel> _filteredOrders = [];
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenOrders(); // 3. Dùng hàm lắng nghe thời gian thực
  }

  void _listenOrders() {
    // Chỉ lấy những hóa đơn đã hoàn thành ('completed') để hiển thị ở Lịch sử
    _firestoreService.streamOrders('completed').listen((data) {
      if (mounted) {
        setState(() {
          // Sắp xếp hóa đơn mới nhất lên đầu
          data.sort((a, b) => b.date.compareTo(a.date));
          _orders = data;
          _filteredOrders = data;
        });
      }
    });
  }

  Map<String, List<OrderModel>> _groupOrdersByDate() {
    Map<String, List<OrderModel>> grouped = {};
    for (var order in _filteredOrders) {
      String dateKey = _getDateLabel(order.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(order);
    }
    return grouped;
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "HÔM NAY ${DateFormat('dd/MM/yyyy').format(date)}";
    if (checkDate == yesterday) return "HÔM QUA ${DateFormat('dd/MM/yyyy').format(date)}";
    return "THỨ ${date.weekday + 1 == 8 ? 'CN' : '${date.weekday + 1}'}, ${DateFormat('dd/MM/yyyy').format(date)}";
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupOrdersByDate();
    double totalRevenue = 0;
    for (var o in _filteredOrders) totalRevenue += o.totalPrice;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hóa đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              // Vì dùng Stream nên không cần gọi lại _loadOrders sau khi pop nữa
              await Navigator.push(context, MaterialPageRoute(builder: (context) => OrderSearchPage(allOrders: _orders)));
            },
          ),
          IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Tổng tiền hàng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text("${_filteredOrders.length} hóa đơn", style: const TextStyle(color: Colors.grey)),
              ]),
              Text(currencyFormat.format(totalRevenue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: groupedOrders.keys.length,
              itemBuilder: (context, index) {
                String dateKey = groupedOrders.keys.elementAt(index);
                List<OrderModel> ordersInDate = groupedOrders[dateKey]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(dateKey, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
                    ...ordersInDate.map((order) => _buildOrderTile(order)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTile(OrderModel order) {
    String itemsText = order.items.isEmpty ? "Không có hàng" : "${order.items[0].productName} x${order.items[0].quantity}${order.items.length > 1 ? ' (+${order.items.length - 1} món khác)' : ''}";
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order))),
      child: Container(
        padding: const EdgeInsets.all(16), color: Colors.white, margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text("${DateFormat('HH:mm').format(order.date)} • HD${order.id.substring(order.id.length - 6)}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(itemsText, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(currencyFormat.format(order.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const Text("Tiền mặt", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

// --- MÀN HÌNH CHI TIẾT HÓA ĐƠN ---
class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
    return Scaffold(
      appBar: AppBar(title: Text("Chi tiết HD${order.id.substring(order.id.length - 6)}")),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(children: [
              _buildInfoRow("Khách hàng", order.customerName, isBold: true),
              _buildInfoRow("Thời gian", DateFormat('dd/MM/yyyy HH:mm').format(order.date)),
              _buildInfoRow("Trạng thái", order.status == 'completed' ? "Hoàn thành" : "Đã hủy", color: order.status == 'completed' ? Colors.green : Colors.red),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            child: Column(children: [
              const Padding(padding: EdgeInsets.all(16), child: Row(children: [Text("Sản phẩm", style: TextStyle(fontWeight: FontWeight.bold))])),
              const Divider(height: 1),
              ...order.items.map((item) => ListTile(
                title: Text(item.productName),
                subtitle: Text("${item.quantity} x ${fmt.format(item.price)}"),
                trailing: Text(fmt.format(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(children: [
              _buildInfoRow("Tổng tiền hàng", fmt.format(order.totalPrice)),
              _buildInfoRow("Giảm giá", "0đ"),
              const Divider(),
              _buildInfoRow("KHÁCH PHẢI TRẢ", fmt.format(order.totalPrice), isBold: true, color: Colors.blue),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color))]),
    );
  }
}

// --- TRANG TÌM KIẾM HÓA ĐƠN ---
class OrderSearchPage extends StatefulWidget {
  final List<OrderModel> allOrders;
  const OrderSearchPage({super.key, required this.allOrders});

  @override
  State<OrderSearchPage> createState() => _OrderSearchPageState();
}

class _OrderSearchPageState extends State<OrderSearchPage> {
  String _searchType = "Hóa đơn"; // "Hàng hóa", "Khách hàng", "Đặt hàng", "Vận đơn"
  final TextEditingController _ctrl = TextEditingController();
  List<OrderModel> _results = [];

  void _onSearch(String v) {
    if (v.isEmpty) { setState(() => _results = []); return; }
    setState(() {
      _results = widget.allOrders.where((o) {
        String query = v.toLowerCase();
        switch (_searchType) {
          case "Hóa đơn": return o.id.toLowerCase().contains(query);
          case "Khách hàng": return o.customerName.toLowerCase().contains(query) || (o.customerPhone ?? "").contains(query);
          case "Hàng hóa": return o.items.any((item) => item.productName.toLowerCase().contains(query));
          case "Đặt hàng": return o.status == 'pending' && (o.customerName.toLowerCase().contains(query) || o.id.toLowerCase().contains(query));
          default: return false;
        }
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl, autofocus: true, onChanged: _onSearch,
          decoration: const InputDecoration(hintText: "Tìm kiếm...", border: InputBorder.none),
        ),
      ),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: ["Hóa đơn", "Hàng hóa", "Khách hàng", "Đặt hàng", "Vận đơn"].map((type) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              showCheckmark: false,

              backgroundColor: Colors.grey[200], // Màu nền khi chưa chọn (như nút "Ghi chú")
              selectedColor: Colors.blue,        // Màu nền khi được chọn (như nút "Hàng hóa")

              shape: const StadiumBorder(side: BorderSide.none),

              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              label: Text(
                type,
                style: TextStyle(
                  color: _searchType == type ? Colors.white : Colors.black87,
                  fontWeight: _searchType == type ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ), selected: _searchType == type,
              onSelected: (s) => setState(() { _searchType = type; _onSearch(_ctrl.text); }),
            ),
          )).toList()),
        ),
        const Divider(height: 1),
        Expanded(child: ListView.builder(
          itemCount: _results.length,
          itemBuilder: (ctx, i) {
            final order = _results[i];
            return ListTile(
              title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${DateFormat('dd/MM/yyyy HH:mm').format(order.date)} • HD${order.id.substring(order.id.length - 6)}"),
              trailing: Text(NumberFormat.decimalPattern('vi_VN').format(order.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order))),
            );
          },
        )),
      ]),
    );
  }
}