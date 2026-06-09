import 'package:flutter/material.dart';

class CustomerChatList extends StatelessWidget {
  const CustomerChatList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Mesajlar', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: const Center(
        child: Text('Mesaj listeniz burada görünecek.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
