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
    return Product(
      id: json['id'],
      name: json['name'],
      price: double.tryParse(json['price'].toString()) ?? 0,
      importPrice: double.tryParse(json['importPrice']?.toString() ?? '0') ?? 0,
      quantity: int.tryParse(json['quantity'].toString()) ?? 0,
      barcode: json['barcode'] ?? '',
      imagePath: json['imagePath'] ?? '',
      category: json['category'] ?? 'Chưa phân loại',
      brand: json['brand'] ?? 'Không có',
      description: json['description'] ?? '',
      unit: json['unit'] ?? '',
      minStock: int.tryParse(json['minStock']?.toString() ?? '0') ?? 0,
      otherInfo: json['otherInfo'] ?? '',
      isDirectSale: json['isDirectSale'] ?? true,
      isPointAccumulation: json['isPointAccumulation'] ?? true,
    );
  }
}