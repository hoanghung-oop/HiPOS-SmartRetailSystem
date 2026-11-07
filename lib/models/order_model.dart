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

  String paymentMethod;
  Map<String,
      dynamic> multiPaymentDetails; // Lưu chi tiết nếu là Đa phương thức
  double totalDiscount;
  double otherFees;
  bool isDelivery;
  double deliveryFee;
  int pointsUsed;
  int pointsEarned;

  OrderModel({
    required this.id,
    required this.date,
    required this.totalPrice,
    required this.customerName,
    this.customerPhone = '',
    required this.items,
    this.status = 'completed',
    this.paymentMethod = 'Tiền mặt',
    this.multiPaymentDetails = const {},
    this.totalDiscount = 0,
    this.otherFees = 0,
    this.isDelivery = false,
    this.deliveryFee = 0,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
  });

  Map<String, dynamic> toJson() =>
      {
        'id': id,
        'date': date.toIso8601String(),
        'totalPrice': totalPrice,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status,
        'paymentMethod': paymentMethod,
        'multiPaymentDetails': multiPaymentDetails,
        'totalDiscount': totalDiscount,
        'otherFees': otherFees,
        'isDelivery': isDelivery,
        'deliveryFee': deliveryFee,
        'pointsUsed': pointsUsed,
        'pointsEarned': pointsEarned,
      };

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime
          .now(),
      totalPrice: double.tryParse(json['totalPrice']?.toString() ?? '0') ?? 0,
      customerName: json['customerName'] ?? 'Khách lẻ',
      customerPhone: json['customerPhone'] ?? '',
      items: json['items'] != null
          ? (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList()
          : [],
      status: json['status'] ?? 'completed',
      paymentMethod: json['paymentMethod'] ?? 'Tiền mặt',
      multiPaymentDetails: json['multiPaymentDetails'] != null
          ? Map<String, dynamic>.from(json['multiPaymentDetails'])
          : const {},
      totalDiscount: double.tryParse(
          json['totalDiscount']?.toString() ?? '0') ?? 0,
      otherFees: double.tryParse(json['otherFees']?.toString() ?? '0') ?? 0,
      isDelivery: json['isDelivery'] ?? false,
      deliveryFee: double.tryParse(json['deliveryFee']?.toString() ?? '0') ?? 0,
      pointsUsed: int.tryParse(json['pointsUsed']?.toString() ?? '0') ?? 0,
      pointsEarned: int.tryParse(json['pointsEarned']?.toString() ?? '0') ?? 0,
    );
  }
}