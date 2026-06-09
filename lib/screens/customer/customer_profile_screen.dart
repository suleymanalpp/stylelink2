import 'package:flutter/material.dart';

class CustomerProfileScreen extends StatelessWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Profilim', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_outline, size: 80, color: Colors.white54),
            SizedBox(height: 16),
            Text('Müşteri Profili', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Profilinizi buradan düzenleyebilirsiniz.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
