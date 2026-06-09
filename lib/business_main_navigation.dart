import 'package:flutter/material.dart';
import 'screens/business/appointments_screen.dart';
import 'screens/business/my_shop_screen.dart';
import 'screens/business/profile_screen.dart';

class BusinessMainNavigation extends StatefulWidget {
  const BusinessMainNavigation({super.key});

  @override
  State<BusinessMainNavigation> createState() => _BusinessMainNavigationState();
}

class _BusinessMainNavigationState extends State<BusinessMainNavigation> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    AppointmentsScreen(),
    MyShopScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.amber.shade700,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Randevular'),
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Dükkanım'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}
