import 'package:flutter/material.dart';
import '../../widgets/all_widgets.dart';

class MyAppointments extends StatelessWidget {
  const MyAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Randevularım', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AppointmentCard(
              title: 'Saç Kesimi',
              subtitle: 'Aslan Erkek Kuaför • 12 Mayıs 14:30',
              trailingText: 'Beklemede',
              onChat: () {},
              onCancel: () {},
            ),
            AppointmentCard(
              title: 'Ağda & Sakal',
              subtitle: 'Efe Barbershop • 18 Mayıs 16:00',
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
