// File: lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SẢN PHẨM ---
  Future<void> addProduct(Product product) async {
    await _db.collection('products').doc(product.id).set(product.toJson());
  }

  Stream<List<Product>> streamProducts() {
    return _db.collection('products').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList());
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    var query = await _db.collection('products').where('barcode', isEqualTo: barcode).limit(1).get();
    if (query.docs.isNotEmpty) return Product.fromJson(query.docs.first.data());
    return null;
  }

  // --- KHÁCH HÀNG ---
  Future<void> addCustomer(Customer customer) async {
    await _db.collection('customers').doc(customer.id).set(customer.toJson());
  }

  Stream<List<Customer>> streamCustomers() {
    return _db.collection('customers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Customer.fromJson(doc.data())).toList());
  }

  Future<void> deleteCustomer(String id) async {
    await _db.collection('customers').doc(id).delete();
  }

  // --- ĐƠN HÀNG ---
  Future<void> saveOrder(OrderModel order) async {
    await _db.collection('orders').doc(order.id).set(order.toJson());
    if (order.status == 'completed') {
      for (var item in order.items) {
        await _db.collection('products').doc(item.productId).update({
          'quantity': FieldValue.increment(-item.quantity)
        });
      }
    }
  }

  Stream<List<OrderModel>> streamOrders(String status) {
    return _db.collection('orders')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((s) => s.docs.map((doc) => OrderModel.fromJson(doc.data())).toList());
  }

  Future<void> deleteOrder(String id) async {
    await _db.collection('orders').doc(id).delete();
  }

  Stream<int> countOrdersByStatus(String status) {
    return _db.collection('orders').where('status', isEqualTo: status).snapshots().map((s) => s.docs.length);
  }

  // --- THU CHI ---
  Future<void> saveTransaction(TransactionModel trans) async {
    await _db.collection('transactions').doc(trans.id).set(trans.toJson());
  }
  Stream<List<TransactionModel>> streamTransactions() {
    return _db.collection('transactions').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList());
  }

  Future<void> deleteTransaction(String id) async {
    await _db.collection('transactions').doc(id).delete();
  }
}
