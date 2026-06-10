// File: lib/models/transaction_model.dart

class TransactionModel {
  String id;
  String note;      // Ghi chú
  double amount;    // Số tiền
  DateTime date;    // Ngày
  bool isExpense;   // true = Chi, false = Thu
  String customerId; // <--- MỚI: Liên kết khách hàng
  String paymentMethod; // <--- MỚI: Tiền mặt, Chuyển khoản, Thẻ

  TransactionModel({
    required this.id,
    required this.note,
    required this.amount,
    required this.date,
    required this.isExpense,
    this.customerId = '',
    this.paymentMethod = 'Tiền mặt',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'note': note,
    'amount': amount,
    'date': date.toIso8601String(),
    'isExpense': isExpense,
    'customerId': customerId,
    'paymentMethod': paymentMethod,
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      note: json['note'],
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      date: DateTime.parse(json['date']),
      isExpense: json['isExpense'] ?? true,
      customerId: json['customerId'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'Tiền mặt',
    );
  }
}