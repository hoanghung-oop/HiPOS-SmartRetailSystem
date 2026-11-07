// File: lib/screens/ai_scout_report_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ai_service.dart';

class AiScoutReportScreen extends StatefulWidget {
  // ĐÃ SỬA: Nhận XFile thay vì File để tương thích mọi nền tảng
  final XFile capturedImage;

  const AiScoutReportScreen({super.key, required this.capturedImage});

  @override
  State<AiScoutReportScreen> createState() => _AiScoutReportScreenState();
}

class _AiScoutReportScreenState extends State<AiScoutReportScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _aiReport = {};
  Uint8List? _imageBytes; // Dữ liệu bytes để hiển thị an toàn trên cả Web và Mobile

  @override
  void initState() {
    super.initState();
    _loadImageBytes();
    _startAiAnalysis();
  }

  // Đọc bytes ảnh để hiển thị không bị lỗi trên Web
  Future<void> _loadImageBytes() async {
    final bytes = await widget.capturedImage.readAsBytes();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  Future<void> _startAiAnalysis() async {
    // Gọi hàm phân tích ảnh từ ai_service.dart (truyền XFile)
    final result = await AIService().analyzeScoutImage(widget.capturedImage);

    if (mounted) {
      setState(() {
        _aiReport = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("🔍 Báo cáo thẩm định AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.amber[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildReportState(),

      bottomNavigationBar: _isLoading ? null : SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Dữ liệu sẽ được tự động điền vào Form tạo mới!"))
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_business),
                SizedBox(width: 8),
                Text("TẠO MÃ SẢN PHẨM NÀY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // GIAO DIỆN KHI ĐANG CHỜ AI (LOADING)
  // --------------------------------------------------------
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _imageBytes != null
                ? Image.memory(_imageBytes!, width: 200, height: 200, fit: BoxFit.cover)
                : Container(
              width: 200,
              height: 200,
              color: Colors.grey[300],
              child: const Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),
          const CircularProgressIndicator(color: Colors.amber),
          const SizedBox(height: 20),
          const Text(
            "AI đang quét dữ liệu thị trường...\nVui lòng chờ trong giây lát.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // GIAO DIỆN KHI CÓ KẾT QUẢ
  // --------------------------------------------------------
  Widget _buildReportState() {
    Color verdictColor = Colors.green;
    IconData verdictIcon = Icons.check_circle;

    String khuyenNghi = _aiReport['khuyen_nghi'] ?? 'RỦI RO';

    if (khuyenNghi == "CÂN NHẮC") {
      verdictColor = Colors.orange;
      verdictIcon = Icons.warning_rounded;
    } else if (khuyenNghi == "RỦI RO") {
      verdictColor = Colors.red;
      verdictIcon = Icons.cancel;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
              image: _imageBytes != null
                  ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                  : null,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 20),

          Text(_aiReport['ten_san_pham'] ?? 'Không xác định', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.2)),
          const SizedBox(height: 4),
          Text("Thương hiệu: ${_aiReport['thuong_hieu'] ?? 'N/A'}", style: TextStyle(fontSize: 16, color: Colors.grey[700])),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: verdictColor.withOpacity(0.1),
              border: Border.all(color: verdictColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(verdictIcon, color: verdictColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Đánh giá từ AI:", style: TextStyle(fontSize: 12, color: verdictColor)),
                      Text(khuyenNghi, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: verdictColor)),
                    ],
                  ),
                )
              ],
            ),
          ),

          const SizedBox(height: 20),

          _buildInfoCard(icon: Icons.monetization_on, iconColor: Colors.blue, title: "Khoảng giá bán lẻ", content: _aiReport['gia_ban_le_uoc_tinh'] ?? '', isHighlight: true),
          const SizedBox(height: 12),
          _buildInfoCard(icon: Icons.trending_up, iconColor: Colors.deepPurple, title: "Thị hiếu & Độ Hot", content: _aiReport['do_hot_thi_truong'] ?? ''),
          const SizedBox(height: 12),
          _buildInfoCard(icon: Icons.security, iconColor: Colors.redAccent, title: "Cảnh báo Hàng giả", content: _aiReport['dau_hieu_nhan_biet_hang_gia'] ?? ''),
          const SizedBox(height: 12),
          _buildInfoCard(icon: Icons.lightbulb, iconColor: Colors.orange, title: "Lời khuyên Kinh doanh", content: _aiReport['loi_khuyen_kinh_doanh'] ?? ''),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String title, required String content, bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                    content,
                    style: TextStyle(
                        fontSize: isHighlight ? 18 : 15,
                        fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                        color: isHighlight ? Colors.blue[800] : Colors.black87,
                        height: 1.4
                    )
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}