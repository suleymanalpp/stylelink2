import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODELLER ====================

class BarberAppointment {
  final String id;
  final String customerId;
  final String customerName;
  final String? customerImageUrl;
  final String serviceName;
  final double price;
  final DateTime dateTime;
  final String status;

  BarberAppointment({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerImageUrl,
    required this.serviceName,
    required this.price,
    required this.dateTime,
    required this.status,
  });
}

// ==================== FIREBASE SERVİSLERİ ====================

class AppointmentFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? getCurrentBarberId() {
    return _auth.currentUser?.uid;
  }

  Stream<List<BarberAppointment>> streamBarberAppointments() {
    final barberId = getCurrentBarberId();
    if (barberId == null) return Stream.value([]);

    return _firestore
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .orderBy('dateTime', descending: false)
        .snapshots()
        .asyncMap((snapshot) async {
          List<BarberAppointment> list = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final customerId = data['customerId'] ?? '';

            String customerName = "Müşteri";
            String? customerImageUrl;

            if (customerId.isNotEmpty) {
              final customerDoc = await _firestore.collection('users').doc(customerId).get();
              final c = customerDoc.data();

              customerName = c?['nameSurname'] ?? "Müşteri";
              customerImageUrl = c?['profileImageUrl'];
            }

            list.add(BarberAppointment(
              id: doc.id,
              customerId: customerId,
              customerName: customerName,
              customerImageUrl: customerImageUrl,
              serviceName: data['serviceName'] ?? '',
              price: (data['price'] ?? 0).toDouble(),
              dateTime: DateTime.parse(data['dateTime']),
              status: data['status'] ?? 'pending',
            ));
          }

          return list;
        });
  }

  Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
    });
  }
}

// ==================== RANDEVU KARTI WIDGET'I ====================

class BarberAppointmentCard extends StatelessWidget {
  final BarberAppointment appointment;
  final VoidCallback? onApprove;
  final VoidCallback? onCancel;

  const BarberAppointmentCard({
    super.key,
    required this.appointment,
    this.onApprove,
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
    final isPending = appointment.status == 'pending';
    final isApproved = appointment.status == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(25),
                    image: appointment.customerImageUrl != null
                        ? DecorationImage(image: NetworkImage(appointment.customerImageUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: appointment.customerImageUrl == null
                      ? const Icon(Icons.person, color: Color(0xFFD4AF37), size: 28)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        appointment.serviceName,
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
          Container(
            height: 1,
            color: Colors.grey.withOpacity(0.2),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isPending) ...[
                  ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reddet'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
                if (isApproved) ...[
                  OutlinedButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('İptal Et'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== ANA EKRAN ====================

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

// 🔥 BURAYA "with SingleTickerProviderStateMixin" EKLENDİ
class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  final service = AppointmentFirebaseService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveAppointment(String appointmentId) async {
    await service.updateAppointmentStatus(appointmentId, 'approved');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Randevu onaylandı'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _cancelAppointment(String appointmentId) async {
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
      await service.updateAppointmentStatus(appointmentId, 'canceled');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Randevu iptal edildi'), backgroundColor: Colors.green),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Randevular', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Bekleyen', icon: Icon(Icons.pending)),
            Tab(text: 'Geçmiş', icon: Icon(Icons.history)),
          ],
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: StreamBuilder<List<BarberAppointment>>(
        stream: service.streamBarberAppointments(),
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
          final now = DateTime.now();

          final pending = appointments
              .where((a) => 
                  (a.status == 'pending' || a.status == 'approved') && 
                  a.dateTime.isAfter(now))
              .toList()
            ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

          final past = appointments
              .where((a) => 
                  a.status == 'canceled' || 
                  a.status == 'completed' || 
                  a.dateTime.isBefore(now))
              .toList()
            ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAppointmentList(pending, isPendingTab: true),
              _buildAppointmentList(past, isPendingTab: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppointmentList(List<BarberAppointment> appointments, {required bool isPendingTab}) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab ? Icons.pending_actions : Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPendingTab
                  ? 'Bekleyen randevunuz bulunmuyor.'
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
        return BarberAppointmentCard(
          appointment: appointment,
          onApprove: (appointment.status == 'pending' && isPendingTab)
              ? () => _approveAppointment(appointment.id)
              : null,
          onCancel: (appointment.status != 'canceled')
              ? () => _cancelAppointment(appointment.id)
              : null,
        );
      },
    );
  }
}