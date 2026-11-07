// File: lib/screens/bank_account_screen.dart
import 'package:flutter/material.dart';
import '../models/bank_account_model.dart';
import '../services/firestore_service.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<BankAccount> _accounts = [];

  final String _securityPin = "1234";

  final List<Map<String, String>> _vietnamBanks = [
    {"name": "MBBank (Quân Đội)", "shortName": "MBBank", "bin": "970422"},
    {"name": "Vietcombank (VCB)", "shortName": "Vietcombank", "bin": "970436"},
    {"name": "Techcombank (TCB)", "shortName": "Techcombank", "bin": "970407"},
    {"name": "BIDV (Đầu Tư & Phát Triển)", "shortName": "BIDV", "bin": "970418"},
    {"name": "VietinBank (Công Thương)", "shortName": "VietinBank", "bin": "970415"},
    {"name": "Agribank (Nông Nghiệp)", "shortName": "Agribank", "bin": "970405"},
    {"name": "ACB (Á Châu)", "shortName": "ACB", "bin": "970416"},
    {"name": "VPBank (Thịnh Vượng)", "shortName": "VPBank", "bin": "970432"},
    {"name": "TPBank (Tiên Phong)", "shortName": "TPBank", "bin": "970423"},
    {"name": "Sacombank", "shortName": "Sacombank", "bin": "970403"},
    {"name": "HDBank", "shortName": "HDBank", "bin": "970437"},
    {"name": "VIB (Quốc Tế)", "shortName": "VIB", "bin": "970441"},
    {"name": "SHB (Sài Gòn - Hà Nội)", "shortName": "SHB", "bin": "970443"},
    {"name": "SeABank", "shortName": "SeABank", "bin": "970440"},
    {"name": "OCB (Phương Đông)", "shortName": "OCB", "bin": "970448"},
    {"name": "MSB (Hàng Hải)", "shortName": "MSB", "bin": "970426"},
    {"name": "LPBank (Bưu Điện Liên Việt)", "shortName": "LPBank", "bin": "970449"},
    {"name": "Eximbank", "shortName": "Eximbank", "bin": "970431"},
    {"name": "Nam A Bank", "shortName": "Nam A Bank", "bin": "970428"},
    {"name": "BVBank (Bản Việt)", "shortName": "BVBank", "bin": "970454"},
  ];

  @override
  void initState() {
    super.initState();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamBankAccounts().listen((data) {
      if (mounted) {
        setState(() {
          _accounts = data;
        });
      }
    });
  }

  void _verifyPinThen(VoidCallback onSuccess) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.blue),
            SizedBox(width: 8),
            Text("Xác thực chủ quán", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Nhập mã PIN để thay đổi tài khoản nhận tiền:", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                counterText: "",
                hintText: "••••",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text == _securityPin) {
                Navigator.pop(ctx);
                onSuccess();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Mã PIN không chính xác!"), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text("XÁC NHẬN"),
          )
        ],
      ),
    );
  }

  void _showAccountDialog({BankAccount? account}) {
    final isEditing = account != null;

    Map<String, String> selectedBank = _vietnamBanks.firstWhere(
          (b) => b['bin'] == account?.bankBin,
      orElse: () => _vietnamBanks.first,
    );

    final accNumberCtrl = TextEditingController(text: account?.accountNumber ?? "");
    final accNameCtrl = TextEditingController(text: account?.accountName ?? "");
    bool isDefault = account?.isDefault ?? (_accounts.isEmpty);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isEditing ? "Sửa tài khoản thụ hưởng" : "Thêm tài khoản thụ hưởng", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Ngân hàng:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedBank['bin'],
                        items: _vietnamBanks.map((b) => DropdownMenuItem(
                          value: b['bin'],
                          child: Text(b['name']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() {
                              selectedBank = _vietnamBanks.firstWhere((b) => b['bin'] == val);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accNumberCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Số tài khoản (*)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.credit_card),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: accNameCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Tên chủ tài khoản (KHÔNG DẤU) (*)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text("Đặt làm tài khoản nhận tiền chính"),
                    value: isDefault,
                    activeColor: Colors.blue,
                    onChanged: (val) => setStateDialog(() => isDefault = val),
                    contentPadding: EdgeInsets.zero,
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                onPressed: () async {
                  if (accNumberCtrl.text.trim().isEmpty || accNameCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng điền đủ số tài khoản và tên chủ thẻ")));
                    return;
                  }

                  final newAcc = BankAccount(
                    id: isEditing ? account.id : "BANK${DateTime.now().millisecondsSinceEpoch}",
                    bankName: selectedBank['shortName']!,
                    bankBin: selectedBank['bin']!,
                    accountNumber: accNumberCtrl.text.trim(),
                    accountName: accNameCtrl.text.trim().toUpperCase(),
                    isDefault: isDefault,
                  );

                  // ĐÓNG DIALOG NGAY LẬP TỨC (Không để treo giao diện)
                  Navigator.pop(ctx);

                  try {
                    await _firestoreService.saveBankAccount(newAcc);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Lỗi lưu tài khoản: $e"), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text("LƯU"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteAccount(BankAccount account) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn muốn xóa tài khoản ${account.bankName} - ${account.accountNumber}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () async {
              // ĐÓNG DIALOG NGAY LẬP TỨC
              Navigator.pop(ctx);

              try {
                await _firestoreService.deleteBankAccount(account.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi xóa tài khoản: $e"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Tài khoản thụ hưởng"),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: _accounts.isEmpty
          ? const Center(child: Text("Chưa có tài khoản ngân hàng nào"))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _accounts.length,
        itemBuilder: (ctx, i) {
          final acc = _accounts[i];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: acc.isDefault ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                child: const Icon(Icons.account_balance, color: Colors.blue),
              ),
              title: Row(
                children: [
                  Text(acc.bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (acc.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      child: const Text("MẶC ĐỊNH", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("STK: ${acc.accountNumber}", style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500)),
                    Text("Chủ TK: ${acc.accountName}", style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'edit') {
                    _verifyPinThen(() => _showAccountDialog(account: acc));
                  }
                  if (val == 'delete') {
                    _verifyPinThen(() => _deleteAccount(acc));
                  }
                  if (val == 'default') {
                    _firestoreService.setAsDefaultBankAccount(acc.id);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!acc.isDefault) const PopupMenuItem(value: 'default', child: Text("Đặt làm mặc định")),
                  const PopupMenuItem(value: 'edit', child: Text("Sửa thông tin")),
                  const PopupMenuItem(value: 'delete', child: Text("Xóa tài khoản", style: TextStyle(color: Colors.red))),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _verifyPinThen(() => _showAccountDialog()),
        backgroundColor: Colors.blue[700],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Thêm tài khoản", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}