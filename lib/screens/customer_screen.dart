// File: lib/screens/customer_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'add_customer_page.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
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
              if (mounted) Navigator.of(ctx).pop();
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
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[100], // Mặc định màu xanh
                      backgroundImage: (cus.imagePath.isNotEmpty && File(cus.imagePath).existsSync()) ? FileImage(File(cus.imagePath)) : null,
                      child: (cus.imagePath.isEmpty || !File(cus.imagePath).existsSync()) ? Text(cus.name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.blue)) : null,
                    ),
                    title: Text(cus.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cus.phone.isEmpty ? "Chưa có SĐT" : cus.phone),
                        Text("Điểm tích lũy: ${cus.points}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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