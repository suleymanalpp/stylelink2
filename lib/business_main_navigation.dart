import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/business/appointments_screen.dart';
import 'screens/business/my_shop_screen.dart';
import 'screens/business/profile_screen.dart';  // BarberProfileScreen burada

class BusinessMainNavigation extends StatefulWidget {
  const BusinessMainNavigation({super.key});

  @override
  State<BusinessMainNavigation> createState() => _BusinessMainNavigationState();
}

class _BusinessMainNavigationState extends State<BusinessMainNavigation> {
  int _selectedIndex = 0;
  late String _currentBarberId;

  @override
  void initState() {
    super.initState();
    _currentBarberId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const AppointmentsScreen(),
          const MyShopScreen(),
          BarberProfileScreen(barberId: _currentBarberId),  // Profil ekranı
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.amber[700],
        unselectedItemColor: Colors.grey,
        backgroundColor: const Color(0xFF0F0F0F),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Randevular',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: 'Dükkanım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}