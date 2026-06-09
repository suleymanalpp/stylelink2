import 'package:flutter/material.dart';
import '../../widgets/all_widgets.dart';

class MainPageScreen extends StatelessWidget {
  const MainPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Hoşgeldiniz', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SectionHeader(title: 'Öne Çıkan Berberler'),
            SizedBox(height: 12),
            Text('Favori berberinizi seçin ve randevunuzu hemen oluşturun.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
