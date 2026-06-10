// File: lib/screens/overview_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart'; // 1. Đổi sang Firestore

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final FirestoreService _firestoreService = FirestoreService(); // 2. Khởi tạo Service
  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];
  List<Product> _products = [];

  double _totalRevenue = 0;
  double _totalProfit = 0;
  int _orderCount = 0;
  double _inventoryValue = 0;
  int _inventoryCount = 0;

  List<Map<String, dynamic>> _topSelling = [];
  final Map<String, int> _qtyMap = {};
  final Map<String, double> _revMap = {};

  bool _hideProfit = true;
  bool _sortByRevenue = true;
  String _selectedPeriod = "Hôm nay";
  DateTimeRange? _customRange;

  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenData(); // 3. Dùng Stream để dữ liệu tự động nhảy số
  }

  void _listenData() {
    // Chỉ lấy các đơn đã hoàn thành để tính doanh thu/lợi nhuận
    _firestoreService.streamOrders('completed').listen((orders) {
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _applyFilter(_selectedPeriod);
        });
      }
    });

    // Lấy danh sách hàng hóa để tính giá trị tồn kho
    _firestoreService.streamProducts().listen((products) {
      if (mounted) {
        setState(() {
          _products = products;
          _applyFilter(_selectedPeriod);
        });
      }
    });
  }

  // Tạo hàm refresh giả vì Stream đã tự động cập nhật (giữ lại UX kéo thả)
  Future<void> _refreshData() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _applyFilter(String period) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime start;
    DateTime end = now;

    switch (period) {
      case "Hôm nay":
        start = today;
        break;
      case "Hôm qua":
        start = today.subtract(const Duration(days: 1));
        end = today.subtract(const Duration(seconds: 1));
        break;
      case "7 ngày qua":
        start = today.subtract(const Duration(days: 6));
        break;
      case "Tháng này":
        start = DateTime(now.year, now.month, 1);
        break;
      case "Tháng trước":
        start = DateTime(now.year, now.month - 1, 1);
        end = DateTime(now.year, now.month, 1).subtract(const Duration(seconds: 1));
        break;
      case "Tùy chỉnh":
        if (_customRange != null) {
          start = _customRange!.start;
          end = _customRange!.end.add(const Duration(days: 1)).subtract(const Duration(seconds: 1));
        } else {
          start = today;
        }
        break;
      default:
        start = today;
    }

    setState(() {
      _selectedPeriod = period;
      _filteredOrders = _allOrders.where((o) => o.date.isAfter(start.subtract(const Duration(seconds: 1))) && o.date.isBefore(end.add(const Duration(seconds: 1)))).toList();
      _calculateStats();
    });
  }

  void _calculateStats() {
    _totalRevenue = 0;
    _totalProfit = 0;
    _orderCount = 0;
    _inventoryValue = 0;
    _inventoryCount = 0;
    _qtyMap.clear();
    _revMap.clear();

    for (var order in _filteredOrders) {
      _totalRevenue += order.totalPrice;
      _orderCount++;
      double cost = 0;
      for (var item in order.items) {
        cost += (item.importPrice * item.quantity);
        _qtyMap[item.productId] = (_qtyMap[item.productId] ?? 0) + item.quantity;
        _revMap[item.productId] = (_revMap[item.productId] ?? 0) + (item.price * item.quantity);
      }
      _totalProfit += (order.totalPrice - cost);
    }

    for (var p in _products) {
      _inventoryCount += p.quantity;
      _inventoryValue += (p.importPrice * p.quantity);
    }
    _sortTopSelling();
  }

  void _sortTopSelling() {
    var keys = _qtyMap.keys.toList();
    if (_sortByRevenue) {
      keys.sort((a, b) => (_revMap[b] ?? 0).compareTo(_revMap[a] ?? 0));
    } else {
      keys.sort((a, b) => (_qtyMap[b] ?? 0).compareTo(_qtyMap[a] ?? 0));
    }
    _topSelling = [];
    for (var i = 0; i < keys.length && i < 10; i++) {
      String id = keys[i];
      try {
        var p = _products.firstWhere((e) => e.id == id);
        _topSelling.add({'name': p.name, 'qty': _qtyMap[id], 'revenue': _revMap[id], 'imagePath': p.imagePath});
      } catch (e) {
        debugPrint("Lỗi tìm sản phẩm: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData, // Đã sửa gọi hàm refresh mượt mà hơn
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              _buildHeader(),
              _buildDateFilter(),
              _buildSummaryCard(),
              _buildQuickActions(),
              _buildChartSection(),
              _buildInventorySection(),
              _buildTopSellingSection(),
              const SizedBox(height: 30),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.storefront, color: Colors.blue, size: 28),
        const SizedBox(width: 8),
        const Text("Cửa hàng của tôi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF003D75))),
        const Spacer(),
        IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none, color: Colors.black54)),
      ]),
    );
  }

  Widget _buildDateFilter() {
    String displayDate = "";
    DateTime now = DateTime.now();
    if (_selectedPeriod == "Hôm nay") {
      displayDate = "Hôm nay, ${DateFormat('dd/MM/yyyy').format(now)}";
    } else if (_selectedPeriod == "Hôm qua") {
      displayDate = "Hôm qua, ${DateFormat('dd/MM/yyyy').format(now.subtract(const Duration(days: 1)))}";
    } else if (_selectedPeriod == "7 ngày qua") {
      displayDate = "7 ngày qua";
    } else if (_selectedPeriod == "Tháng này") {
      displayDate = "Tháng này (${now.month}/${now.year})";
    } else if (_selectedPeriod == "Tháng trước") {
      int m = now.month - 1; int y = now.year; if (m == 0) { m = 12; y--; }
      displayDate = "Tháng trước ($m/$y)";
    } else if (_selectedPeriod == "Tùy chỉnh" && _customRange != null) {
      displayDate = "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}";
    } else {
      displayDate = _selectedPeriod;
    }

    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: _showPeriodPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayDate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showPeriodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: ["Hôm nay", "Hôm qua", "7 ngày qua", "Tháng này", "Tháng trước", "Tùy chỉnh"].map((p) => ListTile(
          title: Text(p, style: TextStyle(fontWeight: _selectedPeriod == p ? FontWeight.bold : FontWeight.normal, color: _selectedPeriod == p ? Colors.blue : Colors.black)),
          trailing: _selectedPeriod == p ? const Icon(Icons.check, color: Colors.blue) : null,
          onTap: () {
            Navigator.pop(ctx);
            if (p == "Tùy chỉnh") {
              _pickCustomRange();
            } else {
              _applyFilter(p);
            }
          },
        )).toList(),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final res = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (res != null) {
      setState(() => _customRange = res);
      _applyFilter("Tùy chỉnh");
    }
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("$_orderCount hóa đơn", style: const TextStyle(color: Colors.grey)),
          InkWell(onTap: () => setState(() => _hideProfit = !_hideProfit), child: Row(children: [const Text("Lợi nhuận ", style: TextStyle(color: Colors.grey)), Icon(_hideProfit ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 16, color: Colors.grey)])),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(currencyFormat.format(_totalRevenue), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(width: 4),
            const Text("đ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
          ]),
          Text(_hideProfit ? "*** ***" : currencyFormat.format(_totalProfit), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Row(children: [Icon(Icons.assignment_return_outlined, size: 16, color: Colors.grey), SizedBox(width: 6), Text("0 đơn trả hàng - 0", style: TextStyle(color: Colors.grey))]),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 90, color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildActionItem(Icons.monetization_on, "Vay vốn", Colors.blue),
          _buildActionItem(Icons.local_shipping, "Giao hàng", Colors.green),
          _buildActionItem(Icons.payment, "Thanh toán", Colors.orange),
          _buildActionItem(Icons.person, "Nhân viên", Colors.purple),
          _buildActionItem(Icons.account_balance, "Thuế & Kế toán", Colors.teal),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color) {
    return Container(
      width: 80, margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildChartSection() {
    List<BarChartGroupData> barGroups = [];
    Map<String, double> groupedRev = {};
    // Logic gom nhóm: Hôm nay/Hôm qua gom theo Giờ, còn lại gom theo Ngày
    DateFormat keyFormat = (_selectedPeriod == "Hôm nay" || _selectedPeriod == "Hôm qua") ? DateFormat('HH') : DateFormat('dd/MM');

    for (var o in _filteredOrders) {
      String key = keyFormat.format(o.date);
      groupedRev[key] = (groupedRev[key] ?? 0) + o.totalPrice;
    }

    var sortedKeys = groupedRev.keys.toList()..sort();
    for (int i = 0; i < sortedKeys.length; i++) {
      String key = sortedKeys[i];
      barGroups.add(BarChartGroupData(x: i, barRods: [BarChartRodData(toY: groupedRev[key]!, color: Colors.blue, width: 14, borderRadius: BorderRadius.circular(4))]));
    }

    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Doanh thu", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Icon(Icons.chevron_right, color: Colors.grey)]),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: barGroups.isEmpty
              ? const Center(child: Text("Không có dữ liệu trong khoảng này", style: TextStyle(color: Colors.grey)))
              : BarChart(BarChartData(
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, m) => Text("${v.toInt() ~/ 1000}k", style: const TextStyle(fontSize: 10, color: Colors.grey)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, m) {
                if (v.toInt() < sortedKeys.length) {
                  String label = sortedKeys[v.toInt()];
                  if (_selectedPeriod == "Hôm nay" || _selectedPeriod == "Hôm qua") label += "h";
                  return Text(label, style: const TextStyle(fontSize: 9));
                }
                return const Text("");
              })),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: barGroups,
          )),
        ),
      ]),
    );
  }

  Widget _buildInventorySection() {
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Giá trị tồn", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text("Tổng vốn", style: TextStyle(color: Colors.grey)),
          Text(currencyFormat.format(_inventoryValue), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerRight, child: Text("$_inventoryCount hàng hóa", style: const TextStyle(color: Colors.grey, fontSize: 13))),
      ]),
    );
  }

  Widget _buildTopSellingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Hàng bán chạy", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          _buildSortChip("Theo doanh thu", _sortByRevenue, () => setState(() { _sortByRevenue = true; _sortTopSelling(); })),
          const SizedBox(width: 10),
          _buildSortChip("Theo số lượng", !_sortByRevenue, () => setState(() { _sortByRevenue = false; _sortTopSelling(); })),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)), child: const Row(children: [Text("10 ", style: TextStyle(fontSize: 12)), Icon(Icons.arrow_drop_down, size: 16)])),
        ]),
        const SizedBox(height: 16),
        if (_topSelling.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Chưa có dữ liệu bán hàng"))) else ..._topSelling.map((item) => _buildTopItem(item)),
      ]),
    );
  }

  Widget _buildSortChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? Colors.blue : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTopItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: (item['imagePath'] != null && item['imagePath'].isNotEmpty && File(item['imagePath']).existsSync()) ? Image.file(File(item['imagePath']), width: 40, height: 40, fit: BoxFit.cover) : Container(width: 40, height: 40, color: Colors.grey[200], child: const Icon(Icons.image, size: 20, color: Colors.grey))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)), Text(_sortByRevenue ? "${item['qty']} hàng hóa" : currencyFormat.format(item['revenue']), style: const TextStyle(color: Colors.grey, fontSize: 12))])),
        Text(_sortByRevenue ? currencyFormat.format(item['revenue']) : "${item['qty']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }
}