// File: lib/screens/add_customer_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'dart:convert';

class AddCustomerPage extends StatefulWidget {
  final Customer? customerToEdit;
  const AddCustomerPage({super.key, this.customerToEdit});
  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  final _firestoreService = FirestoreService();
  late TextEditingController _nameCtrl, _phone1Ctrl, _phone2Ctrl, _addressCtrl, _idCtrl, _noteCtrl;
  String? _birthday;
  String _gender = "Nam";
  String _group = "Mặc định";
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    final c = widget.customerToEdit;
    _nameCtrl = TextEditingController(text: c?.name ?? "");
    _phone1Ctrl = TextEditingController(text: c?.phone ?? "");
    _phone2Ctrl = TextEditingController(text: c?.phone2 ?? "");
    _addressCtrl = TextEditingController(text: c?.address ?? "");
    _idCtrl = TextEditingController(text: c?.id ?? "KH${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}");
    _noteCtrl = TextEditingController(text: c?.note ?? "");
    _birthday = (c?.birthday.isNotEmpty ?? false) ? c!.birthday : null;
    _gender = c?.gender ?? "Nam";
    _group = c?.group ?? "Mặc định";
    _imagePath = (c?.imagePath.isNotEmpty ?? false) ? c!.imagePath : null;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (d != null) setState(() => _birthday = DateFormat('dd/MM/yyyy').format(d));
  }

  void _save() async {
    if (_nameCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập tên khách hàng")));
      return;
    }
    final newC = Customer(
      id: _idCtrl.text, name: _nameCtrl.text, phone: _phone1Ctrl.text, phone2: _phone2Ctrl.text,
      address: _addressCtrl.text, birthday: _birthday ?? "",
      gender: _gender, group: _group, note: _noteCtrl.text, imagePath: _imagePath ?? "",
      points: widget.customerToEdit?.points ?? 0,
    );
    try {
      await _firestoreService.addCustomer(newC);
      if (mounted) Navigator.pop(context, newC);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Lỗi mạng hoặc máy chủ. Vui lòng kiểm tra lại kết nối!"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: Text(widget.customerToEdit != null ? "Sửa khách hàng" : "Khách hàng mới"), actions: [TextButton(onPressed: _save, child: const Text("LƯU", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)))]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: screenWidth > 600 ? 500 : screenWidth),
            child: Column(children: [
              _buildAvatar(),
              const SizedBox(height: 20),
              _buildField("Họ và tên (*)", _nameCtrl),
              _buildField("Số điện thoại 1", _phone1Ctrl, isPhone: true),
              _buildField("Số điện thoại 2", _phone2Ctrl, isPhone: true),
              _buildField("Địa chỉ", _addressCtrl),
              Row(children: [
                Expanded(child: _buildDatePicker()),
                const SizedBox(width: 12),
                Expanded(child: _buildSelect("Giới tính", _gender, ["Nam", "Nữ", "Khác"], (v) => setState(() => _gender = v!))),
              ]),
              const SizedBox(height: 12),
              _buildField("Mã khách hàng", _idCtrl),
              _buildSelect("Nhóm khách", _group, ["Mặc định", "VIP", "Đại lý", "Thân thiết"], (v) => setState(() => _group = v!)),
              _buildField("Ghi chú", _noteCtrl, maxLines: 3),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final res = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 250,
          maxHeight: 250,
          imageQuality: 70,
        );
        if (res != null) {
          final bytes = await res.readAsBytes();
          setState(() => _imagePath = "data:image/jpeg;base64,${base64Encode(bytes)}");
        }
      },
      child: CircleAvatar(
        radius: 45,
        backgroundImage: _imagePath != null && _imagePath!.startsWith('data:image')
            ? MemoryImage(base64Decode(_imagePath!.split(',').last))
            : (_imagePath != null && File(_imagePath!).existsSync() ? FileImage(File(_imagePath!)) : null),
        child: _imagePath == null ? const Icon(Icons.camera_alt, size: 30) : null,
      ),
    );
  }
  Widget _buildField(String label, TextEditingController ctrl, {bool isPhone = false, int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, maxLines: maxLines, keyboardType: isPhone ? TextInputType.phone : TextInputType.text, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())));
  }
  Widget _buildDatePicker() {
    return InkWell(onTap: _pickDate, child: InputDecorator(decoration: const InputDecoration(labelText: "Ngày sinh", border: OutlineInputBorder()), child: Text(_birthday ?? "Chọn ngày")));
  }
  Widget _buildSelect(String label, String value, List<String> items, Function(String?) onChanged) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged));
  }
}