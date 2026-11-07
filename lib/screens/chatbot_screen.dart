// File: lib/screens/chatbot_screen.dart
import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/firestore_service.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final AIService _chatService = AIService();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController(); // Thêm ScrollController

  final List<Map<String, String>> _messages = [
    {'role': 'ai', 'message': 'Xin chào! Tôi là trợ lý AI của cửa hàng. Hôm nay bạn cần phân tích tình hình kinh doanh hay cần tư vấn về hàng hóa?'}
  ];

  List<Product> _currentProducts = [];
  List<OrderModel> _completedOrders = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    // Lắng nghe dữ liệu sản phẩm
    _firestoreService.streamProducts().listen((data) {
      if (mounted) setState(() => _currentProducts = data);
    });

    // Lắng nghe dữ liệu hóa đơn đã thanh toán để báo cáo doanh thu
    _firestoreService.streamOrders('completed').listen((data) {
      if (mounted) setState(() => _completedOrders = data);
    });
  }

  // Hàm tự động cuộn xuống tin nhắn mới nhất
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    if (_messageCtrl.text.trim().isEmpty) return;
    String userText = _messageCtrl.text.trim();

    setState(() {
      _messages.add({'role': 'user', 'message': userText});
      _isTyping = true;
    });

    _messageCtrl.clear();
    _scrollToBottom(); // Cuộn xuống khi user gửi

    // Gọi AI phân tích và truyền toàn bộ dữ liệu thực tế vào
    String response = await _chatService.askGemini(userText, _currentProducts, _completedOrders);

    if (mounted) {
      setState(() {
        _messages.add({'role': 'ai', 'message': response});
        _isTyping = false;
      });
      _scrollToBottom(); // Cuộn xuống khi AI trả lời xong
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 8),
            Text("Trợ lý AI"),
          ],
        ),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView.builder(
                controller: _scrollController, // Gắn Controller vào đây
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (ctx, i) => _buildChatBubble(_messages[i]),
              )
          ),
          if (_isTyping)
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Đang suy nghĩ...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                )
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  String _cleanMarkdown(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^\s*\*\s*', multiLine: true), '• ')
        .replaceAll('_', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  Widget _buildChatBubble(Map<String, String> msg) {
    bool isAi = msg['role'] == 'ai';
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: isAi ? Colors.white : Colors.blue[600],
            borderRadius: BorderRadius.circular(18).copyWith(
              bottomLeft: isAi ? const Radius.circular(4) : const Radius.circular(18),
              bottomRight: isAi ? const Radius.circular(18) : const Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
            ]
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(
            isAi ? _cleanMarkdown(msg['message']!) : msg['message']!,
            style: TextStyle(
              color: isAi ? Colors.black87 : Colors.white,
              fontSize: 15,
              height: 1.4,
            )
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5))
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _messageCtrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(), // Hỗ trợ bấm nút Enter trên bàn phím để gửi
                  decoration: InputDecoration(
                    hintText: "Hỏi về tồn kho, doanh thu...",
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  )
              )
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(color: Colors.blue[600], shape: BoxShape.circle),
            child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage
            ),
          ),
        ]),
      ),
    );
  }
}