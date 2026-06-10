import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_appointment_screen.dart';  // 🔥 IMPORT
import 'customer_chat_screen.dart';      // 🔥 IMPORT

// ==================== MODELLER ====================

class BarberService {
  final String id;
  final String barberId;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;

  BarberService({
    required this.id,
    required this.barberId,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
  });

  factory BarberService.fromMap(String id, Map<String, dynamic> map) {
    return BarberService(
      id: id,
      barberId: map['barberId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }
}

// ==================== FIREBASE SERVİSLERİ ====================

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentSnapshot> getBarberProfile(String barberId) async {
    return await _firestore.collection('users').doc(barberId).get();
  }

  Future<List<BarberService>> getBarberServices(String barberId) async {
    final snapshot = await _firestore
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return BarberService.fromMap(doc.id, data);
    }).toList();
  }

  Future<Map<String, dynamic>?> getWorkingHours(String barberId) async {
    final query = await _firestore
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) return query.docs.first.data();
    return null;
  }

  Future<Map<String, dynamic>> getReviewsInfo(String barberId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .get();
    if (snapshot.docs.isEmpty) return {'rating': 0.0, 'count': 0};
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['rating'] ?? 0).toDouble();
    }
    return {'rating': total / snapshot.docs.length, 'count': snapshot.docs.length};
  }

  String? getCurrentCustomerId() {
    return _auth.currentUser?.uid;
  }
}

// ==================== ANA EKRAN ====================

class BarberProfileViewScreen extends StatefulWidget {
  final String barberId;
  
  const BarberProfileViewScreen({
    super.key, 
    required this.barberId,
  });

  @override
  State<BarberProfileViewScreen> createState() => _BarberProfileViewScreenState();
}

class _BarberProfileViewScreenState extends State<BarberProfileViewScreen> {
  late FirebaseService _firebaseService;
  String? _currentCustomerId;
  
  String _shopName = 'Yükleniyor...';
  String _barberName = 'Yükleniyor...';
  String _phone = 'Yükleniyor...';
  String _address = 'Yükleniyor...';
  String _about = 'Yükleniyor...';
  String? _profileImageUrl;
  double _rating = 0.0;
  int _reviewCount = 0;
  Map<String, bool> _dayStatus = {};
  String _openTime = '09:00';
  String _closeTime = '20:00';
  bool _isLoadingHours = true;
  List<BarberService> _services = [];
  bool _isLoadingServices = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _firebaseService = FirebaseService();
    _currentCustomerId = _firebaseService.getCurrentCustomerId();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadBarberProfile(),
      _loadServices(),
      _loadWorkingHours(),
      _loadReviews(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadBarberProfile() async {
    final userDoc = await _firebaseService.getBarberProfile(widget.barberId);
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _shopName = data['shopName'] ?? 'Dükkan Adı Yok';
        _barberName = data['nameSurname'] ?? 'Berber Adı Yok';
        _phone = data['phone'] ?? 'Telefon yok';
        _address = data['address'] ?? 'Adres yok';
        _about = data['about'] ?? 'Henüz açıklama eklenmemiş.';
        _profileImageUrl = data['profileImageUrl'];
      });
    }
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    final services = await _firebaseService.getBarberServices(widget.barberId);
    setState(() {
      _services = services;
      _isLoadingServices = false;
    });
  }

  Future<void> _loadWorkingHours() async {
    setState(() => _isLoadingHours = true);
    final workingHours = await _firebaseService.getWorkingHours(widget.barberId);
    if (workingHours != null) {
      setState(() {
        _dayStatus = Map<String, bool>.from(workingHours['dayStatus'] ?? {});
        _openTime = workingHours['openTime'] ?? '09:00';
        _closeTime = workingHours['closeTime'] ?? '20:00';
        _isLoadingHours = false;
      });
    } else {
      setState(() => _isLoadingHours = false);
    }
  }

  Future<void> _loadReviews() async {
    final reviewsInfo = await _firebaseService.getReviewsInfo(widget.barberId);
    setState(() {
      _rating = reviewsInfo['rating'];
      _reviewCount = reviewsInfo['count'];
    });
  }

  // 🔥 IMPORT EDİLEN EKRANLARA YÖNLENDİRME
  void _navigateToAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateAppointmentScreen(
          barberId: widget.barberId,
          barberName: _shopName,
        ),
      ),
    );
  }

  void _navigateToChat() {
    if (_currentCustomerId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerChatScreen(
            customerId: _currentCustomerId!,
            barberId: widget.barberId,
            barberName: _shopName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text('Berber Profili', style: TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF0F0F0F), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  _buildActionButtons(),
                  const SizedBox(height: 20),
                  _buildAboutSection(),
                  const SizedBox(height: 20),
                  _buildServicesSection(),
                  const SizedBox(height: 20),
                  _buildWorkingHoursSection(),
                  const SizedBox(height: 20),
                  _buildStatsSection(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), shape: BoxShape.circle, image: _profileImageUrl != null ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover) : null),
            child: _profileImageUrl == null ? const Icon(Icons.store, size: 50, color: Color(0xFFD4AF37)) : null,
          ),
          const SizedBox(height: 16),
          Text(_shopName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_barberName, style: const TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star, color: Color(0xFFD4AF37), size: 20),
            const SizedBox(width: 4),
            Text(_rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$_reviewCount yorum', style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, color: Colors.grey, size: 16),
            const SizedBox(width: 6),
            Flexible(child: Text(_address, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center)),
          ]),
        ],
      ),
    );
  }

  // 🔥 BUTONLAR - IMPORT EDİLEN EKRANLARI ÇAĞIRIYOR
  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToAppointment,
              icon: const Icon(Icons.calendar_month),
              label: const Text('Randevu Al'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _navigateToChat,
              icon: const Icon(Icons.chat),
              label: const Text('Mesaj At'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C1C1C), foregroundColor: const Color(0xFFD4AF37), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFD4AF37)))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 22), SizedBox(width: 8), Text('Hakkımızda', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        Text(_about, style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
      ]),
    );
  }

  Widget _buildServicesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✂️ Hizmetler ve Fiyatlar', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _isLoadingServices ? const Center(child: CircularProgressIndicator())
        : _services.isEmpty ? Container(padding: const EdgeInsets.all(32), decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Henüz hizmet eklenmemiş.', style: TextStyle(color: Colors.grey))))
        : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _services.length, itemBuilder: (context, index) {
            final service = _services[index];
            return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(service.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(service.description, style: const TextStyle(color: Colors.grey, fontSize: 12))])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${service.price.toStringAsFixed(0)} ₺', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)), Text('${service.durationMinutes} dk', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _buildWorkingHoursSection() {
    final days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⏰ Çalışma Saatleri', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _isLoadingHours ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            Row(children: [const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 20), const SizedBox(width: 8), Text('$_openTime - $_closeTime', style: const TextStyle(color: Colors.white, fontSize: 16))]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: days.asMap().entries.map((entry) {
              final index = entry.key;
              final dayName = entry.value;
              final dayKey = (index + 1).toString();
              final isOpen = _dayStatus[dayKey] ?? false;
              return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isOpen ? const Color(0xFFD4AF37).withOpacity(0.2) : Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(dayName, style: TextStyle(color: isOpen ? const Color(0xFFD4AF37) : Colors.red, fontSize: 12)),
              );
            }).toList()),
          ]),
      ]),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📊 İstatistikler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(children: [const Icon(Icons.star, color: Color(0xFFD4AF37), size: 28), const SizedBox(height: 4), Text(_rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const Text('Ortalama Puan', style: TextStyle(color: Colors.grey, fontSize: 12))])),
          Expanded(child: Column(children: [const Icon(Icons.comment, color: Color(0xFFD4AF37), size: 28), const SizedBox(height: 4), Text('$_reviewCount', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const Text('Toplam Yorum', style: TextStyle(color: Colors.grey, fontSize: 12))])),
          Expanded(child: Column(children: [const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 28), const SizedBox(height: 4), Text('${_services.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const Text('Hizmet Sayısı', style: TextStyle(color: Colors.grey, fontSize: 12))])),
        ]),
      ]),
    );
  }
}