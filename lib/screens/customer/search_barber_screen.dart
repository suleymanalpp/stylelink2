import 'package:flutter/material.dart';
import '../../models/all_models.dart';
import '../../widgets/all_widgets.dart';
import 'barber_profile_view_screen.dart';

class SearchBarberScreen extends StatelessWidget {
  const SearchBarberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Berber Ara', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const TextField(
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  hintText: 'Berber veya salon adı ara',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: 3,
                itemBuilder: (context, index) {
                  return BarberCard(
                    barber: BarberModel(
                      uid: '1',
                      name: 'Mehmet Usta',
                      shopName: 'Aslan Erkek Kuaför',
                      email: 'mehmet@example.com',
                      phone: '+905551234567',
                      rating: 4.8,
                      reviewCount: 120,
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BarberProfileViewScreen()));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
