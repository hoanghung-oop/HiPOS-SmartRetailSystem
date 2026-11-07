// File: lib/screens/cashflow_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<TransactionModel> _transactions = [];
  List<Customer> _customers = [];

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamTransactions().listen((data) {
      if (mounted) {
        setState(() {
          data.sort((a, b) => b.date.compareTo(a.date));
          _transactions = data;
        });
      }
    });

    _firestoreService.streamCustomers().listen((data) {
      if (mounted) setState(() => _customers = data);
    });
  }

  double get _totalIncome {
    return _transactions.where((t) => !t.isExpense).fold(0, (sum, item) => sum + item.amount);
  }

  double get _totalExpense {
    return _transactions.where((t) => t.isExpense).fold(0, (sum, item) => sum + item.amount);
  }

  double get _totalBalance {
    return _totalIncome - _totalExpense;
  }

  // ĐÃ SỬA: Thêm tham số method
  Future<void> _addTransaction(bool isExpense, String method) async {
    if (_amountController.text.isEmpty || _noteController.text.isEmpty) return;

    double amount = double.tryParse(_amountController.text.replaceAll('.', '')) ?? 0;

    final trans = TransactionModel(
      id: "TC${DateTime.now().millisecondsSinceEpoch}",
      note: _noteController.text,
      amount: amount,
      date: DateTime.now(),
      isExpense: isExpense,
      paymentMethod: method, // Lưu phương thức thanh toán
    );

    await _firestoreService.saveTransaction(trans);

    if (mounted) {
      _noteController.clear();
      _amountController.clear();
      Navigator.of(context).pop();
    }
  }

  void _deleteTransaction(TransactionModel transaction) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Xác nhận xóa"),
          content: const Text("Bạn muốn xóa khoản này?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Hủy")),
            TextButton(onPressed: () async {
              await _firestoreService.deleteTransaction(transaction.id);
              if (mounted) Navigator.of(ctx).pop();
            }, child: const Text("Xóa", style: TextStyle(color: Colors.red))),
          ],
        )
    );
  }

  // ĐÃ SỬA: Dùng StatefulBuilder để cập nhật UI Dropdown bên trong Dialog
  void _showAddDialog(bool isExpense) {
    _noteController.clear();
    _amountController.clear();
    String selectedMethod = 'Tiền mặt'; // Mặc định

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isExpense ? "Ghi khoản CHI" : "Ghi khoản THU", style: TextStyle(color: isExpense ? Colors.red : Colors.green)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: const InputDecoration(labelText: "Số tiền", suffixText: "đ", border: const OutlineInputBorder()),
                    autofocus: true,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedMethod,
                    decoration: const InputDecoration(labelText: "Phương thức", border: OutlineInputBorder()),
                    items: ['Tiền mặt', 'Chuyển khoản', 'Thẻ', 'Ví'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setStateDialog(() => selectedMethod = val!),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                        labelText: "Lý do (VD: ${isExpense ? 'Tiền điện' : 'Bán ve chai'})",
                        border: const OutlineInputBorder()
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () => _addTransaction(isExpense, selectedMethod),
                  style: ElevatedButton.styleFrom(backgroundColor: isExpense ? Colors.red : Colors.green, foregroundColor: Colors.white),
                  child: const Text("Lưu"),
                ),
              ],
            );
          }
      ),
    );
  }

  void _showDetail(TransactionModel transaction) {
    Customer? customer;
    if (transaction.customerId.isNotEmpty) {
      try {
        customer = _customers.firstWhere((c) => c.id == transaction.customerId);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(transaction.isExpense ? "Chi tiết phiếu chi" : "Chi tiết phiếu thu", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            _detailRow("Mã phiếu", transaction.id),
            _detailRow("Ngày tạo", DateFormat('HH:mm - dd/MM/yyyy').format(transaction.date)),
            _detailRow("Loại", transaction.isExpense ? "Chi" : "Thu", color: transaction.isExpense ? Colors.red : Colors.green),
            _detailRow("Số tiền", currencyFormat.format(transaction.amount), isBold: true, color: transaction.isExpense ? Colors.red : Colors.green),
            _detailRow("Lý do/Ghi chú", transaction.note),
            if (customer != null) _detailRow("Khách hàng", customer.name),
            _detailRow("Phương thức", transaction.paymentMethod),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteTransaction(transaction);
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text("Xóa phiếu", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text("Sổ Quỹ"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildSummaryCard(),
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text("Chưa có ghi chép nào"))
                : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (ctx, index) {
                final tran = _transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                  child: ListTile(
                    onTap: () => _showDetail(tran),
                    leading: CircleAvatar(
                      backgroundColor: tran.isExpense ? Colors.red[50] : Colors.green[50],
                      child: Icon(tran.isExpense ? Icons.arrow_upward : Icons.arrow_downward, color: tran.isExpense ? Colors.red : Colors.green, size: 20),
                    ),
                    title: Text(tran.note, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(DateFormat('HH:mm - dd/MM/yyyy').format(tran.date), style: const TextStyle(fontSize: 12)),
                    trailing: Text(
                        "${tran.isExpense ? '-' : '+'}${currencyFormat.format(tran.amount)}",
                        style: TextStyle(
                            color: tran.isExpense ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 15
                        )
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btnThu",
            onPressed: () => _showAddDialog(false),
            backgroundColor: Colors.green,
            mini: true,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btnChi",
            onPressed: () => _showAddDialog(true),
            backgroundColor: Colors.red,
            mini: true,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          const Text("TIỀN QUỸ HIỆN CÓ", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Text(currencyFormat.format(_totalBalance), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Column(children: [
                const Text("TỔNG THU", style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text(currencyFormat.format(_totalIncome), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ])),
              Container(width: 1, height: 30, color: Colors.grey[200]),
              Expanded(child: Column(children: [
                const Text("TỔNG CHI", style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text(currencyFormat.format(_totalExpense), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ])),
            ],
          )
        ],
      ),
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) return newValue;
    try {
      double value = double.parse(newValue.text.replaceAll('.', ''));
      final formatter = NumberFormat('#,###', 'vi_VN');
      String newText = formatter.format(value).replaceAll(',', '.');
      return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
    } catch (_) {
      return newValue;
    }
  }
}