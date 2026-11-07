// File: lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../models/transaction_model.dart';
import '../models/bank_account_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Lấy User ID của tài khoản đang đăng nhập
  String get _userId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Chưa đăng nhập!");
    return user.uid;
  }

  // --- SẢN PHẨM ---
  Future<void> addProduct(Product product) async {
    await _db.collection('users').doc(_userId).collection('products').doc(product.id).set(product.toJson());
  }

  Stream<List<Product>> streamProducts() {
    return _db.collection('users').doc(_userId).collection('products').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList());
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('users').doc(_userId).collection('products').doc(id).delete();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    var query = await _db.collection('users').doc(_userId).collection('products').where('barcode', isEqualTo: barcode).limit(1).get();
    if (query.docs.isNotEmpty) return Product.fromJson(query.docs.first.data());
    return null;
  }

  // --- KHÁCH HÀNG ---
  Future<void> addCustomer(Customer customer) async {
    await _db.collection('users').doc(_userId).collection('customers').doc(customer.id).set(customer.toJson());
  }

  Stream<List<Customer>> streamCustomers() {
    return _db.collection('users').doc(_userId).collection('customers').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Customer.fromJson(doc.data())).toList());
  }

  Future<void> deleteCustomer(String id) async {
    await _db.collection('users').doc(_userId).collection('customers').doc(id).delete();
  }

  // --- ĐƠN HÀNG (Cơ bản) ---
  Future<void> saveOrder(OrderModel order) async {
    await _db.collection('users').doc(_userId).collection('orders').doc(order.id).set(order.toJson());
  }

  Stream<List<OrderModel>> streamOrders(String status) {
    return _db.collection('users').doc(_userId).collection('orders')
        .where('status', isEqualTo: status)
        .snapshots()
        .map((s) => s.docs.map((doc) => OrderModel.fromJson(doc.data())).toList());
  }

  Future<void> deleteOrder(String id) async {
    await _db.collection('users').doc(_userId).collection('orders').doc(id).delete();
  }

  Stream<int> countOrdersByStatus(String status) {
    return _db.collection('users').doc(_userId).collection('orders').where('status', isEqualTo: status).snapshots().map((s) => s.docs.length);
  }

  // --- THU CHI ---
  Future<void> saveTransaction(TransactionModel trans) async {
    await _db.collection('users').doc(_userId).collection('transactions').doc(trans.id).set(trans.toJson());
  }

  Stream<List<TransactionModel>> streamTransactions() {
    return _db.collection('users').doc(_userId).collection('transactions').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => TransactionModel.fromJson(doc.data())).toList());
  }

  Future<void> deleteTransaction(String id) async {
    await _db.collection('users').doc(_userId).collection('transactions').doc(id).delete();
  }

  // =======================================================================
  // NGHIỆP VỤ THANH TOÁN TỔNG HỢP (BATCH WRITE)
  // =======================================================================
  Future<void> processCheckout({
    required OrderModel order,
    required double amountPaid,
    required Customer? customer,
    required bool usePoints,
    required int pointsUsed,
    required int pointsEarned,
  }) async {
    final batch = _db.batch();
    final userDoc = _db.collection('users').doc(_userId);

    // 1. LƯU HÓA ĐƠN
    final orderRef = userDoc.collection('orders').doc(order.id);
    batch.set(orderRef, order.toJson());

    // 2. TRỪ TỒN KHO SẢN PHẨM
    for (var item in order.items) {
      final productRef = userDoc.collection('products').doc(item.productId);
      batch.update(productRef, {'quantity': FieldValue.increment(-item.quantity)});
    }

    // 3. GHI NHẬN VÀO SỔ QUỸ (Dòng tiền thực tế thu được)
    if (order.totalPrice > 0) {
      String transId = "TC${DateTime.now().millisecondsSinceEpoch}";
      final transRef = userDoc.collection('transactions').doc(transId);
      final transaction = TransactionModel(
        id: transId,
        note: "Bán hàng - HD: ${order.id}",
        amount: order.totalPrice,
        date: DateTime.now(),
        isExpense: false,
        customerId: customer?.id ?? '',
        paymentMethod: order.paymentMethod,
      );
      batch.set(transRef, transaction.toJson());
    }

    // 4. CẬP NHẬT ĐIỂM TÍCH LŨY KHÁCH HÀNG
    if (customer != null) {
      int pointChange = pointsEarned - (usePoints ? pointsUsed : 0);
      if (pointChange != 0) {
        final customerRef = userDoc.collection('customers').doc(customer.id);
        batch.update(customerRef, {'points': FieldValue.increment(pointChange)});
      }
    }

    await batch.commit();
  }

  // =======================================================================
  // NGHIỆP VỤ TRẢ HÀNG & THU HỒI ĐIỂM (BATCH WRITE)
  // =======================================================================
  Future<void> processReturn({
    required OrderModel originalOrder,
    required Map<String, int> returnQty,
    required double totalRefund,
  }) async {
    final batch = _db.batch();
    final userDoc = _db.collection('users').doc(_userId);

    // 1. CỘNG LẠI TỒN KHO & TẠO DANH SÁCH HÀNG TRẢ
    List<OrderItem> returnedItems = [];
    for (var item in originalOrder.items) {
      int qty = returnQty[item.productId] ?? 0;
      if (qty > 0) {
        final productRef = userDoc.collection('products').doc(item.productId);
        batch.update(productRef, {'quantity': FieldValue.increment(qty)});

        returnedItems.add(OrderItem(
          productId: item.productId,
          productName: item.productName,
          price: item.price,
          importPrice: item.importPrice,
          quantity: qty,
          discount: item.discount,
          isDiscountPercentage: item.isDiscountPercentage,
        ));
      }
    }

    // 2. TẠO PHIẾU CHI SỔ QUỸ (Hoàn tiền cho khách)
    if (totalRefund > 0) {
      String transId = "TC${DateTime.now().millisecondsSinceEpoch}";
      final transRef = userDoc.collection('transactions').doc(transId);
      final transaction = TransactionModel(
        id: transId,
        note: "Hoàn tiền trả hàng - HD gốc: ${originalOrder.id}",
        amount: totalRefund,
        date: DateTime.now(),
        isExpense: true,
        customerId: '',
        paymentMethod: 'Tiền mặt',
      );
      batch.set(transRef, transaction.toJson());
    }

    // 3. LƯU LỊCH SỬ TRẢ HÀNG
    String returnId = "TH${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}";
    final returnRef = userDoc.collection('returns').doc(returnId);
    batch.set(returnRef, {
      'id': returnId,
      'originalOrderId': originalOrder.id,
      'returnDate': DateTime.now().toIso8601String(),
      'returnedItems': returnedItems.map((e) => e.toJson()).toList(),
      'refundAmount': totalRefund,
      'reason': "Khách trả hàng",
    });

    // 4. THU HỒI ĐIỂM CỦA KHÁCH HÀNG
    if (originalOrder.customerPhone.isNotEmpty) {
      var cusQuery = await userDoc.collection('customers').where('phone', isEqualTo: originalOrder.customerPhone).limit(1).get();
      if (cusQuery.docs.isNotEmpty) {
        String customerId = cusQuery.docs.first.id;
        final customerRef = userDoc.collection('customers').doc(customerId);
        int pointsToDeduct = (totalRefund / 100000).floor();

        if (pointsToDeduct > 0) {
          batch.update(customerRef, {'points': FieldValue.increment(-pointsToDeduct)});
        }
      }
    }

    await batch.commit();
  }

  // =======================================================================
  // QUẢN LÝ TÀI KHOẢN NGÂN HÀNG THỤ HƯỞNG
  // =======================================================================
  Future<void> saveBankAccount(BankAccount account) async {
    if (account.isDefault) {
      await _clearDefaultBankAccounts();
    }
    await _db.collection('users').doc(_userId).collection('bank_accounts').doc(account.id).set(account.toJson());
  }

  Stream<List<BankAccount>> streamBankAccounts() {
    return _db.collection('users').doc(_userId).collection('bank_accounts').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => BankAccount.fromJson(doc.data())).toList());
  }

  Future<void> deleteBankAccount(String id) async {
    await _db.collection('users').doc(_userId).collection('bank_accounts').doc(id).delete();
  }

  Future<void> setAsDefaultBankAccount(String id) async {
    final batch = _db.batch();
    final querySnapshot = await _db.collection('users').doc(_userId).collection('bank_accounts').get();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isDefault': doc.id == id});
    }
    await batch.commit();
  }

  Future<void> _clearDefaultBankAccounts() async {
    final batch = _db.batch();
    final querySnapshot = await _db.collection('users').doc(_userId).collection('bank_accounts').where('isDefault', isEqualTo: true).get();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isDefault': false});
    }
    await batch.commit();
  }
}