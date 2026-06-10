import 'order_model.dart';

class ReturnOrder {
  final String id;
  final String originalOrderId; // Trả cho hóa đơn nào
  final DateTime returnDate;
  final List<OrderItem> returnedItems;
  final double refundAmount;
  final String reason;

  ReturnOrder({
    required this.id,
    required this.originalOrderId,
    required this.returnDate,
    required this.returnedItems,
    required this.refundAmount,
    this.reason = "",
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalOrderId': originalOrderId,
    'returnDate': returnDate.toIso8601String(),
    'returnedItems': returnedItems.map((e) => e.toJson()).toList(),
    'refundAmount': refundAmount,
    'reason': reason,
  };

  factory ReturnOrder.fromJson(Map<String, dynamic> json) => ReturnOrder(
    id: json['id'],
    originalOrderId: json['originalOrderId'],
    returnDate: DateTime.parse(json['returnDate']),
    returnedItems: (json['returnedItems'] as List).map((e) => OrderItem.fromJson(e)).toList(),
    refundAmount: json['refundAmount'],
    reason: json['reason'] ?? "",
  );
}