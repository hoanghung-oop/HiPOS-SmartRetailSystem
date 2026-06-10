// File: lib/models/order_model.dart

class OrderItem {
  String productId;
  String productName;
  double price;
  double importPrice;
  int quantity;
  double discount; // Giá trị giảm giá
  bool isDiscountPercentage; // Giảm theo % hay số tiền
  String note;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.importPrice,
    required this.quantity,
    this.discount = 0,
    this.isDiscountPercentage = true,
    this.note = '',
  });

  double get sellingPrice {
    if (isDiscountPercentage) {
      return price * (1 - discount / 100);
    }
    return price - discount;
  }

  double get totalAmount => sellingPrice * quantity;

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productName': productName,
    'price': price,
    'importPrice': importPrice,
    'quantity': quantity,
    'discount': discount,
    'isDiscountPercentage': isDiscountPercentage,
    'note': note,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'],
      productName: json['productName'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      importPrice: double.tryParse(json['importPrice'].toString()) ?? 0,
      quantity: int.tryParse(json['quantity'].toString()) ?? 0,
      discount: double.tryParse(json['discount']?.toString() ?? '0') ?? 0,
      isDiscountPercentage: json['isDiscountPercentage'] ?? true,
      note: json['note'] ?? '',
    );
  }
}

class OrderModel {
  String id;
  DateTime date;
  double totalPrice;
  String customerName;
  String customerPhone;
  List<OrderItem> items;
  String status; 

  OrderModel({
    required this.id,
    required this.date,
    required this.totalPrice,
    required this.customerName,
    this.customerPhone = '',
    required this.items,
    this.status = 'completed',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'totalPrice': totalPrice,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'items': items.map((e) => e.toJson()).toList(),
    'status': status,
  };

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      date: DateTime.parse(json['date']),
      totalPrice: double.tryParse(json['totalPrice'].toString()) ?? 0,
      customerName: json['customerName'] ?? 'Khách lẻ',
      customerPhone: json['customerPhone'] ?? '',
      items: (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList(),
      status: json['status'] ?? 'completed',
    );
  }
}