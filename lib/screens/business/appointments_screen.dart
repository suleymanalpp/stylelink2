import 'package:flutter/material.dart';
import '../../widgets/all_widgets.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Randevular', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AppointmentCard(
              title: 'Ali Yılmaz',
              subtitle: 'Saç Kesimi • 24 Mayıs 11:00',
              trailingText: 'Beklemede',
              onChat: () {},
              onCancel: () {},
            ),
            AppointmentCard(
              title: 'Ayşe Demir',
              subtitle: 'Sakal Bakımı • 25 Mayıs 14:00',
              trailingText: 'Onaylandı',
              onChat: () {},
              onCancel: () {},
            ),
          ],
        ),
      ),
    );
  }
}
