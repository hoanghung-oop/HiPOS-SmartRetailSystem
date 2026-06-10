// File: lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'sales_screen.dart';
import 'inventory_screen.dart';
import 'history_screen.dart';
import 'overview_screen.dart'; // Màn hình mới
import 'more_screen.dart';     // Màn hình mới

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Hàm chuyển tab (truyền cho MoreScreen dùng)
  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Danh sách 5 màn hình tương ứng 5 tab
    final List<Widget> screens = [
      const SalesScreen(),        // 0: Bán hàng
      const InventoryScreen(),    // 1: Hàng hóa (Kho)
      const HistoryScreen(),      // 2: Hóa đơn
      const OverviewScreen(),     // 3: Tổng quan (Báo cáo)
      MoreScreen(onTabChange: _switchTab), // 4: Nhiều hơn
    ];

    return Scaffold(
      // Dùng IndexedStack để giữ trạng thái các tab, hoặc dùng cách load trực tiếp tùy bạn.
      // Ở đây dùng load trực tiếp để đảm bảo dữ liệu mới nhất (như bài trước).
      body: screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed, // Bắt buộc fixed vì có 5 tab
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Bán hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: 'Hàng hóa'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Hóa đơn'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Tổng quan'),
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: 'Nhiều hơn'),
        ],
      ),
    );
  }
}