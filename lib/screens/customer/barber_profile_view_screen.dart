import 'package:flutter/material.dart';
import 'create_appointment_screen.dart';

class BarberProfileViewScreen extends StatelessWidget {
  const BarberProfileViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Berber Detayı', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aslan Erkek Kuaför', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Mehmet Usta • 4.8 değerlendirme', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateAppointmentScreen()));
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
              child: const Text('Randevu Oluştur', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
