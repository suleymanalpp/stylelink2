import 'package:flutter/material.dart';

class MyShopScreen extends StatelessWidget {
  const MyShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Dükkanım', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Aslan Erkek Kuaför', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Müşteri randevularını ve hizmetlerini bu ekrandan yönetebilirsiniz.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
