// File: lib/screens/customer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'add_customer_page.dart'; // Đã gọi file riêng

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _repayController = TextEditingController();
  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];

  @override
  void initState() {
    super.initState();
    _listenCustomers();
  }

  void _listenCustomers() {
    _firestoreService.streamCustomers().listen((data) {
      if (mounted) {
        setState(() {
          _allCustomers = data;
          _runFilter(_searchController.text);
        });
      }
    });
  }

  void _runFilter(String keyword) {
    setState(() {
      _filteredCustomers = _allCustomers.where((c) =>
      c.name.toLowerCase().contains(keyword.toLowerCase()) ||
          c.phone.contains(keyword)
      ).toList();
    });
  }

  void _repayDebt(Customer customer) {
    showDialog(
        context: context,
        builder: (ctx) {
          _repayController.text = "";
          return AlertDialog(
            title: Text("Thu nợ: ${customer.name}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Đang nợ: ${currencyFormat.format(customer.debt)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _repayController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Số tiền khách trả", suffixText: "đ", border: OutlineInputBorder()),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Hủy")),
              ElevatedButton(
                onPressed: () async {
                  double amount = double.tryParse(_repayController.text) ?? 0;
                  if (amount > 0) {
                    customer.debt -= amount;
                    if (customer.debt < 0) customer.debt = 0;
                    await _firestoreService.addCustomer(customer);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã thu ${currencyFormat.format(amount)}")));
                  }
                  Navigator.of(ctx).pop();
                },
                child: const Text("Xác nhận thu"),
              ),
            ],
          );
        }
    );
  }

  void _deleteCustomer(String id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Xác nhận"),
          content: const Text("Xóa khách hàng này?"),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("Hủy")),
            TextButton(onPressed: () async {
              await _firestoreService.deleteCustomer(id);
              Navigator.of(ctx).pop();
            }, child: const Text("Xóa", style: TextStyle(color: Colors.red))),
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: const Text("Khách Hàng"),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: "Tìm tên hoặc số điện thoại...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: (){ _searchController.clear(); _runFilter(''); }) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          Expanded(
            child: _filteredCustomers.isEmpty
                ? const Center(child: Text("Chưa có khách hàng"))
                : ListView.builder(
              itemCount: _filteredCustomers.length,
              itemBuilder: (ctx, index) {
                final cus = _filteredCustomers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: cus.debt > 0 ? Colors.red[50] : Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cus.debt > 0 ? Colors.red[100] : Colors.blue[100],
                      backgroundImage: (cus.imagePath.isNotEmpty && File(cus.imagePath).existsSync()) ? FileImage(File(cus.imagePath)) : null,
                      child: (cus.imagePath.isEmpty || !File(cus.imagePath).existsSync()) ? Text(cus.name.substring(0, 1).toUpperCase(), style: TextStyle(color: cus.debt > 0 ? Colors.red : Colors.blue)) : null,
                    ),
                    title: Text(cus.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cus.phone.isEmpty ? "Chưa có SĐT" : cus.phone),
                        if (cus.debt > 0)
                          Text("Nợ: ${currencyFormat.format(cus.debt)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cus.debt > 0)
                          IconButton(
                              icon: const Icon(Icons.payments, color: Colors.green),
                              tooltip: "Thu nợ",
                              onPressed: () => _repayDebt(cus)
                          ),
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => AddCustomerPage(customerToEdit: cus)));
                        }),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteCustomer(cus.id)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCustomerPage())),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}