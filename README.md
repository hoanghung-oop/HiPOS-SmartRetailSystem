# HiPOS - Hệ Thống Quản Lý Bán Hàng Thông Minh (Smart POS with AI Integration)

HiPOS là giải pháp phần mềm quản lý bán lẻ đa nền tảng (Mobile & Web) được phát triển trên nền tảng **Flutter**, tích hợp hạ tầng không máy chủ **Firebase BaaS** và Trí tuệ nhân tạo **Google Gemini 2.5 Flash**. Hệ thống giải quyết toàn diện bài toán tự động hóa vận hành, kiểm soát dòng tiền, thẩm định sản phẩm và cố vấn kinh doanh cho các mô hình bán lẻ vừa và nhỏ.

---

## 🌟 Tính Năng Nổi Bật (Key Features)

- **Voice POS Pipeline:** Nhận diện và bóc tách ngôn ngữ tự nhiên tiếng Việt (tự động khử dấu, tách mệnh đề liên từ và trích xuất số lượng hàng hóa), hỗ trợ lên đơn rảnh tay tại quầy thu ngân.
- **Thanh toán VietQR động chuẩn NAPAS 247:** Tự động sinh mã chuyển khoản định danh kèm số tiền thực tế theo thời gian thực; hỗ trợ linh hoạt luồng thanh toán Đa phương thức (tiền mặt + chuyển khoản).
- **Thẩm định hàng hóa qua Multimodal AI (Gemini Vision):** Chụp ảnh bao bì sản phẩm để phân tích thương hiệu, ước tính khoảng giá thị trường, cảnh báo hàng giả và tự động nạp dữ liệu vào form tạo hàng.
- **Toàn vẹn giao dịch (Atomic Batch Write):** Sử dụng cơ chế WriteBatch trên Cloud Firestore đảm bảo cập nhật đồng bộ 4 thực thể: Hóa đơn, Tồn kho sản phẩm, Sổ quỹ thu chi và Điểm tích lũy thành viên (tuân thủ nghiêm ngặt nguyên tắc ACID).
- **Trợ lý Cố vấn Chiến lược Bán lẻ (AI CSO):** Hội thoại hai chiều thông minh, tự động tiêm ngữ cảnh vận hành (doanh thu trong ngày, tồn kho, mặt hàng chủ lực) để đưa ra các đề xuất kinh doanh theo mùa vụ.
- **Tối ưu hóa tài nguyên (Smart Caching):** Áp dụng Cache-Aside Pattern với SharedPreferences cho Điểm tin hàng ngày, giảm thiểu tối đa chi phí hạn ngạch API.
- **Bảo mật cấu hình tài chính:** Cơ chế xác thực mã PIN 4 chữ số nội bộ ngăn chặn rủi ro gian lận tráo đổi tài khoản ngân hàng thụ hưởng.

---

## 🏗️ Kiến Trúc Hệ Thống (Architecture & Tech Stack)

- **Framework:** [Flutter](https://flutter.dev/) (Dart $\ge$ 3.0.0, Sound Null Safety)
- **Kiến trúc:** Layered Architecture kết hợp mô hình Boundary-Control-Entity (BCE)
- **Cơ sở dữ liệu:** [Cloud Firestore](https://firebase.google.com/docs/firestore) (Mô hình phân vùng đa người dùng Multi-tenant: `users/{userId}/*`)
- **Xác thực:** [Firebase Authentication](https://firebase.google.com/docs/auth)
- **Trí tuệ nhân tạo:** [Google Gemini API](https://ai.google.dev/) (`gemini-2.5-flash`) qua thư viện `google_generative_ai`
- **Bộ nhớ đệm cục bộ:** `shared_preferences`
- **Xử lý âm thanh:** `speech_to_text`
- **Cổng thanh toán:** API VietQR Switch

---

## 🚀 Cài Đặt Và Khởi Chạy (Installation & Setup)

### 1. Yêu cầu tiên quyết
- Flutter SDK $\ge 3.19.0$
- Dart SDK $\ge 3.0.0$
- Công cụ biên dịch: Android Studio / VS Code
- Tài khoản [Google AI Studio](https://aistudio.google.com/) để lấy `GEMINI_API_KEY`
- Dự án trên [Firebase Console](https://console.firebase.google.com/)

### 2. Cài đặt mã nguồn
```bash
# Clone repository
git clone [https://github.com/your-username/HiPOS-SmartRetailSystem.git](https://github.com/your-username/HiPOS-SmartRetailSystem.git)

# Di chuyển vào thư mục dự án
cd HiPOS-SmartRetailSystem

# Cài đặt các gói thư viện phụ thuộc
flutter pub get
