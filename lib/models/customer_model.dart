// File: lib/models/customer_model.dart

class Customer {
  String id;
  String name;
  String phone;
  String phone2;
  String address;
  String birthday;
  String gender;
  String group;
  String note;
  String imagePath;
  int points;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.phone2 = '',
    this.address = '',
    this.birthday = '',
    this.gender = 'Khác',
    this.group = 'Mặc định',
    this.note = '',
    this.imagePath = '',
    this.points = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'phone2': phone2,
    'address': address,
    'birthday': birthday,
    'gender': gender,
    'group': group,
    'note': note,
    'imagePath': imagePath,
    'points': points,
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'] ?? '',
      phone2: json['phone2'] ?? '',
      address: json['address'] ?? '',
      birthday: json['birthday'] ?? '',
      gender: json['gender'] ?? 'Khác',
      group: json['group'] ?? 'Mặc định',
      note: json['note'] ?? '',
      imagePath: json['imagePath'] ?? '',
      points: json['points'] ?? 0,
    );
  }
}