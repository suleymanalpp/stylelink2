import 'package:flutter/material.dart';

class CustomerNotificationScreen extends StatelessWidget {
  const CustomerNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Bildirimler', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: const Center(
        child: Text('Henüz yeni bildiriminiz yok.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
