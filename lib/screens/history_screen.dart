// File: lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<OrderModel> _orders = [];
  List<OrderModel> _filteredOrders = [];
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenOrders();
  }

  void _listenOrders() {
    _firestoreService.streamOrders('completed').listen((data) {
      if (mounted) {
        setState(() {
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

  Color _getPaymentMethodColor(String method) {
    switch (method) {
      case 'Chuyển khoản QR': return Colors.blue[700]!;
      case 'Thẻ': return Colors.teal[700]!;
      case 'Ví': return Colors.purple[700]!;
      case 'Đa phương thức': return Colors.orange[800]!;
      case 'Tiền mặt':
      default:
        return Colors.green[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupedOrders = _groupOrdersByDate();
    double totalRevenue = 0;
    for (var o in _filteredOrders) {
      if (o.status != 'Đã trả' && o.status != 'returned') {
        totalRevenue += o.totalPrice;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Hóa đơn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
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
                const Text("Tổng doanh thu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    bool isReturned = order.status == 'Đã trả' || order.status == 'returned';
    String itemsText = order.items.isEmpty ? "Không có hàng" : "${order.items[0].productName} x${order.items[0].quantity}${order.items.length > 1 ? ' (+${order.items.length - 1} món khác)' : ''}";

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order))),
      child: Container(
        padding: const EdgeInsets.all(16), color: Colors.white, margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (isReturned) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.red)),
                    child: const Text("ĐÃ TRẢ", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ]
              ],
            ),
            const SizedBox(height: 2),
            Text("${DateFormat('HH:mm').format(order.date)} • HD${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(itemsText, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              currencyFormat.format(order.totalPrice),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isReturned ? Colors.grey : Colors.blue,
                decoration: isReturned ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getPaymentMethodColor(order.paymentMethod).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                order.paymentMethod,
                style: TextStyle(color: _getPaymentMethodColor(order.paymentMethod), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
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
    bool isReturned = order.status == 'Đã trả' || order.status == 'returned';

    // Tổng tiền hàng là tổng thành tiền của các món (đã trừ giảm giá từng món nếu có)
    double totalItemsAmount = order.items.fold(0, (sum, item) => sum + item.totalAmount);

    return Scaffold(
      appBar: AppBar(title: Text("Chi tiết HD${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}")),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(children: [
              _buildInfoRow("Khách hàng", order.customerName, isBold: true),
              _buildInfoRow("Thời gian", DateFormat('dd/MM/yyyy HH:mm').format(order.date)),
              _buildInfoRow(
                "Trạng thái",
                isReturned ? "Đã trả hàng" : (order.status == 'completed' ? "Hoàn thành" : "Đã hủy"),
                color: isReturned ? Colors.red : (order.status == 'completed' ? Colors.green : Colors.grey),
                isBold: true,
              ),
              const Divider(height: 16),
              _buildInfoRow("Phương thức thanh toán", order.paymentMethod, isBold: true),
              if (order.paymentMethod == 'Đa phương thức') ...[
                _buildInfoRow(" - Tiền mặt:", fmt.format(order.multiPaymentDetails['cashAmount'] ?? 0)),
                _buildInfoRow(" - Chuyển khoản (${order.multiPaymentDetails['bankName'] ?? ''}):", fmt.format(order.multiPaymentDetails['qrAmount'] ?? 0)),
              ],
            ]),
          ),
          const SizedBox(height: 10),

          // DANH SÁCH SẢN PHẨM HIỂN THỊ CÁCH A
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(padding: EdgeInsets.all(16), child: Text("Danh sách sản phẩm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                const Divider(height: 1),
                ...order.items.map((item) {
                  double itemDiscountAmount = 0;
                  if (item.discount > 0) {
                    itemDiscountAmount = item.isDiscountPercentage
                        ? (item.price * (item.discount / 100)) * item.quantity
                        : item.discount * item.quantity;
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                                Text("x${item.quantity}", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                                const SizedBox(width: 16),
                                Text(fmt.format(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              ],
                            ),
                            if (item.discount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  " (Giảm ${item.isDiscountPercentage ? '${item.discount.toInt()}%' : fmt.format(item.discount)}/món: -${fmt.format(itemDiscountAmount)})",
                                  style: const TextStyle(color: Colors.red, fontSize: 12, fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // TỔNG KẾT HÓA ĐƠN (ĐÃ BỎ DÒNG GIẢM GIÁ TỪNG MÓN)
          Container(
            padding: const EdgeInsets.all(16), color: Colors.white,
            child: Column(children: [
              _buildInfoRow("Tổng tiền hàng", fmt.format(totalItemsAmount)),
              if (order.totalDiscount > 0)
                _buildInfoRow("Giảm giá đơn hàng", "-${fmt.format(order.totalDiscount)}", color: Colors.red),
              if (order.otherFees > 0)
                _buildInfoRow("Thu khác", "+${fmt.format(order.otherFees)}", color: Colors.black87),
              if (order.pointsUsed > 0)
                _buildInfoRow("Quy đổi điểm", "-${fmt.format(order.pointsUsed * 1000)}", color: Colors.green),
              const Divider(height: 20),
              _buildInfoRow("KHÁCH PHẢI TRẢ", fmt.format(order.totalPrice), isBold: true, color: Colors.blue),
            ]),
          ),
          const SizedBox(height: 20),
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
  String _searchType = "Hóa đơn";
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
              backgroundColor: Colors.grey[200],
              selectedColor: Colors.blue,
              shape: const StadiumBorder(side: BorderSide.none),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              label: Text(
                type,
                style: TextStyle(
                  color: _searchType == type ? Colors.white : Colors.black87,
                  fontWeight: _searchType == type ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
              selected: _searchType == type,
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
              subtitle: Text("${DateFormat('dd/MM/yyyy HH:mm').format(order.date)} • HD${order.id.length >= 6 ? order.id.substring(order.id.length - 6) : order.id}"),
              trailing: Text(NumberFormat.decimalPattern('vi_VN').format(order.totalPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderDetailScreen(order: order))),
            );
          },
        )),
      ]),
    );
  }
}