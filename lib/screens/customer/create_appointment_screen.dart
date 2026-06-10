import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODELLER ====================

// HİZMET MODELİ
class AppointmentService {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;

  AppointmentService({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  factory AppointmentService.fromMap(String id, Map<String, dynamic> map) {
    return AppointmentService(
      id: id,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      durationMinutes: map['durationMinutes'] ?? 30,
    );
  }
}

// ==================== FIREBASE SERVİSLERİ ====================

class AppointmentFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Berberin hizmetlerini getir
  Future<List<AppointmentService>> getBarberServices(String barberId) async {
    final snapshot = await _firestore
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return AppointmentService.fromMap(doc.id, data);
    }).toList();
  }

  // Berberin çalışma saatlerini getir
  Future<Map<String, dynamic>?> getWorkingHours(String barberId) async {
    final query = await _firestore
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .get();
    
    if (query.docs.isNotEmpty) {
      return query.docs.first.data();
    }
    return null;
  }

  // Belirli bir gündeki dolu randevu saatlerini getir
  Future<List<String>> getBookedSlots(String barberId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final snapshot = await _firestore
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .where('dateTime', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('dateTime', isLessThan: endOfDay.toIso8601String())
        .where('status', isNotEqualTo: 'canceled')
        .get();
    
    return snapshot.docs.map((doc) {
      final dateTime = DateTime.parse(doc.data()['dateTime']);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  // Randevu oluştur
  Future<void> createAppointment({
    required String barberId,
    required String customerId,
    required String serviceId,
    required String serviceName,
    required double price,
    required DateTime dateTime,
  }) async {
    final appointmentId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Müşteri bilgilerini al
    final customerDoc = await _firestore.collection('users').doc(customerId).get();
    final customerName = customerDoc.data()?['nameSurname'] ?? 'Müşteri';
    
    await _firestore.collection('appointments').doc(appointmentId).set({
      'barberId': barberId,
      'customerId': customerId,
      'customerName': customerName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'price': price,
      'dateTime': dateTime.toIso8601String(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Mevcut müşteri ID'sini getir
  String? getCurrentCustomerId() {
    return _auth.currentUser?.uid;
  }
}

// ==================== ANA EKRAN ====================

class CreateAppointmentScreen extends StatefulWidget {
  final String barberId;
  final String barberName;

  const CreateAppointmentScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  @override
  State<CreateAppointmentScreen> createState() => _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState extends State<CreateAppointmentScreen> {
  late AppointmentFirebaseService _firebaseService;
  String? _customerId;
  
  // Seçimler
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  AppointmentService? _selectedService;
  
  // Veriler
  List<AppointmentService> _services = [];
  List<String> _availableSlots = [];
  List<String> _bookedSlots = [];
  bool _isLoadingServices = true;
  bool _isLoadingSlots = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _firebaseService = AppointmentFirebaseService();
    _customerId = _firebaseService.getCurrentCustomerId();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    final services = await _firebaseService.getBarberServices(widget.barberId);
    setState(() {
      _services = services;
      _isLoadingServices = false;
    });
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedDate == null) return;
    
    setState(() => _isLoadingSlots = true);
    
    // Dolu saatleri al
    _bookedSlots = await _firebaseService.getBookedSlots(widget.barberId, _selectedDate!);
    
    // Çalışma saatlerini al
    final workingHours = await _firebaseService.getWorkingHours(widget.barberId);
    
    if (workingHours != null) {
      final openTime = workingHours['openTime'] ?? '09:00';
      final closeTime = workingHours['closeTime'] ?? '20:00';
      final slotDuration = workingHours['slotDurationMinutes'] ?? 30;
      
      // Müsait saatleri oluştur
      _availableSlots = _generateTimeSlots(openTime, closeTime, slotDuration);
      // Dolu saatleri çıkar
      _availableSlots.removeWhere((slot) => _bookedSlots.contains(slot));
    } else {
      // Varsayılan saatler 09:00 - 20:00, 30 dakika aralık
      _availableSlots = _generateTimeSlots('09:00', '20:00', 30);
      _availableSlots.removeWhere((slot) => _bookedSlots.contains(slot));
    }
    
    setState(() => _isLoadingSlots = false);
  }

  List<String> _generateTimeSlots(String openTime, String closeTime, int intervalMinutes) {
    final slots = <String>[];
    
    final openParts = openTime.split(':');
    final closeParts = closeTime.split(':');
    
    int currentHour = int.parse(openParts[0]);
    int currentMinute = int.parse(openParts[1]);
    final endHour = int.parse(closeParts[0]);
    final endMinute = int.parse(closeParts[1]);
    
    while (currentHour < endHour || (currentHour == endHour && currentMinute < endMinute)) {
      slots.add('${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}');
      
      currentMinute += intervalMinutes;
      if (currentMinute >= 60) {
        currentHour++;
        currentMinute -= 60;
      }
    }
    
    return slots;
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD4AF37)),
        ),
        child: child!,
      ),
    );
    
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _selectedTime = null;
      });
      await _loadAvailableSlots();
    }
  }

  Future<void> _createAppointment() async {
    if (_selectedDate == null) {
      _showSnackBar('Lütfen bir tarih seçin', Colors.red);
      return;
    }
    
    if (_selectedTime == null) {
      _showSnackBar('Lütfen bir saat seçin', Colors.red);
      return;
    }
    
    if (_selectedService == null) {
      _showSnackBar('Lütfen bir hizmet seçin', Colors.red);
      return;
    }
    
    setState(() => _isCreating = true);
    
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    
    try {
      await _firebaseService.createAppointment(
        barberId: widget.barberId,
        customerId: _customerId!,
        serviceId: _selectedService!.id,
        serviceName: _selectedService!.name,
        price: _selectedService!.price,
        dateTime: dateTime,
      );
      
      _showSnackBar('Randevu talebiniz gönderildi!', Colors.green);
      Navigator.pop(context);
    } catch (e) {
      _showSnackBar('Hata: $e', Colors.red);
    } finally {
      setState(() => _isCreating = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Randevu Oluştur', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Berber adı
            Text(
              '${widget.barberName} ile Randevu',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            
            // Tarih seçimi
            const Text('Tarih Seçimi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 12),
                    Text(
                      _selectedDate == null
                          ? 'Tarih Seçin'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Saat seçimi
            if (_selectedDate != null) ...[
              const Text('Saat Seçimi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _isLoadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _availableSlots.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Bu gün için müsait saat bulunmamaktadır.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _availableSlots.map((slot) {
                            final timeParts = slot.split(':');
                            final isSelected = _selectedTime != null &&
                                _selectedTime!.hour == int.parse(timeParts[0]) &&
                                _selectedTime!.minute == int.parse(timeParts[1]);
                            return FilterChip(
                              label: Text(slot),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedTime = selected
                                      ? TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]))
                                      : null;
                                });
                              },
                              backgroundColor: const Color(0xFF1C1C1C),
                              selectedColor: const Color(0xFFD4AF37),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
              const SizedBox(height: 20),
            ],
            
            // Hizmet seçimi
            const Text('Hizmet Seçimi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoadingServices
                ? const Center(child: CircularProgressIndicator())
                : _services.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Henüz hizmet eklenmemiş.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _services.length,
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          final isSelected = _selectedService?.id == service.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedService = service;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.2) : const Color(0xFF1C1C1C),
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: const Color(0xFFD4AF37))
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 24),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          service.name,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '${service.durationMinutes} dk',
                                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${service.price.toStringAsFixed(0)} ₺',
                                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            const SizedBox(height: 32),
            
            // Randevu oluştur butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCreating
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Randevu Oluştur',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}