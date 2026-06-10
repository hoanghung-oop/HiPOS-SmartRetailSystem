// File: lib/screens/order_management_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order_model.dart';
import '../services/firestore_service.dart';

class OrderManagementScreen extends StatefulWidget {
  final String statusFilter; // 'draft' hoặc 'pending' hoặc 'completed' (để trả hàng)
  final String title;

  const OrderManagementScreen({super.key, required this.statusFilter, required this.title});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.title),
          // Đã cập nhật logic màu sắc theo trạng thái
          backgroundColor: widget.statusFilter == 'draft' ? Colors.orange : Colors.blue,
          foregroundColor: Colors.white
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _firestoreService.streamOrders(widget.statusFilter),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Không có đơn hàng nào"));
          }

          final orders = snapshot.data!;
          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (ctx, index) {
              final order = orders[index];
              return Card(
                // Đã cập nhật margin theo Code 2 để danh sách nhìn liền mạch hơn
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${DateFormat('dd/MM HH:mm').format(order.date)} - ${order.items.length} món"),
                      Text(currencyFormat.format(order.totalPrice), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nút Xóa có gọi Dialog xác nhận
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.grey),
                        onPressed: () => _showDeleteConfirm(order.id),
                      ),
                      // Nút Chọn (Mũi tên) - Có thể bấm được
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.blue),
                        onPressed: () {
                          // Trả đơn hàng này về màn hình trước (SalesScreen)
                          Navigator.pop(context, order);
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context, order); // Chọn đơn để xử lý tiếp
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirm(String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: const Text("Bạn có chắc chắn muốn xóa đơn hàng này?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () {
              _firestoreService.deleteOrder(orderId);
              Navigator.pop(ctx);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}