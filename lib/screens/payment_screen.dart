// File: lib/screens/payment_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/bank_account_model.dart';
import '../services/firestore_service.dart';
import 'bank_account_screen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentScreen extends StatefulWidget {
  final List<OrderItem> cart;
  final Customer? customer;
  final double totalAmount;

  const PaymentScreen({
    super.key,
    required this.cart,
    required this.customer,
    required this.totalAmount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _otherFeeCtrl = TextEditingController();
  final TextEditingController _customerPayCtrl = TextEditingController();
  final TextEditingController _multiCashCtrl = TextEditingController(); // Dành cho Đa phương thức

  bool _isDiscountPercent = false;
  bool _usePoints = false;
  bool _isDelivery = false; // Chờ phát triển sau
  String _paymentMethod = 'Tiền mặt';
  bool _isProcessing = false;

  final int _pointConversionRate = 1000;

  List<BankAccount> _bankAccounts = [];
  BankAccount? _selectedBank;

  Widget _buildCustomerAvatarWidget() {
    Widget defaultIcon = const Icon(Icons.person, color: Colors.blue);
    final imgPath = widget.customer?.imagePath ?? '';

    if (imgPath.isEmpty) {
      return CircleAvatar(radius: 25, backgroundColor: Colors.blue[100], child: defaultIcon);
    }

    // 1. Nếu là ảnh nén Base64 (Lưu từ Cloud)
    if (imgPath.startsWith('data:image')) {
      try {
        final bytes = base64Decode(imgPath.split(',').last);
        return CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue[100],
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        return CircleAvatar(radius: 25, backgroundColor: Colors.blue[100], child: defaultIcon);
      }
    }

    // 2. Nếu là ảnh Web / URL mạng
    if (kIsWeb || imgPath.startsWith('http') || imgPath.startsWith('blob:')) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.blue[100],
        backgroundImage: NetworkImage(imgPath),
        onBackgroundImageError: (_, __) {},
      );
    }

    // 3. Nếu là file trên máy (CHỈ CHẠY TRÊN MOBILE, KHÔNG BAO GIỜ CHẠY TRÊN WEB)
    try {
      if (File(imgPath).existsSync()) {
        return CircleAvatar(
          radius: 25,
          backgroundColor: Colors.blue[100],
          backgroundImage: FileImage(File(imgPath)),
        );
      }
    } catch (_) {}

    return CircleAvatar(radius: 25, backgroundColor: Colors.blue[100], child: defaultIcon);
  }

  @override
  void initState() {
    super.initState();
    _customerPayCtrl.text = currencyFormat.format(_finalAmount).replaceAll('đ', '').trim();

    // Lắng nghe thay đổi chung để render lại UI (cho ô khách gõ)
    void updateUI() => setState(() {});
    _customerPayCtrl.addListener(updateUI);
    _multiCashCtrl.addListener(updateUI);

    // Lắng nghe thay đổi giảm giá/thu khác để tự động cập nhật lại ô Khách thanh toán
    void _updateTotalAndCash() {
      setState(() {
        if (_paymentMethod != 'Đa phương thức') {
          _customerPayCtrl.text = currencyFormat.format(_finalAmount).replaceAll('đ', '').trim();
        }
      });
    }
    _discountCtrl.addListener(_updateTotalAndCash);
    _otherFeeCtrl.addListener(_updateTotalAndCash);

    _firestoreService.streamBankAccounts().listen((accounts) {
      if (mounted) {
        setState(() {
          _bankAccounts = accounts;
          if (_selectedBank == null && accounts.isNotEmpty) {
            _selectedBank = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
          } else if (accounts.isNotEmpty && !_bankAccounts.any((a) => a.id == _selectedBank?.id)) {
            _selectedBank = accounts.firstWhere((a) => a.isDefault, orElse: () => accounts.first);
          }
        });
      }
    });
  }

  int get _totalItemsQty => widget.cart.fold(0, (sum, item) => sum + item.quantity);

  double get _discountAmount {
    double val = double.tryParse(_discountCtrl.text.replaceAll('.', '')) ?? 0;
    if (_isDiscountPercent) return widget.totalAmount * (val / 100);
    return val;
  }

  double get _otherFees => double.tryParse(_otherFeeCtrl.text.replaceAll('.', '')) ?? 0;

  double get _amountBeforePoints {
    double total = widget.totalAmount - _discountAmount + _otherFees;
    return total > 0 ? total : 0;
  }

  // 2. Số điểm thực tế cần dùng (tối đa chỉ bằng số tiền của đơn hàng)
  int get _actualPointsUsed {
    if (!_usePoints || widget.customer == null) return 0;
    final availablePoints = widget.customer!.points;
    if (availablePoints <= 0 || _amountBeforePoints <= 0) return 0;

    // Số điểm cần thiết để thanh toán đủ số tiền đơn hàng
    final pointsNeeded = (_amountBeforePoints / _pointConversionRate).ceil();

    // Chỉ dùng vừa đủ, không dùng vượt quá số điểm khách có
    return pointsNeeded < availablePoints ? pointsNeeded : availablePoints;
  }

  double get _pointsDiscount {
    final discount = (_actualPointsUsed * _pointConversionRate).toDouble();
    return discount > _amountBeforePoints ? _amountBeforePoints : discount;
  }

  double get _finalAmount {
    double total = _amountBeforePoints - _pointsDiscount;
    return total > 0 ? total : 0;
  }

  // Tiền mặt cho phương thức tiêu chuẩn
  double get _customerPaid {
    if (_paymentMethod != 'Tiền mặt') return _finalAmount;
    return double.tryParse(_customerPayCtrl.text.replaceAll('.', '')) ?? 0;
  }

  double get _change => _customerPaid - _finalAmount;

  // Tính toán cho Đa phương thức (Tiền mặt + QR)
  double get _multiCashPaid => double.tryParse(_multiCashCtrl.text.replaceAll('.', '')) ?? 0;

  double get _multiQRAmount {
    double remaining = _finalAmount - _multiCashPaid;
    return remaining > 0 ? remaining : 0;
  }

  int get _pointsEarned => (_finalAmount / 100000).floor();

  String _getQrUrl(double amount) {
    if (_selectedBank == null || _selectedBank!.bankBin.isEmpty || _selectedBank!.accountNumber.isEmpty) return "";

    // Mã hóa nội dung tránh lỗi khoảng trắng
    String addInfo = Uri.encodeComponent("Thanh toan HD${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}");
    String accName = Uri.encodeComponent(_selectedBank!.accountName);

    return "https://img.vietqr.io/image/${_selectedBank!.bankBin}-${_selectedBank!.accountNumber}-compact2.png?amount=${amount.toInt()}&addInfo=$addInfo&accountName=$accName";
  }

  Future<void> _processCheckout() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    String orderId = "HD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";

    // Xây dựng dữ liệu chi tiết nếu là Đa phương thức
    Map<String, dynamic> multiDetails = {};
    if (_paymentMethod == 'Đa phương thức') {
      multiDetails = {
        'cashAmount': _multiCashPaid,
        'qrAmount': _multiQRAmount,
        'bankName': _selectedBank?.bankName ?? ''
      };
    }

    OrderModel newOrder = OrderModel(
      id: orderId,
      date: DateTime.now(),
      totalPrice: _finalAmount,
      customerName: widget.customer?.name ?? 'Khách lẻ',
      customerPhone: widget.customer?.phone ?? '',
      items: widget.cart,
      status: 'completed',
      paymentMethod: _paymentMethod,
      multiPaymentDetails: multiDetails,
      totalDiscount: _discountAmount,
      otherFees: _otherFees,
      isDelivery: _isDelivery,
      // ĐÃ SỬA: Chỉ ghi nhận số điểm thực tế đã dùng
      pointsUsed: _actualPointsUsed,
      pointsEarned: _pointsEarned,
    );

    try {
      double amountForCashflow = _paymentMethod == 'Đa phương thức' ? _multiCashPaid : _customerPaid;

      await _firestoreService.processCheckout(
        order: newOrder,
        amountPaid: amountForCashflow,
        customer: widget.customer,
        usePoints: _usePoints,
        // ĐÃ SỬA: Chỉ trừ đúng số điểm thực tế dùng, giữ lại điểm thừa cho khách
        pointsUsed: _actualPointsUsed,
        pointsEarned: _pointsEarned,
      );
      if (mounted) _showReceiptDialog(newOrder);
    } catch (e) {
      debugPrint("Lỗi thanh toán: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi xử lý giao dịch. Vui lòng thử lại!"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showEnlargedQR(double amount) {
    if (_selectedBank == null) return;
    final qrUrl = _getQrUrl(amount);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Quét mã để thanh toán", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: qrUrl.isEmpty
                  ? Container(
                height: 320,
                alignment: Alignment.center,
                child: const Text("Chưa có thông tin ngân hàng hợp lệ"),
              )
                  : Image.network(
                qrUrl,
                fit: BoxFit.contain,
                height: 320,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (ctx, error, stackTrace) => Container(
                  height: 320,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 50, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text("Không thể tải mã VietQR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                        "Vui lòng kiểm tra lại kết nối mạng Internet của thiết bị.",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(currencyFormat.format(amount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.blue)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text("ĐÓNG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptDialog(OrderModel order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront, size: 50, color: Colors.blue),
                const SizedBox(height: 8),
                const Text("TẠP HÓA SỐ", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text("Đ/c: 123 Đường Công Nghệ, Hà Nội", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                const Text("HÓA ĐƠN THANH TOÁN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(order.date)}", style: const TextStyle(fontSize: 13)),
                Text("Số HD: ${order.id}", style: const TextStyle(fontSize: 13)),
                const Divider(thickness: 1.5, height: 24),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Khách hàng:"), Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                if (widget.customer != null && order.pointsEarned > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Điểm tích lũy thêm:"), Text("+${order.pointsEarned}", style: const TextStyle(color: Colors.green)),
                  ]),
                const Divider(height: 24),

                // DANH SÁCH MÓN: ĐÃ BỔ SUNG DÒNG GIẢM GIÁ TỪNG MÓN CỦA BILL
                ...order.items.map((e) {
                  double itemDiscountAmount = 0;
                  if (e.discount > 0) {
                    itemDiscountAmount = e.isDiscountPercentage
                        ? (e.price * (e.discount / 100)) * e.quantity
                        : e.discount * e.quantity;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: Text(e.productName)),
                            Expanded(flex: 1, child: Text("x${e.quantity}", textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text(currencyFormat.format(e.totalAmount), textAlign: TextAlign.right)),
                          ],
                        ),
                        if (e.discount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              " (Giảm ${e.isDiscountPercentage ? '${e.discount.toInt()}%' : currencyFormat.format(e.discount)}/món: -${currencyFormat.format(itemDiscountAmount)})",
                              style: const TextStyle(fontSize: 11, color: Colors.red, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const Divider(thickness: 1.5, height: 24),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Tổng tiền hàng:"), Text(currencyFormat.format(widget.totalAmount)),
                ]),
                if (order.totalDiscount > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Giảm giá đơn hàng:"), Text("-${currencyFormat.format(order.totalDiscount)}", style: const TextStyle(color: Colors.red)),
                  ]),
                if (order.otherFees > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Thu khác:"), Text("+${currencyFormat.format(order.otherFees)}"),
                  ]),
                if (order.pointsUsed > 0)
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Quy đổi điểm:"), Text("-${currencyFormat.format(order.pointsUsed * _pointConversionRate)}", style: const TextStyle(color: Colors.green)),
                  ]),
                const Divider(height: 24),

                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("TỔNG CỘNG:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(currencyFormat.format(order.totalPrice), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 12),

                if (order.paymentMethod == 'Đa phương thức') ...[
                  const Text("Chi tiết thanh toán:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text(" - Tiền mặt:", style: TextStyle(fontSize: 13)),
                    Text(currencyFormat.format(order.multiPaymentDetails['cashAmount'] ?? 0), style: const TextStyle(fontSize: 13)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(" - CK (${order.multiPaymentDetails['bankName']}):", style: const TextStyle(fontSize: 13)),
                    Text(currencyFormat.format(order.multiPaymentDetails['qrAmount'] ?? 0), style: const TextStyle(fontSize: 13)),
                  ]),
                ] else ...[
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Phương thức:"), Text(order.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                ],

                const SizedBox(height: 24),
                const Text("Cảm ơn Quý khách và hẹn gặp lại!", style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text("Hotline: 0123.456.789", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true);
              },
              child: const Text("HOÀN TẤT", style: TextStyle(fontSize: 16, color: Colors.black54, fontWeight: FontWeight.bold))
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi lệnh in!")));
            },
            icon: const Icon(Icons.print),
            label: const Text("IN HÓA ĐƠN", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Khối UI Sinh mã QR và Chọn Bank ---
  Widget _buildQRAndBankSelector(double amountForQR) {
    if (_bankAccounts.isEmpty) {
      return Container(
        width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
        child: const Text("Chưa có TK ngân hàng. Hãy Thêm NH để hiển thị mã QR.", style: TextStyle(color: Colors.orange), textAlign: TextAlign.center),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8), color: Colors.white),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(_getQrUrl(amountForQR), width: 80, height: 80, fit: BoxFit.cover,
              errorBuilder: (c, e, s) => Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.qr_code, size: 40, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                      value: _selectedBank?.id,
                      items: _bankAccounts.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            "${b.bankName} - ${b.accountNumber} - ${b.accountName}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                      )).toList(),
                      onChanged: (val) => setState(() => _selectedBank = _bankAccounts.firstWhere((b) => b.id == val)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showEnlargedQR(amountForQR),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text("Mở QR", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text("Thanh toán", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          IconButton(icon: const Icon(Icons.share, color: Colors.blue), onPressed: () {}),
          IconButton(icon: const Icon(Icons.print, color: Colors.blue), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Avatar Khách hàng
            Container(
              color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _buildCustomerAvatarWidget(),
                title: Text(widget.customer?.name ?? "Khách lẻ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: widget.customer != null ? Text("Điểm tích lũy: ${widget.customer!.points}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)) : null,
              ),
            ),

            // 2. Xem hàng trong đơn
            Container(
              color: Colors.white, margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                iconColor: Colors.black87,
                textColor: Colors.black87,
                title: Text("Xem hàng trong đơn ($_totalItemsQty sản phẩm)", style: const TextStyle(fontWeight: FontWeight.bold)),
                children: widget.cart.map((item) => ListTile(
                  title: Text(item.productName, style: const TextStyle(fontSize: 15)),
                  subtitle: Text("${item.quantity} x ${currencyFormat.format(item.price)}"),
                  trailing: Text(currencyFormat.format(item.totalAmount), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                )).toList(),
              ),
            ),

            // 3. Tính toán Tiền bạc
            Container(
              color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      const Icon(Icons.receipt_long, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text("Tổng tiền hàng ($_totalItemsQty)", style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ]),
                    Text(currencyFormat.format(widget.totalAmount), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 16),

                  // Giảm giá + Nút gạt %/đ
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(
                      children: [
                        const Text("Giảm giá", style: TextStyle(fontSize: 15, color: Colors.black87)),
                        const SizedBox(width: 12),
                        Container(
                          height: 32,
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                          child: ToggleButtons(
                            isSelected: [_isDiscountPercent, !_isDiscountPercent],
                            onPressed: (idx) => setState(() { _isDiscountPercent = idx == 0; _discountCtrl.clear(); }),
                            renderBorder: false,
                            fillColor: Colors.white,
                            selectedColor: Colors.blue,
                            color: Colors.grey[600],
                            borderRadius: BorderRadius.circular(8),
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 28),
                            children: const [
                              Text("%", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("đ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: 110, child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      inputFormatters: [CurrencyInputFormatter()],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!))),
                    )),
                  ]),
                  const SizedBox(height: 16),

                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Thu khác", style: TextStyle(fontSize: 15, color: Colors.black87)),
                    SizedBox(width: 110, child: TextField(
                      controller: _otherFeeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      inputFormatters: [CurrencyInputFormatter()],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      decoration: InputDecoration(suffixText: "đ", isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!))),
                    )),
                  ]),
                  const SizedBox(height: 12),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero, activeColor: Colors.blue,
                    title: const Text("Giao hàng", style: TextStyle(fontSize: 15, color: Colors.grey)),
                    value: _isDelivery, onChanged: (v) {},
                  ),

                  if (widget.customer != null) ...[
                    const Divider(height: 24, thickness: 1),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Quy đổi điểm trừ vào đơn", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                                const SizedBox(height: 4),
                                if (widget.customer!.points > 0)
                                  Text(
                                    _usePoints
                                        ? "Dùng $_actualPointsUsed / ${widget.customer!.points} điểm (còn lại ${widget.customer!.points - _actualPointsUsed} điểm)"
                                        : "Khách có ${widget.customer!.points} điểm (tương đương ${currencyFormat.format(widget.customer!.points * _pointConversionRate)})",
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  )
                                else
                                  const Text("Khách chưa có điểm", style: TextStyle(color: Colors.grey, fontSize: 13)),

                              ],
                            ),
                          ),
                          Switch(
                            value: _usePoints,
                            activeColor: Colors.blue,
                            onChanged: (widget.customer!.points > 0 && _amountBeforePoints > 0) ? (v) => setState(() {
                              _usePoints = v;
                              if (_paymentMethod != 'Tiền mặt' && _paymentMethod != 'Đa phương thức') {
                                _customerPayCtrl.text = currencyFormat.format(_finalAmount).replaceAll('đ', '').trim();
                              }
                            }) : null,
                          ),
                        ]
                    ),
                  ],

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("KHÁCH CẦN TRẢ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                      Text(currencyFormat.format(_finalAmount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red)),
                    ]),
                  )
                ],
              ),
            ),

            // 4. Phương thức thanh toán
            Container(
              color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Phương thức thanh toán", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      InkWell(
                        onTap: () => setState(() { _paymentMethod = 'Đa phương thức'; }),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: _paymentMethod == 'Đa phương thức' ? Colors.blue[100] : Colors.grey[200], shape: BoxShape.circle),
                          child: Icon(Icons.account_balance_wallet, size: 20, color: _paymentMethod == 'Đa phương thức' ? Colors.blue : Colors.grey[600]),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: ['Tiền mặt', 'Chuyển khoản QR', 'Thẻ', 'Ví'].map((m) => ChoiceChip(
                      label: Text(m),
                      selected: _paymentMethod == m,
                      selectedColor: Colors.blue[50],
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: _paymentMethod == m ? Colors.blue : Colors.grey[300]!)),
                      labelStyle: TextStyle(color: _paymentMethod == m ? Colors.blue[800] : Colors.black87, fontWeight: _paymentMethod == m ? FontWeight.bold : FontWeight.normal),
                      onSelected: (val) {
                        if (val) setState(() { _paymentMethod = m; _customerPayCtrl.text = currencyFormat.format(_finalAmount).replaceAll('đ', '').trim(); });
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),

            // 5. HIỂN THỊ GIAO DIỆN THEO PHƯƠNG THỨC CHỌN

            // --- A. Giao diện Chuyển khoản QR ---
            if (_paymentMethod == 'Chuyển khoản QR')
              Container(
                color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Thông tin chuyển khoản", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BankAccountScreen())),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text("Thêm NH")
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildQRAndBankSelector(_finalAmount),
                  ],
                ),
              ),

            // --- B. Giao diện Đa Phương Thức ---
            if (_paymentMethod == 'Đa phương thức')
              Container(
                color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("1. Thanh toán Tiền mặt", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Số tiền khách đưa:", style: TextStyle(fontSize: 14, color: Colors.black87)),
                      SizedBox(width: 140, child: TextField(
                        controller: _multiCashCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        decoration: InputDecoration(suffixText: "đ", isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      )),
                    ]),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(thickness: 1, height: 1)),

                    Text("2. Thanh toán QR (Còn lại: ${currencyFormat.format(_multiQRAmount)})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 12),
                    _buildQRAndBankSelector(_multiQRAmount),
                  ],
                ),
              ),

            // --- C. Giao diện Tiền mặt tiêu chuẩn ---
            if (_paymentMethod == 'Tiền mặt')
              Container(
                color: Colors.white, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Khách thanh toán", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      SizedBox(width: 140, child: TextField(
                        controller: _customerPayCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        inputFormatters: [CurrencyInputFormatter()],
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                        decoration: InputDecoration(suffixText: "đ", isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      )),
                    ]),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text("Tiền thừa trả khách", style: TextStyle(fontSize: 15, color: Colors.grey)),
                      Text(currencyFormat.format(_change > 0 ? _change : 0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                  ],
                ),
              )
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: ElevatedButton(
          onPressed: ((_paymentMethod == 'Đa phương thức' ? (_multiCashPaid + _multiQRAmount) : _customerPaid) >= _finalAmount && !_isProcessing) ? _processCheckout : null,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0
          ),
          child: _isProcessing
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text("HOÀN TẤT ${currencyFormat.format(_finalAmount)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// === BỘ ĐỊNH DẠNG SỐ THÔNG MINH ===
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Xóa mọi ký tự không phải là số
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