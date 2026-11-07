// File: lib/services/local_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';
import '../models/transaction_model.dart';

class LocalStorage {

  // 1. Lưu trạng thái Dark Mode (Giao diện Sáng/Tối)
  static Future<void> saveThemeMode(bool isDark) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_dark_mode', isDark);
  }

  static Future<bool> loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('is_dark_mode') ?? false; // Mặc định là Light mode
  }

  // 2. Lưu ngôn ngữ ứng dụng
  static Future<void> saveLanguage(String langCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_language', langCode);
  }

  static Future<String> loadLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('app_language') ?? 'vi'; // Mặc định tiếng Việt
  }

  // 3. Lưu lần đầu mở app
  static Future<void> setFirstRun(bool isFirst) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('is_first_run', isFirst);
  }

  static Future<bool> isFirstRun() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('is_first_run') ?? true;
  }
}