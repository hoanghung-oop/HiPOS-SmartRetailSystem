// File: lib/screens/overview_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/firestore_service.dart';
import '../services/ai_service.dart';
import 'chatbot_screen.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final FirestoreService _firestoreService = FirestoreService();
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

  /// Đang chạm vào tầng nào của cột: 0 = tầng gốc, 1 = tầng ngọn.
  /// Dùng để tooltip hiện đúng giá trị phần đang chạm (gốc / lãi / lỗ).
  int? _touchedStackIndex;

  final NumberFormat currencyFormat =
  NumberFormat.currency(locale: 'vi_VN', symbol: '', decimalDigits: 0);

  /// Chỉ dùng riêng cho card tổng quan: có ký hiệu 'đ' trong chuỗi format
  /// để FittedBox scale không làm lệch cỡ chữ của ký hiệu tiền tệ.
  final NumberFormat _currencyWithSymbol =
  NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamOrders('completed').listen((orders) {
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _applyFilter(_selectedPeriod);
        });
      }
    });

    _firestoreService.streamProducts().listen((products) {
      if (mounted) {
        setState(() {
          _products = products;
          _applyFilter(_selectedPeriod);
        });
      }
    });
  }

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
        end = DateTime(now.year, now.month, 1)
            .subtract(const Duration(seconds: 1));
        break;
      case "Tùy chỉnh":
        if (_customRange != null) {
          start = _customRange!.start;
          end = _customRange!.end
              .add(const Duration(days: 1))
              .subtract(const Duration(seconds: 1));
        } else {
          start = today;
        }
        break;
      default:
        start = today;
    }

    setState(() {
      _selectedPeriod = period;
      _filteredOrders = _allOrders
          .where((o) =>
      o.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          o.date.isBefore(end.add(const Duration(seconds: 1))))
          .toList();
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
        _qtyMap[item.productId] =
            (_qtyMap[item.productId] ?? 0) + item.quantity;
        _revMap[item.productId] =
            (_revMap[item.productId] ?? 0) + (item.price * item.quantity);
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
      // ĐÃ SỬA: Thêm orElse để không còn lỗi "Bad state: No element"
      // khi sản phẩm đã bị xóa khỏi kho.
      final p = _products.firstWhere(
            (e) => e.id == id,
        orElse: () => Product(
          id: id,
          name: 'Sản phẩm đã bị xóa',
          price: 0,
          quantity: 0,
        ),
      );
      _topSelling.add({
        'name': p.name,
        'qty': _qtyMap[id],
        'revenue': _revMap[id],
        'imagePath': p.imagePath,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(children: [
              _buildHeader(),
              _buildDateFilter(),
              _buildSummaryCard(),
              _buildQuickActions(),

              AiDailyBriefingWidget(
                  currentProducts: _products, todayRevenue: _totalRevenue),

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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.storefront, color: Colors.blue, size: 28),
        const SizedBox(width: 8),
        const Text("Cửa hàng của tôi",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF003D75))),
        const Spacer(),
        IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none, color: Colors.black54)),
      ]),
    );
  }

  Widget _buildDateFilter() {
    String displayDate = "";
    DateTime now = DateTime.now();
    if (_selectedPeriod == "Hôm nay") {
      displayDate = "Hôm nay, ${DateFormat('dd/MM/yyyy').format(now)}";
    } else if (_selectedPeriod == "Hôm qua") {
      displayDate =
      "Hôm qua, ${DateFormat('dd/MM/yyyy').format(now.subtract(const Duration(days: 1)))}";
    } else if (_selectedPeriod == "7 ngày qua") {
      displayDate = "7 ngày qua";
    } else if (_selectedPeriod == "Tháng này") {
      displayDate = "Tháng này (${now.month}/${now.year})";
    } else if (_selectedPeriod == "Tháng trước") {
      int m = now.month - 1;
      int y = now.year;
      if (m == 0) {
        m = 12;
        y--;
      }
      displayDate = "Tháng trước ($m/$y)";
    } else if (_selectedPeriod == "Tùy chỉnh" && _customRange != null) {
      displayDate =
      "${DateFormat('dd/MM').format(_customRange!.start)} - ${DateFormat('dd/MM').format(_customRange!.end)}";
    } else {
      displayDate = _selectedPeriod;
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: _showPeriodPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(displayDate,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          "Hôm nay",
          "Hôm qua",
          "7 ngày qua",
          "Tháng này",
          "Tháng trước",
          "Tùy chỉnh"
        ]
            .map((p) => ListTile(
          title: Text(p,
              style: TextStyle(
                  fontWeight: _selectedPeriod == p
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _selectedPeriod == p
                      ? Colors.blue
                      : Colors.black)),
          trailing: _selectedPeriod == p
              ? const Icon(Icons.check, color: Colors.blue)
              : null,
          onTap: () {
            Navigator.pop(ctx);
            if (p == "Tùy chỉnh") {
              _pickCustomRange();
            } else {
              _applyFilter(p);
            }
          },
        ))
            .toList(),
      ),
    );
  }

  Future<void> _pickCustomRange() async {
    final res = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (res != null) {
      setState(() => _customRange = res);
      _applyFilter("Tùy chỉnh");
    }
  }

  // =====================================================================
  // SUMMARY CARD — layout chống tràn
  // =====================================================================
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("$_orderCount hóa đơn",
              style: const TextStyle(color: Colors.grey)),
          InkWell(
            onTap: () => setState(() => _hideProfit = !_hideProfit),
            child: Row(children: [
              const Text("Lợi nhuận ", style: TextStyle(color: Colors.grey)),
              Icon(
                  _hideProfit
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: Colors.grey),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _currencyWithSymbol.format(_totalRevenue),
                  maxLines: 1,
                  style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  _hideProfit
                      ? "*** ***"
                      : _currencyWithSymbol.format(_totalProfit),
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _totalProfit >= 0 ? Colors.green : Colors.red),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.assignment_return_outlined, size: 16, color: Colors.grey),
          SizedBox(width: 6),
          Text("0 đơn trả hàng - 0", style: TextStyle(color: Colors.grey)),
        ]),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 90,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _buildActionItem(Icons.monetization_on, "Vay vốn", Colors.blue),
          _buildActionItem(Icons.local_shipping, "Giao hàng", Colors.green),
          _buildActionItem(Icons.payment, "Thanh toán", Colors.orange),
          _buildActionItem(Icons.person, "Nhân viên", Colors.purple),
          _buildActionItem(
              Icons.account_balance, "Thuế & Kế toán", Colors.teal),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, Color color) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // =====================================================================
  // CHART SECTION — 2 tầng (gốc + lãi/lỗ)
  //   + nhãn nghìn/triệu/tỷ
  //   + tooltip theo tầng
  //   + SỬA B: interval & chartMaxY "đẹp" để nhãn trục Y không chồng nhau
  // =====================================================================
  Widget _buildChartSection() {
    // 1. Gom doanh thu và tiền gốc theo từng mốc thời gian
    final Map<String, double> groupedRevenue = {};
    final Map<String, double> groupedCost = {};
    final DateFormat keyFormat =
    (_selectedPeriod == "Hôm nay" || _selectedPeriod == "Hôm qua")
        ? DateFormat('HH')
        : DateFormat('dd/MM');

    for (var o in _filteredOrders) {
      final String key = keyFormat.format(o.date);
      double orderCost = 0;
      for (var item in o.items) {
        orderCost += item.importPrice * item.quantity;
      }
      groupedRevenue[key] = (groupedRevenue[key] ?? 0) + o.totalPrice;
      groupedCost[key] = (groupedCost[key] ?? 0) + orderCost;
    }

    final List<String> sortedKeys = groupedRevenue.keys.toList()..sort();

    // 2. Dựng dữ liệu cho từng cột: 2 tầng stack
    //    - Lãi:  [gốc xanh dương] + [lãi xanh lá]
    //    - Lỗ :  [thu về xanh dương] + [lỗ đỏ]
    //    → Tổng chiều cao cột luôn = max(gốc, doanh thu), không vẽ cột âm.
    final List<BarChartGroupData> barGroups = [];
    final List<Map<String, double>> groupData = [];

    for (int i = 0; i < sortedKeys.length; i++) {
      final String key = sortedKeys[i];
      final double revenue = groupedRevenue[key] ?? 0;
      final double cost = groupedCost[key] ?? 0;
      final double profit = revenue - cost;

      final double baseValue;
      final double topValue;
      final Color topColor;
      if (profit >= 0) {
        baseValue = cost;
        topValue = profit;
        topColor = const Color(0xFF2E9E5B); // xanh lá
      } else {
        baseValue = revenue;
        topValue = -profit; // phần lỗ
        topColor = const Color(0xFFD9534F); // đỏ
      }

      groupData.add({
        'base': baseValue,
        'top': topValue,
        'profit': profit,
        'revenue': revenue,
        'cost': cost,
      });

      barGroups.add(BarChartGroupData(
        x: i,
        barsSpace: 0,
        barRods: [
          BarChartRodData(
            fromY: 0,
            toY: baseValue + topValue,
            width: 14,
            borderRadius: BorderRadius.circular(4),
            rodStackItems: [
              BarChartRodStackItem(0, baseValue, Colors.blue),
              BarChartRodStackItem(baseValue, baseValue + topValue, topColor),
            ],
          ),
        ],
      ));
    }

    // =====================================================================
    // 3. SỬA B — Trục Y "đẹp":
    //    Chọn interval thuộc họ {1,2,5}×10^n, và chartMaxY là BỘI SỐ
    //    của interval. Nhờ vậy đỉnh trục trùng đúng một vạch, không sinh
    //    nhãn lửng chồng lên nhau (case cũ: 312 tỷ chồng 300 tỷ).
    // =====================================================================
    double maxBarHeight = 0;
    for (final g in groupData) {
      final double total = (g['base'] ?? 0) + (g['top'] ?? 0);
      if (total > maxBarHeight) maxBarHeight = total;
    }
    if (maxBarHeight <= 0) maxBarHeight = 1;

    // Mục tiêu ~4 khoảng chia + 10% khoảng thở trên đỉnh cột.
    final double targetInterval = maxBarHeight * 1.1 / 4;
    final double yInterval = _niceInterval(targetInterval);
    // chartMaxY = bội số gần nhất của yInterval, đủ chứa maxBarHeight * 1.1.
    final double chartMaxY =
        (maxBarHeight * 1.1 / yInterval).ceil() * yInterval;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Doanh thu",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
        const SizedBox(height: 6),
        Row(children: [
          _buildLegendDot(Colors.blue, "Tiền gốc"),
          const SizedBox(width: 14),
          _buildLegendDot(const Color(0xFF2E9E5B), "Lợi nhuận"),
          const SizedBox(width: 14),
          _buildLegendDot(const Color(0xFFD9534F), "Lỗ"),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: barGroups.isEmpty
              ? const Center(
              child: Text("Không có dữ liệu trong khoảng này",
                  style: TextStyle(color: Colors.grey)))
              : BarChart(
            BarChartData(
              maxY: chartMaxY,
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                enabled: true,
                // Ghi nhớ tầng đang chạm (0 = gốc, 1 = ngọn)
                // để tooltip hiện đúng số.
                touchCallback: (event, response) {
                  _touchedStackIndex =
                      response?.spot?.touchedStackItemIndex;
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black87,
                  tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  maxContentWidth: 180,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (group.x < 0 || group.x >= groupData.length) {
                      return null;
                    }
                    final data = groupData[group.x];
                    final double profit = data['profit'] ?? 0;
                    final int idx = _touchedStackIndex ?? 0;

                    double value;
                    String label;
                    if (idx <= 0) {
                      // Tầng dưới
                      value = data['base'] ?? 0;
                      label = profit >= 0
                          ? 'Tiền gốc: ${_formatCompactCurrency(value)} đ'
                          : 'Thu về: ${_formatCompactCurrency(value)} đ';
                    } else {
                      // Tầng trên
                      value = data['top'] ?? 0;
                      label = profit >= 0
                          ? 'Lợi nhuận: ${_formatCompactCurrency(value)} đ'
                          : 'Lỗ: ${_formatCompactCurrency(value)} đ';
                    }
                    return BarTooltipItem(
                      label,
                      const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // 1. Giảm từ 52 xuống 40 để nhãn gọn gàng, sát lề trái hơn, không bị trống
                    reservedSize: 40,
                    getTitlesWidget: (v, m) {
                      // 2. Định dạng chữ: số 0 hay các mốc tiền đều đi qua cùng một chuẩn
                      final String label = v == 0 ? "0" : _formatCompactCurrency(v);

                      // 3. Dùng SideTitleWidget để TẤT CẢ các nhãn (gồm cả 0) tự động căn phải thẳng tắp
                      return SideTitleWidget(
                        meta: m,
                        space: 4, // Khoảng cách đều 4px giữa nhãn và đường gióng trục tung
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, m) {
                      final int i = v.toInt();
                      if (i >= 0 &&
                          i < sortedKeys.length &&
                          v == i.toDouble()) {
                        String label = sortedKeys[i];
                        if (_selectedPeriod == "Hôm nay" ||
                            _selectedPeriod == "Hôm qua") {
                          if (label.startsWith('0')) {
                            label = label.substring(1);
                          }
                          label += "h";
                        }
                        // Đồng bộ bọc SideTitleWidget cho cả trục hoành (giờ) để vạch gióng chuẩn xác
                        return SideTitleWidget(
                          meta: m,
                          space: 4,
                          child: Text(label, style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                // SỬA B: dùng yInterval thay cho chartMaxY/4
                horizontalInterval: yInterval,
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
    ]);
  }

  /// Rút gọn số tiền theo quy mô để nhãn trục Y không tràn:
  ///   >= 1 tỷ     -> "1,5 tỷ" / "234 tỷ"
  ///   >= 1 triệu  -> "12 triệu"
  ///   >= 1 nghìn  -> "850 nghìn"
  String _formatCompactCurrency(double value) {
    final double abs = value.abs();
    final String sign = value < 0 ? '-' : '';
    if (abs >= 1000000000) {
      return '$sign${_trimDecimal(abs / 1000000000)} tỷ';
    } else if (abs >= 1000000) {
      return '$sign${_trimDecimal(abs / 1000000)} triệu';
    } else if (abs >= 1000) {
      return '$sign${_trimDecimal(abs / 1000)} nghìn';
    }
    return '$sign${abs.toStringAsFixed(0)}';
  }

  String _trimDecimal(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    // 1 chữ số thập phân, dấu phẩy theo vi_VN
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  /// SỬA B — Trả về khoảng chia "đẹp" thuộc họ {1, 2, 5} × 10^n
  /// gần nhất với target.
  ///   Ví dụ: 82,5 tỷ  -> 100 tỷ
  ///          880 nghìn -> 1 triệu
  ///          4.400     -> 5.000
  double _niceInterval(double target) {
    if (target <= 0) return 1;
    final double exponent = (math.log(target) / math.ln10).floorToDouble();
    final double magnitude = math.pow(10, exponent).toDouble();
    final double normalized = target / magnitude; // nằm trong [1, 10)
    final double niceNorm;
    if (normalized <= 1.0) {
      niceNorm = 1.0;
    } else if (normalized <= 2.0) {
      niceNorm = 2.0;
    } else if (normalized <= 5.0) {
      niceNorm = 5.0;
    } else {
      niceNorm = 10.0;
    }
    return niceNorm * magnitude;
  }

  Widget _buildInventorySection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Giá trị tồn",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Tổng vốn", style: TextStyle(color: Colors.grey)),
              Text(currencyFormat.format(_inventoryValue),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
        const SizedBox(height: 4),
        Align(
            alignment: Alignment.centerRight,
            child: Text("$_inventoryCount hàng hóa",
                style: const TextStyle(color: Colors.grey, fontSize: 13))),
      ]),
    );
  }

  Widget _buildTopSellingSection() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Hàng bán chạy",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          _buildSortChip(
              "Theo doanh thu",
              _sortByRevenue,
                  () => setState(() {
                _sortByRevenue = true;
                _sortTopSelling();
              })),
          const SizedBox(width: 10),
          _buildSortChip(
              "Theo số lượng",
              !_sortByRevenue,
                  () => setState(() {
                _sortByRevenue = false;
                _sortTopSelling();
              })),
          const Spacer(),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4)),
              child: const Row(children: [
                Text("10 ", style: TextStyle(fontSize: 12)),
                Icon(Icons.arrow_drop_down, size: 16)
              ])),
        ]),
        const SizedBox(height: 16),
        if (_topSelling.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text("Chưa có dữ liệu bán hàng")))
        else
          ..._topSelling.map((item) => _buildTopItem(item)),
      ]),
    );
  }

  Widget _buildSortChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: active ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.black54,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTopItem(Map<String, dynamic> item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        _buildProductThumbnail(item['imagePath'] as String?),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      _sortByRevenue
                          ? "${item['qty']} hàng hóa"
                          : currencyFormat.format(item['revenue']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12))
                ])),
        Text(
            _sortByRevenue
                ? currencyFormat.format(item['revenue'])
                : "${item['qty']}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  /// Ảnh thumbnail an toàn cho mọi nền tảng.
  /// - Web / URL / blob: dùng Image.network, không chạm dart:io.
  /// - Mobile: dùng Image.file bọc try/catch.
  /// - Fallback: placeholder xám.
  Widget _buildProductThumbnail(String? imagePath) {
    final Widget placeholder = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, size: 20, color: Colors.grey),
    );

    if (imagePath == null || imagePath.isEmpty) return placeholder;

    // Bổ sung đọc Base64
    if (imagePath.startsWith('data:image')) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(base64Decode(imagePath.split(',').last), width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (c, e, s) => placeholder),
        );
      } catch (_) {
        return placeholder;
      }
    }

    if (kIsWeb ||
        imagePath.startsWith('http') ||
        imagePath.startsWith('blob:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imagePath,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => placeholder,
        ),
      );
    }

    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) => placeholder),
        );
      }
    } catch (_) {}
    return placeholder;
  }
} // ĐÓNG class _OverviewScreenState

// =====================================================================
// WIDGET ĐIỂM TIN AI (class độc lập, ngang cấp với OverviewScreen)
// =====================================================================

class AiDailyBriefingWidget extends StatefulWidget {
  final List<Product> currentProducts;
  final double todayRevenue;

  const AiDailyBriefingWidget(
      {super.key,
        required this.currentProducts,
        required this.todayRevenue});

  @override
  State<AiDailyBriefingWidget> createState() => _AiDailyBriefingWidgetState();
}

class _AiDailyBriefingWidgetState extends State<AiDailyBriefingWidget> {
  Map<String, dynamic>? _aiData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBriefing();
  }

  Future<void> _fetchBriefing() async {
    final data = await AIService()
        .getDailyBusinessBriefing(widget.currentProducts, widget.todayRevenue);
    if (mounted) {
      setState(() {
        _aiData = data;
        _isLoading = false;
      });
    }
  }

  void _showDetailedAdvice(BuildContext context) {
    if (_aiData == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.deepPurple)),
                const SizedBox(width: 12),
                const Text("Chiến lược AI",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 30),
            Text(_aiData!['tieu_de'],
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!)),
                child: Text(_aiData!['phan_tich'],
                    style: const TextStyle(fontSize: 15, height: 1.5))),
            const SizedBox(height: 16),
            const Text("Hành động đề xuất:",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 8),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(_aiData!['hanh_dong'],
                    style: TextStyle(
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500))),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("TÔI ĐÃ HIỂU"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ChatbotScreen()));
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 18),
                        SizedBox(width: 6),
                        Text("HỎI THÊM AI"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.deepPurple.withOpacity(0.1))),
        child: const Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.deepPurple)),
            SizedBox(width: 12),
            Text("Giám đốc AI đang tổng hợp thị trường...",
                style: TextStyle(
                    color: Colors.deepPurple, fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDetailedAdvice(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.deepPurple.shade800,
            Colors.deepPurple.shade600
          ]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.deepPurple.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("AI Cố vấn kinh doanh",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(_aiData?['tieu_de'] ?? "Không có tin tức mới",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}