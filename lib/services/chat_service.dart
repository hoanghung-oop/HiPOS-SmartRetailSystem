// File: lib/services/chat_service.dart
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class ChatService {
  // LƯU Ý BẢO MẬT: Tạm thời để key ở đây để test. Khi nào đưa app lên mạng thật sự, 
  // hãy áp dụng kỹ thuật file .env như chúng ta đã bàn nhé!
  static const String _apiKey = 'AIzaSyA2RG6W0NK3PhMVBnFWHaZ-lq4OIhTA6U8';

  final GenerativeModel _model;
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  ChatService() : _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);

  Future<String> askGemini(String userPrompt, List<Product> currentProducts, List<OrderModel> recentOrders) async {
    try {
      // 1. Tính toán tổng doanh thu
      double totalRevenue = recentOrders.fold(0, (sum, item) => sum + item.totalPrice);
      int orderCount = recentOrders.length;

      // 2. TỐI ƯU HÓA DỮ LIỆU SẢN PHẨM: Giới hạn tối đa 20 sản phẩm để gửi đi cho nhẹ mạng
      String productStr = "";
      if (currentProducts.isEmpty) {
        productStr = "Kho đang trống.";
      } else if (currentProducts.length > 20) {
        // Nếu lớn hơn 20, chỉ lấy 20 cái đầu tiên và báo cho AI biết còn nữa
        productStr = currentProducts.take(20).map((p) => '${p.name} (Giá: ${currencyFormat.format(p.price)}, Tồn: ${p.quantity})').join('; ');
        productStr += "... (và ${currentProducts.length - 20} sản phẩm khác).";
      } else {
        productStr = currentProducts.map((p) => '${p.name} (Giá: ${currencyFormat.format(p.price)}, Tồn: ${p.quantity})').join('; ');
      }

      // 3. Xây dựng Context gọn gàng
      final String context = "Bạn là trợ lý ảo AI thông minh của phần mềm quản lý cửa hàng kinh doanh. "
          "Dữ liệu cửa hàng hiện tại: "
          "- Kho hàng hóa: $productStr. "
          "- Tình hình kinh doanh: $orderCount đơn hàng, tổng doanh thu đạt ${currencyFormat.format(totalRevenue)}. "
          "Yêu cầu: Trả lời ngắn gọn, chuyên nghiệp, đưa ra số liệu ngay lập tức.";

      final content = [
        Content.text(context),
        Content.text(userPrompt),
      ];

      // Thêm timeout (thời gian chờ tối đa) để không bị treo app
      final response = await _model.generateContent(content).timeout(const Duration(seconds: 100));
      return response.text ?? "Xin lỗi, tôi không thể phân tích dữ liệu lúc này.";

    } catch (e) {
      return "Lỗi kết nối AI: Do mạng chậm.\nChi tiết: $e";
    }
  }
}