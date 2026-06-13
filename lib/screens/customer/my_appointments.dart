import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'barber_profile_view_screen.dart';

// ==================== MODEL ====================

class Appointment {
  final String id;
  final String barberId;
  final String barberName;
  final String barberShopName;
  final String? barberImageUrl;
  final String serviceName;
  final double price;
  final DateTime dateTime;
  final String status;

  Appointment({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.barberShopName,
    this.barberImageUrl,
    required this.serviceName,
    required this.price,
    required this.dateTime,
    required this.status,
  });
}

// ==================== FIREBASE ====================

class AppointmentFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔥 CANLI AKIŞ (STREAM) - ANLIK GÜNCELLEME İÇİN
  Stream<List<Appointment>> streamMyAppointments() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('appointments')
        .where('customerId', isEqualTo: uid)
        .snapshots()
        .asyncMap((snapshot) async {
          List<Appointment> list = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final barberId = data['barberId'];

            String barberName = "Berber";
            String barberShopName = "Dükkan";
            String? image;

            if (barberId != null && barberId.isNotEmpty) {
              final barberDoc = await _firestore.collection('users').doc(barberId).get();
              final b = barberDoc.data();

              barberName = b?['nameSurname'] ?? "Berber";
              barberShopName = b?['shopName'] ?? "Dükkan";
              image = b?['profileImageUrl'];
            }

            list.add(Appointment(
              id: doc.id,
              barberId: barberId ?? '',
              barberName: barberName,
              barberShopName: barberShopName,
              barberImageUrl: image,
              serviceName: data['serviceName'] ?? '',
              price: (data['price'] ?? 0).toDouble(),
              dateTime: DateTime.parse(data['dateTime']),
              status: data['status'] ?? 'pending',
            ));
          }

          return list;
        });
  }

  Future<void> cancelAppointment(String appointmentId) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': 'canceled',
    });
  }
}

// ==================== APPOINTMENT CARD ====================

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onShopTap;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.onShopTap,
    this.onCancel,
  });

  String _getStatusText() {
    switch (appointment.status) {
      case 'pending':
        return 'Beklemede';
      case 'approved':
        return 'Onaylandı';
      case 'canceled':
        return 'İptal Edildi';
      case 'completed':
        return 'Tamamlandı';
      default:
        return 'Beklemede';
    }
  }

  Color _getStatusColor() {
    switch (appointment.status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusBackgroundColor() {
    switch (appointment.status) {
      case 'pending':
        return Colors.orange.withOpacity(0.2);
      case 'approved':
        return Colors.green.withOpacity(0.2);
      case 'canceled':
        return Colors.red.withOpacity(0.2);
      case 'completed':
        return Colors.blue.withOpacity(0.2);
      default:
        return Colors.orange.withOpacity(0.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = appointment.dateTime;
    final isCancelable = (appointment.status == 'pending' || appointment.status == 'approved') &&
        date.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onShopTap,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      image: appointment.barberImageUrl != null
                          ? DecorationImage(image: NetworkImage(appointment.barberImageUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: appointment.barberImageUrl == null
                        ? const Icon(Icons.store, color: Color(0xFFD4AF37), size: 28)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.barberShopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          appointment.barberName,
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusBackgroundColor(),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: Colors.grey.withOpacity(0.2),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Hizmet', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(appointment.serviceName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tarih', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Saat', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_money, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ücret', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(
                            '${appointment.price.toStringAsFixed(0)} ₺',
                            style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCancelable) ...[
            Container(
              height: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Randevuyu İptal Et',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== ANA EKRAN (StreamBuilder ile) ====================

class MyAppointments extends StatelessWidget {
  const MyAppointments({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AppointmentFirebaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text("Randevularım", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      // 🔥 STREAMBUILDER İLE ANLIK GÜNCELLEME
      body: StreamBuilder<List<Appointment>>(
        stream: service.streamMyAppointments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Hata: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          final appointments = snapshot.data ?? [];

          if (appointments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz randevunuz bulunmuyor.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Berber arama ekranı yakında...'), backgroundColor: Colors.orange),
                      );
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Berber Ara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            );
          }

          // Yaklaşan ve geçmiş randevuları ayır
          final now = DateTime.now();
          final upcoming = appointments
              .where((a) => a.dateTime.isAfter(now) && a.status != 'canceled')
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

          final past = appointments
              .where((a) => a.dateTime.isBefore(now) || a.status == 'canceled')
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Yaklaşan', icon: Icon(Icons.calendar_today)),
                    Tab(text: 'Geçmiş', icon: Icon(Icons.history)),
                  ],
                  indicatorColor: Color(0xFFD4AF37),
                  labelColor: Color(0xFFD4AF37),
                  unselectedLabelColor: Colors.grey,
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAppointmentList(context, upcoming, service, isUpcoming: true),
                      _buildAppointmentList(context, past, service, isUpcoming: false),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppointmentList(
    BuildContext context,
    List<Appointment> appointments,
    AppointmentFirebaseService service, {
    required bool isUpcoming,
  }) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUpcoming ? Icons.calendar_today : Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isUpcoming
                  ? 'Yaklaşan randevunuz bulunmuyor.'
                  : 'Geçmiş randevunuz bulunmuyor.',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return AppointmentCard(
          appointment: appointment,
          onShopTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BarberProfileViewScreen(barberId: appointment.barberId),
              ),
            );
          },
          onCancel: isUpcoming && appointment.status != 'canceled'
              ? () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Randevuyu İptal Et'),
                      content: const Text('Bu randevuyu iptal etmek istediğinize emin misiniz?'),
                      backgroundColor: const Color(0xFF1C1C1C),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('İptal Et', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await service.cancelAppointment(appointment.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Randevu iptal edildi'), backgroundColor: Colors.green),
                    );
                  }
                }
              : null,
        );
      },
    );
  }
}