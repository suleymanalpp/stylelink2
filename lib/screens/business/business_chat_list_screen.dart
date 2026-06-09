import 'package:flutter/material.dart';

class BusinessChatListScreen extends StatelessWidget {
  const BusinessChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Mesajlarım', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: const Center(
        child: Text('Müşterilerinizle olan mesajlar buraya gelecek.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
