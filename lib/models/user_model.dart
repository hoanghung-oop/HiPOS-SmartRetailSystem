class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // Thêm role để phân quyền (ví dụ: 'admin', 'staff', 'customer')

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.role = 'customer', // Mặc định khi mới đăng ký là khách hàng/nhân viên
  });

  // Chuyển đổi dữ liệu thành Map để sau này dễ dàng lưu lên Firebase Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
    };
  }

  // Lấy dữ liệu từ Map (khi tải từ Firebase về app)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'customer',
    );
  }
}