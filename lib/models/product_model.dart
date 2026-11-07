// File: lib/models/product_model.dart

class Product {
  String id;
  String name;
  double price;
  double importPrice;
  int quantity;
  String barcode;
  String imagePath;
  String category;
  String brand;
  String description;
  String unit;
  int minStock;
  String otherInfo;
  bool isDirectSale;
  bool isPointAccumulation;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.importPrice = 0,
    required this.quantity,
    this.barcode = '',
    this.imagePath = '',
    this.category = 'Chưa phân loại',
    this.brand = 'Không có',
    this.description = '',
    this.unit = '',
    this.minStock = 0,
    this.otherInfo = '',
    this.isDirectSale = true,
    this.isPointAccumulation = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'importPrice': importPrice,
      'quantity': quantity,
      'barcode': barcode,
      'imagePath': imagePath,
      'category': category,
      'brand': brand,
      'description': description,
      'unit': unit,
      'minStock': minStock,
      'otherInfo': otherInfo,
      'isDirectSale': isDirectSale,
      'isPointAccumulation': isPointAccumulation,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      // Dùng toString() và các giá trị mặc định để bọc chống lỗi Null hoàn toàn
      return Product(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Sản phẩm lỗi tên',
        price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
        importPrice: double.tryParse(json['importPrice']?.toString() ?? '0') ?? 0,
        quantity: int.tryParse(json['quantity']?.toString() ?? '0') ?? 0,
        barcode: json['barcode']?.toString() ?? '',
        imagePath: json['imagePath']?.toString() ?? '',
        category: json['category']?.toString() ?? 'Chưa phân loại',
        brand: json['brand']?.toString() ?? 'Không có',
        description: json['description']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        minStock: int.tryParse(json['minStock']?.toString() ?? '0') ?? 0,
        otherInfo: json['otherInfo']?.toString() ?? '',
        // Ép kiểu an toàn cho Boolean
        isDirectSale: json['isDirectSale'] is bool ? json['isDirectSale'] : true,
        isPointAccumulation: json['isPointAccumulation'] is bool ? json['isPointAccumulation'] : true,
      );
    } catch (e) {
      // KỊCH BẢN CỨU NGUY: Nếu 1 sản phẩm bị hỏng nặng, tạo sản phẩm giả để Stream tiếp tục chạy
      return Product(
        id: 'ERROR_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Lỗi dữ liệu (Hãy xóa SP này)',
        price: 0,
        quantity: 0,
      );
    }
  }
}