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
  Future<List<DateTime>> getBookedAppointments(String barberId, DateTime date) async {
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
      return DateTime.parse(doc.data()['dateTime']);
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
  DateTime? _selectedSlot;
  AppointmentService? _selectedService;
  
  // Veriler
  List<AppointmentService> _services = [];
  List<DateTime> _availableSlots = [];
  List<DateTime> _bookedSlots = [];
  bool _isLoadingServices = true;
  bool _isLoadingSlots = false;
  bool _isCreating = false;
  
  // Çalışma saatleri bilgileri
  String _openTime = '09:00';
  String _closeTime = '20:00';
  int _slotDuration = 30;
  int _breakBetweenSlots = 0;
  Map<String, bool> _dayStatus = {};

  @override
  void initState() {
    super.initState();
    _firebaseService = AppointmentFirebaseService();
    _customerId = _firebaseService.getCurrentCustomerId();
    _loadServices();
    _loadWorkingHoursOnly();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    final services = await _firebaseService.getBarberServices(widget.barberId);
    setState(() {
      _services = services;
      _isLoadingServices = false;
    });
  }

  // Çalışma saatlerini yükle
  Future<void> _loadWorkingHoursOnly() async {
    final workingHours = await _firebaseService.getWorkingHours(widget.barberId);
    
    print('========== WORKING HOURS LOADED ==========');
    print('Raw workingHours: $workingHours');
    
    if (workingHours != null) {
      // 🔥 TİP DÖNÜŞÜMLERİNİ KONTROL ET
      final openTimeRaw = workingHours['openTime'] ?? '09:00';
      final closeTimeRaw = workingHours['closeTime'] ?? '20:00';
      final slotDurationRaw = workingHours['slotDurationMinutes'] ?? 30;
      final breakBetweenRaw = workingHours['breakBetweenSlotsMinutes'] ?? 0;
      
      print('openTimeRaw: $openTimeRaw (${openTimeRaw.runtimeType})');
      print('closeTimeRaw: $closeTimeRaw (${closeTimeRaw.runtimeType})');
      print('slotDurationRaw: $slotDurationRaw (${slotDurationRaw.runtimeType})');
      print('breakBetweenRaw: $breakBetweenRaw (${breakBetweenRaw.runtimeType})');
      
      setState(() {
        _openTime = openTimeRaw.toString();
        _closeTime = closeTimeRaw.toString();
        // 🔥 int'e dönüştür (String gelebilir)
        _slotDuration = slotDurationRaw is int ? slotDurationRaw : int.tryParse(slotDurationRaw.toString()) ?? 30;
        _breakBetweenSlots = breakBetweenRaw is int ? breakBetweenRaw : int.tryParse(breakBetweenRaw.toString()) ?? 0;
        _dayStatus = Map<String, bool>.from(workingHours['dayStatus'] ?? {});
      });
      
      print('Parsed values:');
      print('  _openTime: $_openTime');
      print('  _closeTime: $_closeTime');
      print('  _slotDuration: $_slotDuration');
      print('  _breakBetweenSlots: $_breakBetweenSlots');
      print('  _dayStatus: $_dayStatus');
    } else {
      print('⚠️ workingHours is NULL! Using default values.');
    }
    print('==========================================');
  }

  // 🔥 TARİH SEÇİCİ - SADECE AÇIK GÜNLER SEÇİLEBİLİR
  Future<void> _selectDate() async {
    await _loadWorkingHoursOnly();
    
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      selectableDayPredicate: (DateTime date) {
        final dayKey = date.weekday.toString();
        final isOpen = _dayStatus[dayKey] ?? false;
        
        final isToday = date.year == DateTime.now().year &&
                        date.month == DateTime.now().month &&
                        date.day == DateTime.now().day;
        
        if (date.isBefore(DateTime.now()) && !isToday) {
          return false;
        }
        
        return isOpen;
      },
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD4AF37)),
        ),
        child: child!,
      ),
    );
    
    if (selectedDate != null) {
      setState(() {
        _selectedDate = selectedDate;
        _selectedSlot = null;
        _availableSlots = [];
        _bookedSlots = [];
      });
      
      await _loadAvailableSlots();
    }
  }

  // 🔥 SLOTLARI HESAPLA
  Future<void> _loadAvailableSlots() async {
    if (_selectedDate == null) return;
    
    // 🔥 DEBUG: Firestore'dan gelen değerleri kontrol et
    print('========== DEBUG SLOT HESAPLAMA ==========');
    print('Seçilen tarih: ${_selectedDate}');
    print('Haftanın günü: ${_selectedDate!.weekday}');
    print('dayStatus: $_dayStatus');
    print('openTime: $_openTime');
    print('closeTime: $_closeTime');
    print('slotDurationMinutes: $_slotDuration');
    print('breakBetweenSlots: $_breakBetweenSlots');
    print('==========================================');
    
    setState(() => _isLoadingSlots = true);
    
    try {
      final dayOfWeek = _selectedDate!.weekday;
      final dayKey = dayOfWeek.toString();
      final isOpen = _dayStatus[dayKey] ?? false;
      
      print('Gün kontrolü: dayKey=$dayKey, isOpen=$isOpen');
      
      if (!isOpen) {
        print('⚠️ Dükkan bu gün KAPALI!');
        _availableSlots = [];
        _bookedSlots = [];
        setState(() => _isLoadingSlots = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu gün dükkan kapalıdır.'), backgroundColor: Colors.orange),
        );
        return;
      }
      
      // Dolu randevuları al
      final bookedAppointments = await _firebaseService.getBookedAppointments(widget.barberId, _selectedDate!);
      print('Dolu randevu sayısı: ${bookedAppointments.length}');
      
      // Tüm slotları hesapla
      final allSlots = _generateAllSlots();
      print('Toplam slot sayısı: ${allSlots.length}');
      
      // Dolu slotları belirle
      _bookedSlots = [];
      _availableSlots = [];
      
      for (var slot in allSlots) {
        bool isBooked = false;
        for (var booked in bookedAppointments) {
          final bookedStart = booked;
          final bookedEnd = booked.add(Duration(minutes: _slotDuration));
          final slotEnd = slot.add(Duration(minutes: _slotDuration));
          
          if ((slot.isBefore(bookedEnd) && slotEnd.isAfter(bookedStart))) {
            isBooked = true;
            break;
          }
        }
        
        if (isBooked) {
          _bookedSlots.add(slot);
        } else {
          _availableSlots.add(slot);
        }
      }
      
      print('Boş slot sayısı: ${_availableSlots.length}');
      print('Dolu slot sayısı: ${_bookedSlots.length}');
      
    } catch (e) {
      print('❌ Slot hesaplama hatası: $e');
      _availableSlots = [];
      _bookedSlots = [];
    } finally {
      setState(() => _isLoadingSlots = false);
    }
  }

  // 🔥 TÜM SLOTLARI OLUŞTUR
  List<DateTime> _generateAllSlots() {
    print('🔧 Slot hesaplama detayları:');
    print('  openTime: $_openTime');
    print('  closeTime: $_closeTime');
    print('  slotDuration: $_slotDuration');
    print('  breakBetweenSlots: $_breakBetweenSlots');
    
    final slots = <DateTime>[];
    
    final openParts = _openTime.split(':');
    final closeParts = _closeTime.split(':');
    
    if (openParts.length < 2 || closeParts.length < 2) {
      print('❌ HATA: openTime veya closeTime formatı yanlış!');
      print('   openParts: $openParts');
      print('   closeParts: $closeParts');
      return slots;
    }
    
    int openHour = int.parse(openParts[0]);
    int openMinute = int.parse(openParts[1]);
    int closeHour = int.parse(closeParts[0]);
    int closeMinute = int.parse(closeParts[1]);
    
    print('  openHour: $openHour, openMinute: $openMinute');
    print('  closeHour: $closeHour, closeMinute: $closeMinute');
    
    DateTime currentSlot = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      openHour,
      openMinute,
    );
    
    final closeTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      closeHour,
      closeMinute,
    );
    
    print('  currentSlot başlangıç: $currentSlot');
    print('  closeTime: $closeTime');
    
    int slotCount = 0;
    while (currentSlot.add(Duration(minutes: _slotDuration)).isBefore(closeTime) ||
           currentSlot.add(Duration(minutes: _slotDuration)).isAtSameMomentAs(closeTime)) {
      
      slots.add(currentSlot);
      slotCount++;
      
      final nextSlot = currentSlot.add(Duration(minutes: _slotDuration + _breakBetweenSlots));
      print('  Slot $slotCount: ${_formatDateTime(currentSlot)} - ${_formatDateTime(currentSlot.add(Duration(minutes: _slotDuration)))}');
      print('    Sonraki slot başlangıcı: ${_formatDateTime(nextSlot)}');
      
      currentSlot = nextSlot;
    }
    
    print('✅ Toplam $slotCount slot oluşturuldu.');
    return slots;
  }

  Future<void> _createAppointment() async {
    if (_selectedDate == null) {
      _showSnackBar('Lütfen bir tarih seçin', Colors.red);
      return;
    }
    
    if (_selectedSlot == null) {
      _showSnackBar('Lütfen bir saat seçin', Colors.red);
      return;
    }
    
    if (_selectedService == null) {
      _showSnackBar('Lütfen bir hizmet seçin', Colors.red);
      return;
    }
    
    setState(() => _isCreating = true);
    
    try {
      await _firebaseService.createAppointment(
        barberId: widget.barberId,
        customerId: _customerId!,
        serviceId: _selectedService!.id,
        serviceName: _selectedService!.name,
        price: _selectedService!.price,
        dateTime: _selectedSlot!,
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
                  : _availableSlots.isEmpty && _bookedSlots.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'Bu gün için randevu alınamamaktadır.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ..._availableSlots.map((slot) {
                              final isSelected = _selectedSlot == slot;
                              return FilterChip(
                                label: Text(_formatDateTime(slot)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedSlot = selected ? slot : null;
                                  });
                                },
                                backgroundColor: const Color(0xFF1C1C1C),
                                selectedColor: const Color(0xFF4CAF50),
                                labelStyle: const TextStyle(color: Colors.white),
                                avatar: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                              );
                            }).toList(),
                            ..._bookedSlots.map((slot) {
                              return FilterChip(
                                label: Text(_formatDateTime(slot)),
                                selected: false,
                                onSelected: null,
                                backgroundColor: Colors.red.withOpacity(0.3),
                                labelStyle: const TextStyle(color: Colors.grey),
                                avatar: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                              );
                            }).toList(),
                          ],
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
                onPressed: (_selectedDate != null && _selectedSlot != null && _selectedService != null && !_isCreating)
                    ? _createAppointment
                    : null,
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
            
            const SizedBox(height: 16),
            
            // Bilgi kutusu
            if (_selectedService != null && _selectedDate != null && _selectedSlot != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seçilen hizmet: ${_selectedService!.name}\n'
                        'Süre: ${_selectedService!.durationMinutes} dk\n'
                        'Randevu saati: ${_formatDateTime(_selectedSlot!)}',
                        style: const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}