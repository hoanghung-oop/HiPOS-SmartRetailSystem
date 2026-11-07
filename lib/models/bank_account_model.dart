// File: lib/models/bank_account_model.dart

class BankAccount {
  String id;
  String bankBin;      // Mã BIN của ngân hàng (VD: 970436 cho Vietcombank)
  String bankName;     // Tên ngân hàng (VD: Vietcombank)
  String accountNumber;// Số tài khoản
  String accountName;  // Tên chủ tài khoản (Không dấu)
  bool isDefault;      // Tài khoản mặc định để nhận tiền

  BankAccount({
    required this.id,
    required this.bankBin,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'bankBin': bankBin,
    'bankName': bankName,
    'accountNumber': accountNumber,
    'accountName': accountName,
    'isDefault': isDefault,
  };

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'],
      bankBin: json['bankBin'] ?? '',
      bankName: json['bankName'] ?? '',
      accountNumber: json['accountNumber'] ?? '',
      accountName: json['accountName'] ?? '',
      isDefault: json['isDefault'] ?? false,
    );
  }
}