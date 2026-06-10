import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Hàm xử lý đăng ký tài khoản
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mật khẩu xác nhận không khớp!"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        // 1. Tạo tài khoản trên Firebase
        UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // 2. Cập nhật tên hiển thị của người dùng
        await credential.user?.updateDisplayName(_nameController.text.trim());

        // 3. ĐĂNG XUẤT NGAY LẬP TỨC để yêu cầu đăng nhập lại
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          // Thông báo thành công và điều hướng về màn hình Login
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Đăng ký thành công! Vui lòng đăng nhập lại."),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context); // Đóng màn hình đăng ký
        }
      } on FirebaseAuthException catch (e) {
        String message = "Lỗi đăng ký";
        if (e.code == 'email-already-in-use') message = "Email này đã được sử dụng";
        if (e.code == 'weak-password') message = "Mật khẩu quá yếu";
        if (e.code == 'invalid-email') message = "Định dạng email không đúng";

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade900, Colors.blue.shade500],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  const Icon(Icons.person_add_rounded, size: 80, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    "TẠO TÀI KHOẢN",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Text(
                    "Bắt đầu hành trình quản lý kinh doanh của bạn",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    width: screenWidth * 0.9,
                    constraints: const BoxConstraints(maxWidth: 450),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: "Họ và tên",
                            icon: Icons.badge_outlined,
                            validator: (v) => v!.isEmpty ? "Vui lòng nhập họ và tên" : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _emailController,
                            label: "Email",
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.contains('@') ? null : "Vui lòng nhập email hợp lệ",
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            label: "Mật khẩu",
                            icon: Icons.lock_outline,
                            isPassword: true,
                            isPasswordVisible: _isPasswordVisible,
                            onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            validator: (v) => v!.length < 6 ? "Mật khẩu tối thiểu 6 ký tự" : null,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: "Xác nhận mật khẩu",
                            icon: Icons.lock_reset_outlined,
                            isPassword: true,
                            isPasswordVisible: _isPasswordVisible,
                            onToggleVisibility: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                            validator: (v) => v!.isEmpty ? "Vui lòng xác nhận mật khẩu" : null,
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text("ĐĂNG KÝ NGAY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Đã có tài khoản? ", style: TextStyle(color: Colors.white)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "Đăng nhập",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !isPasswordVisible,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600),
        prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 22),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 20),
          onPressed: onToggleVisibility,
        )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}