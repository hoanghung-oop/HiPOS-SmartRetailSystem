// File: lib/services/ai_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class AIService {

  late final GenerativeModel _model;
  final currencyFormat = NumberFormat.currency(
      locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  AIService() {
    const webApiKey = String.fromEnvironment(
        'GEMINI_API_KEY', defaultValue: '');

    final finalApiKey = webApiKey.isNotEmpty ? webApiKey : (dotenv
        .env['GEMINI_API_KEY'] ?? '');

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: finalApiKey,
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
      ],
    );
  }

  // ---------------------------------------------------------
  // 1. CỐ VẤN KINH DOANH (Chatbot AI) - ĐÃ BỔ SUNG AUTO RETRY
  // ---------------------------------------------------------
  Future<String> askGemini(String userPrompt, List<Product> currentProducts,
      List<OrderModel> recentOrders) async {
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    double totalRevenue = recentOrders.fold(
        0, (sum, item) => sum + item.totalPrice);
    int orderCount = recentOrders.length;
    double totalInventoryValue = currentProducts.fold(
        0, (sum, p) => sum + (p.importPrice * p.quantity));
    int totalItems = currentProducts.fold(0, (sum, p) => sum + p.quantity);

    String productStr = currentProducts.isEmpty
        ? "Kho đang trống."
        : currentProducts.take(30).map((p) => '${p.name} (Tồn: ${p
        .quantity}, Giá: ${currencyFormat.format(p.price)})').join('; ');

    final String context = '''
    Đóng vai Giám đốc Chiến lược Bán lẻ (CSO) và Cố vấn tài chính xuất sắc nhất.
    Hôm nay là ngày: $currentDate (Hãy dùng thông tin này để tư vấn theo mùa vụ, lễ hội, xu hướng).
    
    TÌNH HÌNH CỬA HÀNG HIỆN TẠI:
    - Đơn hàng hôm nay: $orderCount đơn. Doanh thu: ${currencyFormat.format(
        totalRevenue)}.
    - Tổng vốn đang đọng trong kho: ${currencyFormat.format(
        totalInventoryValue)} ($totalItems sản phẩm).
    - Tóm tắt danh sách hàng hóa: $productStr.

    NHIỆM VỤ:
    Bạn đang chat trực tiếp với Chủ cửa hàng. Chủ cửa hàng sẽ hỏi bạn các câu hỏi.
    Hãy phân tích dữ liệu trên kết hợp với kiến thức kinh doanh thực tế của bạn để trả lời.
    - Xưng hô: Xưng "Tôi" (Trợ lý/Cố vấn) và gọi người dùng là "Bạn" hoặc "Chủ cửa hàng".
    - Phong cách: Trả lời rõ ràng, chuyên nghiệp, đưa ra số liệu dẫn chứng và các bước hành động cụ thể (Actionable Insights).
    - Nếu người dùng hỏi về hàng hóa nên nhập, hãy căn cứ vào ngày tháng hiện tại ($currentDate) để gợi ý các mặt hàng hot sắp tới (VD: Trung thu, Lễ tết, Hè...).
    - Định dạng phản hồi: Trình bày văn bản rõ ràng, KHÔNG dùng các dấu hoa thị * hay markdown thô, dùng các số thứ tự 1., 2., 3. và dấu gạch ngang đầu dòng để liệt kê ý.
    '''
    ;


    int maxRetries = 2;
    while (true) {
      try {
        final response = await _model.generateContent([
          Content.text(context),
          Content.text("Câu hỏi của Chủ cửa hàng: $userPrompt")
        ]).timeout(const Duration(seconds: 30));

        return response.text ??
            "Xin lỗi, tôi không thể phân tích dữ liệu lúc này.";
      } catch (e) {
        if (maxRetries == 0) {
          return "Hệ thống AI đang quá tải hoặc lỗi mạng. Vui lòng thử lại sau ít phút!\n(Chi tiết: $e)";
        }
        maxRetries--;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // ---------------------------------------------------------
  // 2. THẨM ĐỊNH SẢN PHẨM (AI Scout / Vision) - HỖ TRỢ CẢ WEB VÀ MOBILE
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> analyzeScoutImage(XFile image) async {
    try {
      // XFile có hàm readAsBytes() chạy mượt trên cả Web lẫn Mobile
      final imageBytes = await image.readAsBytes();
      final mimeType = image.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final promptText = TextPart('''
      Phân tích sản phẩm và trả về JSON hợp lệ. KHÔNG giải thích thêm:
      {"ten_san_pham": "Tên", "thuong_hieu": "Hiệu", "khuyen_nghi": "NÊN NHẬP", "gia_ban_le_uoc_tinh": "Giá", "do_hot_thi_truong": "Hot", "dau_hieu_nhan_biet_hang_gia": "Giả", "loi_khuyen_kinh_doanh": "Khuyên"}
      ''');

      int maxRetries = 2;
      while (true) {
        try {
          final response = await _model.generateContent([
            Content.multi([promptText, DataPart(mimeType, imageBytes)])
          ]).timeout(const Duration(seconds: 20));

          String responseText = response.text ?? "";

          int start = responseText.indexOf('{');
          int end = responseText.lastIndexOf('}');

          if (start != -1 && end != -1) {
            String jsonStr = responseText.substring(start, end + 1);
            return jsonDecode(jsonStr);
          }
          throw Exception("AI trả về sai định dạng, không tìm thấy object JSON.");
        } catch (e) {
          if (maxRetries == 0) {
            return {
              "ten_san_pham": "Không thể thẩm định",
              "khuyen_nghi": "CHỜ XỬ LÝ",
              "loi_khuyen_kinh_doanh": "Chuyên viên Thẩm định hiện đang bận hỗ trợ các phiên làm việc khác. Vui lòng thử lại sau."
            };
          }
          maxRetries--;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (fileError) {
      return {
        "ten_san_pham": "Lỗi đọc ảnh",
        "khuyen_nghi": "CHỜ XỬ LÝ",
        "loi_khuyen_kinh_doanh": "Không thể đọc dữ liệu ảnh trên thiết bị."
      };
    }
  }

  // ---------------------------------------------------------
  // 3. GỢI Ý BÁN CHÉO (Cross-Selling) - AUTO RETRY
  // ---------------------------------------------------------
  Future<List<String>> getCrossSellSuggestions(List<String> cartItemNames,
      List<Product> inventory) async {
    if (cartItemNames.isEmpty || inventory.isEmpty) return [];

    List<String> availableItems = inventory.map((p) => p.name).where((
        name) => !cartItemNames.contains(name)).take(30).toList();
    String inventoryStr = availableItems.join(', ');
    String cartStr = cartItemNames.join(', ');

    final String prompt = '''
    Nhiệm vụ: Gợi ý 3 sản phẩm bán kèm.
    Khách mua: $cartStr. 
    Kho đang có: $inventoryStr.
    
    Yêu cầu BẮT BUỘC:
    1. Chỉ chọn món CÓ SẴN trong Kho.
    2. Trả về đúng định dạng mảng JSON hợp lệ, BẮT BUỘC dùng dấu ngoặc kép ("). Không dùng dấu nháy đơn.
    3. Tuyệt đối không giải thích, không dùng markdown.
    
    Ví dụ đúng: ["Mực khô", "Lạc"]
    ''';

    int maxRetries = 2;

    while (true) {
      try {
        final response = await _model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 10));
        String responseText = response.text ?? "";

        int start = responseText.indexOf('[');
        int end = responseText.lastIndexOf(']');

        if (start != -1 && end != -1) {
          String jsonStr = responseText.substring(start, end + 1);
          List<dynamic> parsedList = jsonDecode(jsonStr);
          return parsedList.map((e) => e.toString()).toList();
        }

        throw Exception("AI trả về sai định dạng, không tìm thấy mảng JSON.");
      } catch (e) {
        if (maxRetries == 0) {
          print("Lỗi AI Gợi ý chéo (Đã thử lại hết mức): $e");
          return ["Lỗi Mạng"];
        }
        maxRetries--;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // ---------------------------------------------------------
  // 4. ĐIỂM TIN AI TỔNG QUAN (Daily Business Briefing) - AUTO RETRY & CACHE 1 NGÀY
  // ---------------------------------------------------------
  Future<Map<String, dynamic>> getDailyBusinessBriefing(List<Product> products,
      double todayRevenue) async {
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // BƯỚC 1: KIỂM TRA BỘ NHỚ ĐỆM (CACHE) TRƯỚC
    try {
      final prefs = await SharedPreferences.getInstance();
      String? savedDate = prefs.getString('ai_briefing_date');

      // Nếu hôm nay đã lấy điểm tin rồi, lập tức trả về dữ liệu cũ không cần gọi API
      if (savedDate == currentDate) {
        String? savedData = prefs.getString('ai_briefing_data');
        if (savedData != null) {
          return jsonDecode(savedData);
        }
      }
    } catch (e) {
      print("Lỗi đọc cache AI: $e");
    }

    // BƯỚC 2: NẾU CHƯA CÓ HOẶC QUA NGÀY MỚI, BẮT ĐẦU GỌI API
    String currentMonth = DateFormat('MM/yyyy').format(DateTime.now());
    double totalInventoryValue = products.fold(
        0, (sum, p) => sum + (p.importPrice * p.quantity));
    int totalItems = products.fold(0, (sum, p) => sum + p.quantity);

    Product? highestStockProduct;
    if (products.isNotEmpty) {
      highestStockProduct = products.reduce((curr, next) =>
      curr.quantity > next.quantity
          ? curr
          : next);
    }

    String stockContext = highestStockProduct != null
        ? "Tồn kho nhiều nhất: ${highestStockProduct
        .name} (${highestStockProduct.quantity} cái)."
        : "Kho đang trống.";

    final String prompt = '''
    Đóng vai Cố vấn Chiến lược Kinh doanh xuất sắc nhất Việt Nam.
    Hôm nay là ngày: $currentDate. Tháng: $currentMonth.
    Tình hình cửa hàng: Doanh thu hôm nay ${currencyFormat.format(todayRevenue)}. 
    Tổng giá trị vốn đang nằm trong kho: ${currencyFormat.format(
        totalInventoryValue)} ($totalItems sản phẩm).
    $stockContext
    
    Nhiệm vụ: Dựa vào ngày tháng hiện tại (để đoán mùa vụ/lễ hội sắp tới) và tình hình kho hàng, hãy đưa ra 1 lời khuyên kinh doanh ĐỘT PHÁ nhất cho chủ quán hôm nay.
    
    TRẢ VỀ ĐÚNG ĐỊNH DẠNG JSON SAU, BẮT BUỘC DÙNG DẤU NGOẶC KÉP, KHÔNG GIẢI THÍCH:
    {
      "tieu_de": "Tóm tắt cực ngắn (dưới 12 chữ, giật tít. Ví dụ: 'Sắp Trung Thu, cân nhắc nhập bánh!')",
      "phan_tich": "Phân tích chi tiết lý do (khoảng 3 câu. Đề cập đến xu hướng thị trường, mùa vụ hoặc rủi ro đọng vốn)",
      "hanh_dong": "Đề xuất 1 hành động cụ thể cho hôm nay (Ví dụ: 'Tạo combo giảm giá món X')"
    }
    ''';

    int maxRetries = 2;

    while (true) {
      try {
        final response = await _model
            .generateContent([Content.text(prompt)])
            .timeout(const Duration(seconds: 15));
        String responseText = response.text ?? "";

        int start = responseText.indexOf('{');
        int end = responseText.lastIndexOf('}');

        if (start != -1 && end != -1) {
          String jsonStr = responseText.substring(start, end + 1);

          // BƯỚC 3: LƯU LẠI KẾT QUẢ VÀO BỘ NHỚ ĐỂ DÙNG CHO CÁC LẦN MỞ APP SAU TRONG NGÀY
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('ai_briefing_date', currentDate); // Lưu ngày
            await prefs.setString(
                'ai_briefing_data', jsonStr); // Lưu nội dung JSON
          } catch (e) {
            print("Lỗi lưu cache AI: $e");
          }

          return jsonDecode(jsonStr);
        }

        throw Exception("AI trả về sai định dạng, không tìm thấy object JSON.");
      } catch (e) {
        if (maxRetries == 0) {
          print("Lỗi AI Điểm tin (Đã thử lại hết mức): $e");
          return _fallbackBriefing();
        }
        maxRetries--;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // Dữ liệu dự phòng với thông điệp Thân thiện / Nhập vai (Roleplay)
  Map<String, dynamic> _fallbackBriefing() {
    return {
      "tieu_de": "Thông báo từ Cố vấn",
      "phan_tich": "Đường truyền đến trung tâm dữ liệu AI đang gián đoạn, dữ liệu doanh thu của bạn vẫn được bảo mật và lưu an toàn.",
      "hanh_dong": "Cố vấn Chiến lược sẽ tự động cập nhật lại báo cáo khi kết nối máy chủ ổn định."
    };
  }
}