// File: lib/screens/sales_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// ignore: deprecated_member_use
import 'package:simple_barcode_scanner/simple_barcode_scanner.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';
import '../services/firestore_service.dart';
import 'order_management_screen.dart';
import 'return_screen.dart';
import 'add_customer_page.dart';
import 'payment_screen.dart';
import 'add_product_page.dart';
import '../services/ai_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Product> _products = [];
  final Map<String, OrderItem> _cart = {};
  Customer? _selectedCustomer;
  bool _isSalesMode = true;
  int _draftCount = 0;
  int _pendingCount = 0;

  final NumberFormat currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  // --- BIẾN TRẠNG THÁI CHO GIỌNG NÓI ---
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = "";

  // --- BIẾN CHO GỢI Ý BÁN CHÉO ---
  List<String> _crossSellSuggestions = [];
  bool _isFetchingCrossSell = false;
  bool _hideCrossSell = false;
  Timer? _crossSellTimer;

  void _updateCrossSell() {
    // 1. Hủy Timer cũ nếu người dùng thao tác liên tục (Debounce)
    _crossSellTimer?.cancel();

    if (_cart.isEmpty) {
      if (mounted) {
        setState(() {
          _crossSellSuggestions.clear();
          _isFetchingCrossSell = false;
          _hideCrossSell = false; // Tự động bật lại AI khi giỏ hàng trống
        });
      }
      return;
    }

    // 2. Bắt đầu đếm ngược 15 giây trước khi gọi AI Trợ lý bán hàng
    _crossSellTimer = Timer(const Duration(seconds: 5), () async {
      if (mounted) {
        setState(() => _isFetchingCrossSell = true);
      }

      // Rút trích danh sách tên các món đang có trong giỏ
      List<String> cartItemNames = _cart.values.map((e) => e.productName).toList();

      // Gọi AI (chỉ chạy ngầm, không block ứng dụng)
      List<String> suggestions = await AIService().getCrossSellSuggestions(cartItemNames, _products);

      if (mounted) {
        setState(() {
          _crossSellSuggestions = suggestions;
          _isFetchingCrossSell = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _crossSellTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _listenData();
  }

  void _listenData() {
    _firestoreService.streamProducts().listen((data) {
      if (mounted) setState(() => _products = data);
    });

    _firestoreService.countOrdersByStatus('draft').listen((count) {
      if (mounted) setState(() => _draftCount = count);
    });

    _firestoreService.countOrdersByStatus('pending').listen((count) {
      if (mounted) setState(() => _pendingCount = count);
    });
  }

  void _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (val) => debugPrint('onStatus: $val'),
      onError: (val) => debugPrint('onError: $val'),
    );
    if (available) {
      setState(() {
        _isListening = true;
        _voiceText = "";
      });
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎙️ Đang nghe... Hãy đọc tên hàng"), duration: Duration(seconds: 1)));

      _speech.listen(
        onResult: (val) {
          _voiceText = val.recognizedWords;
        },
        localeId: 'vi_VN',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không thể truy cập Micro. Hãy cấp quyền!"), backgroundColor: Colors.red));
    }
  }

  void _stopListening() async {
    setState(() => _isListening = false);
    await _speech.stop();

    if (_voiceText.isNotEmpty) {
      _processVoiceCommand(_voiceText);
    }
  }

  // 1. Hàm khử toàn bộ dấu tiếng Việt và ký tự đặc biệt
  String _normalizeVietnamese(String text) {
    String result = text.toLowerCase().trim();

    const vietnameseMap = {
      'a': '[àáạảãâầấậẩẫăằắặẳẵ]',
      'e': '[èéẹẻẽêềếệểễ]',
      'i': '[ìíịỉĩ]',
      'o': '[òóọỏõôồốộổỗơờớợởỡ]',
      'u': '[ùúụủũưừứựửữ]',
      'y': '[ỳýỵỷỹ]',
      'd': '[đ]',
    };

    vietnameseMap.forEach((nonAccent, regexPattern) {
      result = result.replaceAll(RegExp(regexPattern), nonAccent);
    });

    // Xóa toàn bộ ký tự lạ, chỉ giữ lại chữ cái và số
    result = result.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // Rút gọn nhiều khoảng trắng liên tiếp thành 1 khoảng trắng
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // 2. Kiểm tra độ trùng khớp giữa đoạn giọng nói và tên sản phẩm
  // Trả về vị trí bắt đầu trùng khớp trên chuỗi chuẩn hóa, hoặc -1 nếu không khớp
  int _findProductMatchIndex(String spokenNorm, String productNorm) {
    if (spokenNorm.isEmpty || productNorm.isEmpty) return -1;

    // Cách 1: Khớp chuẩn xác theo từ (Ví dụ: "rau muong" nằm trong "cho anh hai bo rau muong")
    int idx = spokenNorm.indexOf(productNorm);
    if (idx != -1) return idx;

    // Cách 2: Khớp liên âm bỏ khoảng trắng (Ví dụ: "co ca" <-> "coca", "sinh to bo" <-> "sinhtobo")
    String compactSpoken = spokenNorm.replaceAll(' ', '');
    String compactProd = productNorm.replaceAll(' ', '');
    if (compactSpoken.contains(compactProd)) {
      // Tìm vị trí tương đối của từ đầu tiên của tên sản phẩm trong câu nói
      String firstWord = productNorm.split(' ').first;
      return spokenNorm.indexOf(firstWord);
    }

    return -1;
  }

  void _processVoiceCommand(String text) {
    bool foundAny = false;

    // 1. Chuẩn hóa câu nói gốc
    String normText = _normalizeVietnamese(text);

    // 2. Tách câu thành các mệnh đề độc lập (dựa trên các từ nối)
    String chunkSeparated = normText
        .replaceAll(' va ', '|')
        .replaceAll(' them ', '|')
        .replaceAll(' voi ', '|')
        .replaceAll(' phay ', '|');

    List<String> chunks = chunkSeparated
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // Bản đồ chuyển từ chữ số sang số
    Map<String, int> textToNumber = {
      'mot': 1, 'hai': 2, 'ba': 3, 'bon': 4, 'nam': 5,
      'sau': 6, 'bay': 7, 'tam': 8, 'chin': 9, 'muoi': 10,
      'doi': 2, 'chuc': 10, 'hop': 1, 'chai': 1, 'lon': 1, 'goi': 1, 'dia': 1, 'bat': 1
    };

    // 3. Sắp xếp danh sách sản phẩm theo độ dài tên giảm dần
    // Để ưu tiên nhận diện "Nước ép cam sành" trước "Nước ép cam"
    List<Product> sortedProducts = List.from(_products);
    sortedProducts.sort((a, b) => b.name.length.compareTo(a.name.length));

    for (String chunk in chunks) {
      for (var p in sortedProducts) {
        String pNameNorm = _normalizeVietnamese(p.name);

        int matchIdx = _findProductMatchIndex(chunk, pNameNorm);

        if (matchIdx != -1) {
          int qty = 1;

          // Quét số lượng ở các từ ĐỨNG TRƯỚC tên sản phẩm (Ví dụ: "hai lon coca" -> lấy 2)
          if (matchIdx > 0) {
            String beforeStr = chunk.substring(0, matchIdx).trim();
            List<String> wordsBefore = beforeStr.split(' ');
            for (String w in wordsBefore.reversed) {
              if (int.tryParse(w) != null) {
                qty = int.parse(w);
                break;
              } else if (textToNumber.containsKey(w) && textToNumber[w]! > 1) {
                qty = textToNumber[w]!;
                break;
              }
            }
          }

          // Quét số lượng ở các từ ĐỨNG SAU tên sản phẩm (Ví dụ: "rau muong hai bo" -> lấy 2)
          int afterIdx = matchIdx + pNameNorm.length;
          if (qty == 1 && afterIdx < chunk.length) {
            String afterStr = chunk.substring(afterIdx).trim();
            List<String> wordsAfter = afterStr.split(' ');
            for (String w in wordsAfter) {
              if (int.tryParse(w) != null) {
                qty = int.parse(w);
                break;
              } else if (textToNumber.containsKey(w) && textToNumber[w]! > 1) {
                qty = textToNumber[w]!;
                break;
              }
            }
          }

          _addToCart(p, qty: qty);
          foundAny = true;
          break; // Đã nhận diện được sản phẩm trong mệnh đề này, chuyển sang mệnh đề tiếp theo
        }
      }
    }

    if (foundAny) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎙️ Đã xử lý: '$text'"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎙️ Không tìm thấy sản phẩm trong câu: '$text'"),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _addToCart(Product p, {int qty = 1}) {
    if (_isSalesMode && p.quantity < ((_cart[p.id]?.quantity ?? 0) + qty)) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không đủ hàng trong kho!"), duration: Duration(milliseconds: 500)));
      return;
    }
    setState(() {
      if (_cart.containsKey(p.id)) {
        _cart[p.id]!.quantity += qty;
      } else {
        _cart[p.id] = OrderItem(productId: p.id, productName: p.name, price: p.price, importPrice: p.importPrice, quantity: qty);

        // Cập nhật AI gợi ý khi có món mới
        _updateCrossSell();
      }
    });
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]!.quantity > 1) {
          _cart[productId]!.quantity -= 1;
        } else {
          _cart.remove(productId);

          // Cập nhật lại AI gợi ý khi xóa hẳn 1 món khỏi giỏ
          _updateCrossSell();
        }
      }
    });
  }

  void _removeEntireItem(String productId) {
    setState(() {
      _cart.remove(productId);

      // Cập nhật lại AI gợi ý khi vuốt xóa hẳn 1 món
      _updateCrossSell();
    });
  }

  double get _totalPrice {
    double t = 0;
    _cart.forEach((id, item) => t += item.totalAmount);
    return t;
  }

  int get _totalQuantity {
    int q = 0;
    _cart.forEach((k, item) => q += item.quantity);
    return q;
  }

  Future<void> _processOrder({required String status}) async {
    if (_cart.isEmpty) return;
    List<OrderItem> items = _cart.values.toList();

    OrderModel newOrder = OrderModel(
      id: "HD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}",
      date: DateTime.now(),
      totalPrice: _totalPrice,
      customerName: _selectedCustomer?.name ?? 'Khách lẻ',
      customerPhone: _selectedCustomer?.phone ?? '',
      items: items,
      status: status,
    );

    try {
      await _firestoreService.saveOrder(newOrder);

      if (mounted) {
        setState(() {
          _cart.clear();
          _selectedCustomer = null;
          _crossSellSuggestions.clear(); // Xóa gợi ý khi thanh toán xong
        });
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Thành công!"), backgroundColor: Colors.green)
        );
      }
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

  void _openOrderList(String status, String title) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => OrderManagementScreen(statusFilter: status, title: title)));
    if (result is OrderModel && mounted) {
      setState(() {
        _cart.clear();
        _selectedCustomer = Customer(id: "temp", name: result.customerName, phone: result.customerPhone);
        for (var item in result.items) {
          _cart[item.productId] = item;
        }
        _updateCrossSell(); // Cập nhật AI gợi ý khi mở lại đơn cũ
      });
      await _firestoreService.deleteOrder(result.id);
    }
  }

  Future<void> _scanToSell() async {
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      try {
        final product = _products.firstWhere((p) => p.barcode == res);
        _addToCart(product);
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Không tìm thấy hàng"),
              content: Text("Mã vạch: $res\nBạn có muốn thêm sản phẩm mới này không?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final newP = await Navigator.push(context, MaterialPageRoute(builder: (context) => AddProductPage(initialBarcode: res)));
                    if (newP is Product) {
                      _addToCart(newP);
                    }
                  },
                  child: const Text("Thêm"),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  // --- WIDGET GIAO DIỆN GỢI Ý BÁN CHÉO ---
  Widget _buildCrossSellBar() {
    // Ẩn nếu giỏ hàng trống HOẶC nhân viên đã bấm nút X tắt đi
    if (_cart.isEmpty || _hideCrossSell) return const SizedBox.shrink();

    if (_isFetchingCrossSell) {
      return Container(
        height: 40,
        padding: const EdgeInsets.only(left: 16, right: 8),
        color: Colors.amber.withOpacity(0.1),
        child: Row(
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
            const SizedBox(width: 12),
            const Expanded(child: Text("✨ AI đang gợi ý mua kèm...", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic, fontSize: 13))),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _hideCrossSell = true),
            ),
          ],
        ),
      );
    }

    if (_crossSellSuggestions.isEmpty) return const SizedBox.shrink();

    // Nếu AI trả về lỗi mạng, hiển thị dòng chữ cảnh báo (không phải nút bấm)
    if (_crossSellSuggestions.contains("AI_BUSY") || _crossSellSuggestions.contains("Lỗi Mạng") || _crossSellSuggestions.contains("Lỗi API/Mạng")) {
      return Container(
        height: 45,
        padding: const EdgeInsets.only(left: 16, right: 8),
        color: Colors.red.withOpacity(0.1), // Đổi sang nền đỏ nhạt để báo lỗi
        child: Row(
          children: [
            const Icon(Icons.support_agent, size: 16, color: Colors.blueGrey),
            const SizedBox(width: 8),
            const Expanded(
                child: Text(
                    "Trợ lý Bán hàng hiện đang bận hỗ trợ các quầy khác, hệ thống sẽ dùng gợi ý mặc định.",
                    style: TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic, fontSize: 12)
                )
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _hideCrossSell = true), // Bấm X để tắt
            ),
          ],
        ),
      );
    }

    // NẾU CÓ GỢI Ý THÀNH CÔNG, HIỂN THỊ NÚT BẤM SẢN PHẨM BÌNH THƯỜNG
    return Container(
      height: 45,
      padding: const EdgeInsets.only(left: 16, right: 12),
      color: Colors.amber.withOpacity(0.1),
      child: Row(
        children: [
          const Text("✨ Gợi ý:", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _crossSellSuggestions.map((name) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.amber.shade300),
                      label: Text("+ $name", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () {
                        try {
                          Product p = _products.firstWhere((prod) {
                            String invName = prod.name.trim().toLowerCase();
                            String aiName = name.trim().toLowerCase();
                            return invName == aiName || invName.contains(aiName) || aiName.contains(invName);
                          });
                          _addToCart(p);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sản phẩm không còn trong kho")));
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _hideCrossSell = true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchTrigger(),
            Expanded(child: _buildCartList()),
            _buildCrossSellBar(), // <--- CHÈN THANH GỢI Ý NGAY TRÊN FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        children: [
          Container(
            height: 40, padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(25)),
            child: Row(
              children: [
                _buildToggleBtn("Bán hàng", _isSalesMode, () => setState(() => _isSalesMode = true)),
                _buildToggleBtn("Đặt hàng", !_isSalesMode, () => setState(() => _isSalesMode = false)),
              ],
            ),
          ),
          const Spacer(),
          _buildActionIcon(Icons.save_as, Colors.orange, "Đơn lưu tạm", () => _openOrderList('draft', 'Đơn Lưu Tạm'), count: _draftCount),
          const SizedBox(width: 8),
          _buildActionIcon(Icons.assignment, Colors.blue, "Đơn đặt hàng", () => _openOrderList('pending', 'Đơn Đặt Hàng'), count: _pendingCount),
          const SizedBox(width: 8),
          _buildActionIcon(Icons.keyboard_return, Colors.red, "Trả hàng", () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReturnScreen()));
          }),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String text, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black : Colors.grey[600], fontSize: 13)),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, String tooltip, VoidCallback onTap, {int count = 0}) {
    return InkWell(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  "$count",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchTrigger() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), color: Colors.white,
      child: Row(children: [
        GestureDetector(
          onLongPressStart: (_) => _startListening(),
          onLongPressEnd: (_) => _stopListening(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 45, width: 45,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : Colors.blue[600],
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isListening
                  ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                  : [],
            ),
            child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded( // <-- ĐÃ SỬA: Dùng Expanded bọc ô tìm kiếm để tránh tràn viền (overflow) trên máy thật
            child: InkWell(
              onTap: () async {
                final Product? selected = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProductSearchPage(products: _products)));
                if (selected != null) { _addToCart(selected); }
              },
              child: Container(
                  height: 45, padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Expanded( // <-- ĐÃ SỬA: Đảm bảo cả Text cũng tự thu hẹp không bị đẩy ra ngoài
                      child: Text(
                        _isListening ? "Đang nghe..." : "Tìm hoặc giữ Mic để đọc...",
                        style: TextStyle(color: _isListening ? Colors.red : Colors.grey, fontWeight: _isListening ? FontWeight.bold : FontWeight.normal),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ])
              ),
            )
        ),
        const SizedBox(width: 8),
        InkWell(onTap: _scanToSell, child: Container(height: 45, width: 45, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.qr_code_scanner, color: Colors.black87))),
      ]),
    );
  }

  Widget _buildCartList() {
    if (_cart.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.black12), Text("Chưa có sản phẩm")]));
    return ListView.builder(itemCount: _cart.length, itemBuilder: (ctx, i) {
      String id = _cart.keys.elementAt(i);
      OrderItem item = _cart.values.elementAt(i);
      Product? p = _products.firstWhere((e) => e.id == id, orElse: () => Product(id: "", name: "Lỗi", price: 0, quantity: 0));

      return Dismissible(
        key: Key(id),
        direction: DismissDirection.endToStart,
        onDismissed: (direction) {
          _removeEntireItem(id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Đã xóa ${item.productName}"),
            duration: const Duration(seconds: 1),
            action: SnackBarAction(label: "Hoàn tác", onPressed: () => _addToCart(p, qty: item.quantity)),
          ));
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          color: Colors.red,
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        child: ListTile(
          leading: _buildSafeImage(p.imagePath, size: 50),
          title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(currencyFormat.format(item.sellingPrice)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => _removeFromCart(id)),
            InkWell(
              onTap: () => _showEditItemDialog(item, p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(4)),
                child: Text("${item.quantity}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.green), onPressed: () => _addToCart(p)),
          ]),
          onTap: () => _showEditItemDialog(item, p),
        ),
      );
    });
  }

  void _showEditItemDialog(OrderItem item, Product p) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => ItemEditSheet(
          item: item,
          product: p,
          onUpdate: (updatedItem) {
            setState(() {
              _cart[item.productId] = updatedItem;
            });
          },
        )
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.person, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomerSearchPage()));
                if (result is Customer) setState(() => _selectedCustomer = result);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(child: Text(_selectedCustomer?.name ?? "Khách lẻ", style: const TextStyle(fontWeight: FontWeight.bold))),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedCustomer != null)
            IconButton(icon: const Icon(Icons.close, size: 20, color: Colors.grey), onPressed: () => setState(() => _selectedCustomer = null)),
        ]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text("Tổng tiền", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.shopping_basket_outlined, color: Colors.blue, size: 28),
                Positioned(
                  top: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text("$_totalQuantity", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                )
              ],
            ),
          ]),
          Text(currencyFormat.format(_totalPrice), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red)),
        ]),
        const SizedBox(height: 12),

        Row(children: [
          Expanded(
              flex: 4,
              child: ElevatedButton(
                  onPressed: _cart.isNotEmpty ? () => _processOrder(status: 'draft') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text("LƯU TẠM", maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold)),
                  )
              )
          ),
          const SizedBox(width: 8),
          Expanded(
              flex: 6,
              child: ElevatedButton(
                  onPressed: _cart.isNotEmpty ? () async {
                    if (_isSalesMode) {
                      final bool? success = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaymentScreen(
                            cart: _cart.values.toList(),
                            customer: _selectedCustomer,
                            totalAmount: _totalPrice,
                          ),
                        ),
                      );
                      if (success == true && mounted) {
                        setState(() {
                          _cart.clear();
                          _selectedCustomer = null;
                          _crossSellSuggestions.clear();
                        });
                      }
                    } else {
                      _processOrder(status: 'pending');
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSalesMode ? Colors.blue[700] : Colors.blue[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_isSalesMode ? "THANH TOÁN" : "ĐẶT HÀNG", maxLines: 1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                  )
              )
          ),
        ]),
      ]),
    );
  }
}

class ItemEditSheet extends StatefulWidget {
  final OrderItem item;
  final Product product;
  final Function(OrderItem) onUpdate;
  const ItemEditSheet({super.key, required this.item, required this.product, required this.onUpdate});

  @override
  State<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends State<ItemEditSheet> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _noteCtrl;
  late bool _isPercent;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final fmt = NumberFormat.decimalPattern('vi_VN');
    _qtyCtrl = TextEditingController(text: fmt.format(widget.item.quantity));
    _priceCtrl = TextEditingController(text: fmt.format(widget.item.price.toInt()));

    _discountCtrl = TextEditingController(
      text: widget.item.discount > 0 ? fmt.format(widget.item.discount.toInt()) : '',
    );

    _noteCtrl = TextEditingController(text: widget.item.note);
    _isPercent = widget.item.isDiscountPercentage;
  }

  double get _sellingPrice {
    double p = double.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0;
    double d = double.tryParse(_discountCtrl.text.replaceAll('.', '')) ?? 0;
    if (_isPercent) return p * (1 - d / 100);
    return p - d;
  }

  @override
  Widget build(BuildContext context) {
    double sellingPrice = _sellingPrice;
    int qty = int.tryParse(_qtyCtrl.text.replaceAll('.', '')) ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _buildSafeImage(widget.product.imagePath, size: 60),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Mã: ${widget.product.barcode} | Kho: ${widget.product.quantity}", style: const TextStyle(color: Colors.grey)),
              Text("Giá: ${currencyFormat.format(widget.product.price)}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ]),
          const Divider(height: 32),
          _buildRow("Số lượng", Row(children: [
            IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () {
              int v = int.tryParse(_qtyCtrl.text.replaceAll('.', '')) ?? 1;
              if (v > 1) {
                _qtyCtrl.text = NumberFormat.decimalPattern('vi_VN').format(v - 1);
                setState(() {});
              }
            }),
            SizedBox(width: 80, child: TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [CurrencyInputFormatter()],
                onChanged: (_) => setState((){}),
                decoration: const InputDecoration(border: OutlineInputBorder())
            )),
            IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () {
              int v = int.tryParse(_qtyCtrl.text.replaceAll('.', '')) ?? 0;
              _qtyCtrl.text = NumberFormat.decimalPattern('vi_VN').format(v + 1);
              setState(() {});
            }),
          ])),
          _buildRow("Đơn giá", SizedBox(width: 150, child: TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              inputFormatters: [CurrencyInputFormatter()],
              onChanged: (_) => setState((){}),
              decoration: const InputDecoration(suffixText: "đ")
          ))),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text("Giảm giá", style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 12),
                        ToggleButtons(
                          isSelected: [_isPercent, !_isPercent],
                          onPressed: (i) {
                            setState(() => _isPercent = i == 0);
                          },
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 35),
                          children: const [Text("%"), Text("đ")],
                        ),
                      ],
                    ),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _discountCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                inputFormatters: [CurrencyInputFormatter()],
                  onTap: () {
                    if (_discountCtrl.text.trim() == '0') {
                      _discountCtrl.clear();
                    }
                  },
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
              ),
            ),
          ])),
          _buildRow("Thành tiền", Text(currencyFormat.format(sellingPrice * qty), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 20))),
          const SizedBox(height: 12),
          TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: "Ghi chú", border: OutlineInputBorder())),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () {
            widget.onUpdate(OrderItem(
                productId: widget.item.productId,
                productName: widget.item.productName,
                price: double.tryParse(_priceCtrl.text.replaceAll('.', '')) ?? 0,
                importPrice: widget.item.importPrice,
                quantity: int.tryParse(_qtyCtrl.text.replaceAll('.', '')) ?? 1,
                discount: double.tryParse(_discountCtrl.text.replaceAll('.', '')) ?? 0,
                isDiscountPercentage: _isPercent,
                note: _noteCtrl.text
            ));
            Navigator.pop(context);
          }, style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), child: const Text("XÁC NHẬN"))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildRow(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(fontSize: 16)), child]),
    );
  }
}

class ProductSearchPage extends StatefulWidget {
  final List<Product> products;
  const ProductSearchPage({super.key, required this.products});
  @override
  State<ProductSearchPage> createState() => _ProductSearchPageState();
}

class _ProductSearchPageState extends State<ProductSearchPage> {
  late List<Product> _allProducts;
  List<Product> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = "Tất cả";
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _allProducts = widget.products;
    _filtered = _allProducts;
  }

  void _runFilter() {
    String query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allProducts.where((p) {
        bool matchSearch = p.name.toLowerCase().contains(query) || p.barcode.contains(query) || p.id.toLowerCase().contains(query);
        bool matchCat = _selectedCategory == "Tất cả" || p.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();
    });
  }

  void _showCategoryFilter() {
    Set<String> categories = {"Tất cả", ..._allProducts.map((e) => e.category)};
    showModalBottomSheet(
        context: context,
        builder: (ctx) => ListView(
          children: categories.map((c) => ListTile(
            title: Text(c),
            trailing: _selectedCategory == c ? const Icon(Icons.check, color: Colors.blue) : null,
            onTap: () {
              setState(() { _selectedCategory = c; });
              _runFilter();
              Navigator.pop(ctx);
            },
          )).toList(),
        )
    );
  }

  Future<void> _scanBarcode() async {
    // ignore: deprecated_member_use
    var res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SimpleBarcodeScannerPage()));
    if (res is String && res != '-1') {
      _searchCtrl.text = res;
      _runFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white, elevation: 0.5, titleSpacing: 0,
        title: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchCtrl, autofocus: true, onChanged: (_) => _runFilter(), decoration: const InputDecoration(hintText: "Tìm sản phẩm...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8))))),
          IconButton(icon: const Icon(Icons.add, color: Colors.blue), onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddProductPage()));
            if (res is Product) Navigator.pop(context, res);
          }),
          IconButton(icon: const Icon(Icons.filter_list, color: Colors.blue), onPressed: _showCategoryFilter),
          IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.blue), onPressed: _scanBarcode),
        ]),
      ),
      body: _filtered.isEmpty ? const Center(child: Text("Không có sản phẩm nào")) : ListView.builder(itemCount: _filtered.length, itemBuilder: (ctx, i) {
        final p = _filtered[i];
        return ListTile(
          leading: _buildSafeImage(p.imagePath, size: 50),
          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Mã: ${p.barcode} | Kho: ${p.quantity}"),
          trailing: Text(currencyFormat.format(p.price), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
          onTap: () => Navigator.pop(context, p),
        );
      }),
    );
  }
}

class CustomerSearchPage extends StatefulWidget {
  const CustomerSearchPage({super.key});
  @override
  State<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends State<CustomerSearchPage> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Customer> _all = [];
  List<Customer> _filtered = [];
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _listenCustomers();
  }

  void _listenCustomers() {
    _firestoreService.streamCustomers().listen((data) {
      if (mounted) {
        setState(() {
          _all = data;
          _runFilter(_searchCtrl.text);
        });
      }
    });
  }

  void _runFilter(String v) {
    setState(() => _filtered = _all.where((c) => c.name.toLowerCase().contains(v.toLowerCase()) || c.phone.contains(v)).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, backgroundColor: Colors.white, elevation: 0.5, titleSpacing: 0,
        title: Row(children: [
          IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
          Expanded(child: Container(height: 40, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: TextField(controller: _searchCtrl, autofocus: true, onChanged: _runFilter, decoration: const InputDecoration(hintText: "Tìm tên hoặc SĐT...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 8))))),
          IconButton(icon: const Icon(Icons.person_add, color: Colors.blue), onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AddCustomerPage()));
          }),
        ]),
      ),
      body: Column(
        children: [
          ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: const Text("Khách lẻ (Mặc định)"), onTap: () => Navigator.pop(context, null)),
          const Divider(height: 1),
          Expanded(child: ListView.builder(itemCount: _filtered.length, itemBuilder: (ctx, i) {
            final c = _filtered[i];
            return ListTile(
              leading: _buildSafeAvatar(c),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${c.phone.isNotEmpty ? c.phone : 'Không có SĐT'} • ${c.points} điểm"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                child: Text("${c.points} điểm", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              onTap: () => Navigator.pop(context, c),
            );
          })),
        ],
      ),
    );
  }
}

// =======================================================================
// HÀM HỖ TRỢ HIỂN THỊ ẢNH AN TOÀN TRÊN WEB (TRÁNH LỖI FILE SYSTEM)
// =======================================================================

Widget _buildSafeImage(String? path, {double size = 50}) {
  Widget placeholder = Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.image, color: Colors.grey)
  );
  if (path == null || path.isEmpty) return placeholder;

  // Bổ sung đọc Base64
  if (path.startsWith('data:image')) {
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(base64Decode(path.split(',').last), width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => placeholder),
      );
    } catch (_) {
      return placeholder;
    }
  }

  if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(path, width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => placeholder)
    );
  } else {
    try {
      if (File(path).existsSync()) {
        return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(File(path), width: size, height: size, fit: BoxFit.cover, errorBuilder: (c, e, s) => placeholder)
        );
      }
    } catch (e) {}
    return placeholder;
  }
}

Widget _buildSafeAvatar(Customer c) {
  Widget textAvatar = CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : "?"));
  if (c.imagePath.isEmpty) return textAvatar;

  if (kIsWeb || c.imagePath.startsWith('http') || c.imagePath.startsWith('blob:')) {
    return CircleAvatar(backgroundImage: NetworkImage(c.imagePath), onBackgroundImageError: (e, s) => textAvatar);
  } else {
    try {
      if (File(c.imagePath).existsSync()) {
        return CircleAvatar(backgroundImage: FileImage(File(c.imagePath)), onBackgroundImageError: (e, s) => textAvatar);
      }
    } catch (e) {
      // Bỏ qua lỗi
    }
    return textAvatar;
  }
}

// === BỘ ĐỊNH DẠNG SỐ THÔNG MINH ===
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    // Xóa mọi ký tự không phải là số (bao gồm cả dấu chấm cũ)
    String digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    // Chuyển thành số nguyên (tự động xóa số 0 ở đầu) và format có dấu chấm
    final int value = int.parse(digitsOnly);
    final String formatted = NumberFormat.decimalPattern('vi_VN').format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length), // Giữ con trỏ ở cuối
    );
  }
}