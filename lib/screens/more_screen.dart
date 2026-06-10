// File: lib/screens/more_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_screen.dart';
import 'cashflow_screen.dart';
import 'order_management_screen.dart';
import 'return_screen.dart';
import 'chatbot_screen.dart';

class MoreScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const MoreScreen({super.key, required this.onTabChange});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  String? _avatarPath;
  final String _shopName = "Cửa hàng của tôi";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final res = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text("Chụp ảnh mới"), onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.camera))),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text("Chọn từ thư viện"), onTap: () async => Navigator.pop(ctx, await picker.pickImage(source: ImageSource.gallery))),
        ],
      ),
    );
    if (res != null) setState(() => _avatarPath = res.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildSectionTitle("AI & PHÂN TÍCH THÔNG MINH"),
              _buildMenuBlock([
                _menuItem(Icons.auto_awesome, "Trợ lý AI", Colors.blue[800]!, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatbotScreen()));
                }),
              ]),
              _buildSectionTitle("LỐI TẮT ỨNG DỤNG"),
              _buildMenuBlock([
                _menuItem(Icons.point_of_sale, "Bán hàng", Colors.blue, () => widget.onTabChange(0)),
                _menuItem(Icons.inventory, "Hàng hóa", Colors.orange, () => widget.onTabChange(1)),
                _menuItem(Icons.receipt_long, "Hóa đơn", Colors.green, () => widget.onTabChange(2)),
                _menuItem(Icons.bar_chart, "Tổng quan", Colors.purple, () => widget.onTabChange(3)),
              ]),
              _buildSectionTitle("QUẢN LÝ"),
              _buildMenuBlock([
                _menuItem(Icons.people, "Khách hàng", Colors.blueAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerScreen()));
                }),
                _menuItem(Icons.account_balance_wallet, "Sổ Quỹ", Colors.teal, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CashFlowScreen()));
                }),
                _menuItem(Icons.assignment_return, "Trả hàng", Colors.redAccent, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnScreen()));
                }),
                _menuItem(Icons.assignment, "Đặt hàng", Colors.orangeAccent, () {
                  // SỬA LỖI: status_filter -> statusFilter
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderManagementScreen(statusFilter: 'pending', title: 'Đơn Đặt Hàng')));
                }),
              ]),
              _buildSectionTitle("CÀI ĐẶT & HỖ TRỢ"),
              _buildMenuBlock([
                _menuItem(Icons.language, "Ngôn ngữ", Colors.grey, () {}),
                _menuItem(Icons.description, "Điều khoản sử dụng", Colors.grey, () {}),
                _menuItem(Icons.logout, "Đăng xuất", Colors.red, () async {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Đăng xuất"),
                      content: const Text("Bạn có chắc chắn muốn đăng xuất không?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Hủy")),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Đăng xuất", style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) await FirebaseAuth.instance.signOut();
                }),
              ]),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
                  child: _avatarPath == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
                ),
                Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, size: 14, color: Colors.white))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_shopName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text("Chỉnh sửa thông tin cửa hàng", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit, color: Colors.blue, size: 20)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11))));
  }

  Widget _buildMenuBlock(List<Widget> items) {
    return Container(
      color: Colors.white,
      child: Column(
        children: List.generate(items.length, (index) {
          return Column(
            children: [
              items[index],
              if (index < items.length - 1) const Divider(height: 1, indent: 56),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
