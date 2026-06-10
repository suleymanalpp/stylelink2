import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODELLER ====================

// ÇALIŞMA SAATLERİ MODELİ
class WorkingHours {
  final String id;
  final String barberId;
  final String openTime;
  final String closeTime;
  final int slotDurationMinutes;
  final Map<String, bool> dayStatus;

  WorkingHours({
    required this.id,
    required this.barberId,
    required this.openTime,
    required this.closeTime,
    required this.slotDurationMinutes,
    required this.dayStatus,
  });

  factory WorkingHours.fromMap(String id, Map<String, dynamic> map) {
    return WorkingHours(
      id: id,
      barberId: map['barberId'] ?? '',
      openTime: map['openTime'] ?? '09:00',
      closeTime: map['closeTime'] ?? '20:00',
      slotDurationMinutes: map['slotDurationMinutes'] ?? 30,
      dayStatus: Map<String, bool>.from(map['dayStatus'] ?? {
        '1': true, '2': true, '3': true, '4': true, '5': true, '6': true, '7': false,
      }),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barberId': barberId,
      'openTime': openTime,
      'closeTime': closeTime,
      'slotDurationMinutes': slotDurationMinutes,
      'dayStatus': dayStatus,
    };
  }
}

// HİZMET MODELİ
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

  Map<String, dynamic> toMap() {
    return {
      'barberId': barberId,
      'name': name,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
    };
  }
}

// ==================== FIREBASE SERVİSLERİ ====================

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Kullanıcı bilgisi getir
  Future<DocumentSnapshot> getUserById(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  // Hizmetleri dinle
  Stream<QuerySnapshot> streamServicesForBarber(String barberId) {
    return _firestore
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .snapshots();
  }

  // Hizmet ekle
  Future<void> addService(BarberService service) async {
    await _firestore.collection('services').doc(service.id).set(service.toMap());
  }

  // Hizmet güncelle
  Future<void> updateService(BarberService service) async {
    await _firestore.collection('services').doc(service.id).update(service.toMap());
  }

  // Hizmet sil
  Future<void> deleteService(String serviceId) async {
    await _firestore.collection('services').doc(serviceId).delete();
  }

  // Çalışma saatlerini getir
  Future<DocumentSnapshot?> getWorkingHours(String barberId) async {
    final query = await _firestore
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return query.docs.first;
    }
    return null;
  }

  // 🔥 DÜZELTİLDİ: Çalışma saatlerini kaydet (varsa güncelle, yoksa ekle)
  Future<void> saveWorkingHours(WorkingHours workingHours) async {
    await _firestore.collection('workingHours').doc(workingHours.id).set(
      workingHours.toMap(),
      SetOptions(merge: true),
    );
  }
}

// ==================== ANA EKRAN ====================

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final String? currentBarberId = FirebaseAuth.instance.currentUser?.uid;
  
  // Hizmet ekleme/düzenleme controller'ları
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _serviceDescriptionController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDurationController = TextEditingController();
  
  // Çalışma saatleri
  Map<String, bool> _dayStatus = {};
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _closeTime = const TimeOfDay(hour: 20, minute: 0);
  int _slotDuration = 30;
  bool _isLoadingHours = true;
  
  // State
  String? _editingServiceId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadWorkingHours();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _serviceNameController.dispose();
    _serviceDescriptionController.dispose();
    _servicePriceController.dispose();
    _serviceDurationController.dispose();
    super.dispose();
  }

  // ÇALIŞMA SAATLERİNİ YÜKLE
  Future<void> _loadWorkingHours() async {
    setState(() => _isLoadingHours = true);
    
    try {
      final workingHoursDoc = await _firestoreService.getWorkingHours(currentBarberId!);
      
      if (workingHoursDoc != null && workingHoursDoc.exists) {
        final data = workingHoursDoc.data() as Map<String, dynamic>;
        setState(() {
          _dayStatus = Map<String, bool>.from(data['dayStatus'] ?? {
            '1': true, '2': true, '3': true, '4': true, '5': true, '6': true, '7': false,
          });
          _openTime = _parseTimeOfDay(data['openTime'] ?? '09:00');
          _closeTime = _parseTimeOfDay(data['closeTime'] ?? '20:00');
          _slotDuration = data['slotDurationMinutes'] ?? 30;
          _isLoadingHours = false;
        });
      } else {
        setState(() {
          _dayStatus = {
            '1': true, '2': true, '3': true, '4': true, '5': true, '6': true, '7': false,
          };
          _isLoadingHours = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingHours = false);
    }
  }

  TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // HİZMET EKLE/GÜNCELLE DİYALOĞU
  void _showServiceDialog({String? serviceId, String? name, String? description, double? price, int? duration}) {
    _editingServiceId = serviceId;
    _serviceNameController.text = name ?? '';
    _serviceDescriptionController.text = description ?? '';
    _servicePriceController.text = price?.toString() ?? '';
    _serviceDurationController.text = duration?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(serviceId == null ? 'Yeni Hizmet Ekle' : 'Hizmet Düzenle'),
        backgroundColor: const Color(0xFF1C1C1C),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _serviceNameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Hizmet Adı',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serviceDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _servicePriceController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Fiyat (₺)',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serviceDurationController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Süre (dakika)',
                  labelStyle: TextStyle(color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _saveService,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
            child: Text(serviceId == null ? 'Ekle' : 'Güncelle', style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveService() async {
    if (_serviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet adı giriniz')));
      return;
    }

    setState(() => _isLoading = true);

    final service = BarberService(
      id: _editingServiceId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      barberId: currentBarberId!,
      name: _serviceNameController.text.trim(),
      description: _serviceDescriptionController.text.trim(),
      price: double.tryParse(_servicePriceController.text) ?? 0,
      durationMinutes: int.tryParse(_serviceDurationController.text) ?? 30,
    );

    if (_editingServiceId == null) {
      await _firestoreService.addService(service);
    } else {
      await _firestoreService.updateService(service);
    }

    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingServiceId == null ? 'Hizmet eklendi' : 'Hizmet güncellendi')),
      );
    }
  }

  Future<void> _deleteService(String serviceId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hizmet Sil'),
        content: const Text('Bu hizmeti silmek istediğinize emin misiniz?'),
        backgroundColor: const Color(0xFF1C1C1C),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await _firestoreService.deleteService(serviceId);
              if (mounted) {
                Navigator.pop(context);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hizmet silindi')));
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 🔥 DÜZELTİLDİ: Çalışma saatlerini kaydet (mevcut ID'yi koru)
  Future<void> _saveWorkingHours() async {
    setState(() => _isLoading = true);
    
    try {
      // Mevcut çalışma saatlerini kontrol et
      final existingDoc = await _firestoreService.getWorkingHours(currentBarberId!);
      
      String docId;
      if (existingDoc != null && existingDoc.exists) {
        // VARSA AYNI ID'Yİ KULLAN (GÜNCELLE)
        docId = existingDoc.id;
      } else {
        // YOKSA YENİ ID OLUŞTUR
        docId = DateTime.now().millisecondsSinceEpoch.toString();
      }
      
      final workingHours = WorkingHours(
        id: docId,
        barberId: currentBarberId!,
        openTime: _formatTimeOfDay(_openTime),
        closeTime: _formatTimeOfDay(_closeTime),
        slotDurationMinutes: _slotDuration,
        dayStatus: _dayStatus,
      );
      
      await _firestoreService.saveWorkingHours(workingHours);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çalışma saatleri kaydedildi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _selectTime(String type) async {
    final initialTime = type == 'open' ? _openTime : _closeTime;
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFFD4AF37)),
        ),
        child: child!,
      ),
    );
    if (time != null && mounted) {
      setState(() {
        if (type == 'open') {
          _openTime = time;
        } else {
          _closeTime = time;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Dükkanım', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: ' Hizmetlerim', icon: Icon(Icons.content_cut)),
            Tab(text: ' Çalışma Saatleri', icon: Icon(Icons.schedule)),
          ],
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.grey,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServicesTab(),
          _buildWorkingHoursTab(),
        ],
      ),
    );
  }

  // ==================== HİZMETLER SEKMESİ ====================
  Widget _buildServicesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showServiceDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Hizmet Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.streamServicesForBarber(currentBarberId!),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final services = snapshot.data!.docs;
              if (services.isEmpty) {
                return const Center(
                  child: Text('Henüz hizmet eklenmemiş.', style: TextStyle(color: Colors.grey)),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final doc = services[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final service = BarberService.fromMap(doc.id, data);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: const Color(0xFF1C1C1C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 30),
                      title: Text(service.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${service.durationMinutes} dk • ${service.price.toStringAsFixed(0)} ₺\n${service.description}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showServiceDialog(
                              serviceId: service.id,
                              name: service.name,
                              description: service.description,
                              price: service.price,
                              duration: service.durationMinutes,
                            ),
                            icon: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
                          ),
                          IconButton(
                            onPressed: () => _deleteService(service.id),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== ÇALIŞMA SAATLERİ SEKMESİ ====================
  Widget _buildWorkingHoursTab() {
    if (_isLoadingHours) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Açık Olduğu Günler', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'].asMap().entries.map((entry) {
            final index = entry.key;
            final dayName = entry.value;
            final dayKey = (index + 1).toString();
            return SwitchListTile(
              title: Text(dayName, style: const TextStyle(color: Colors.white)),
              value: _dayStatus[dayKey] ?? false,
              onChanged: (value) {
                setState(() {
                  _dayStatus[dayKey] = value;
                });
              },
              activeColor: const Color(0xFFD4AF37),
            );
          }),
          
          const Divider(color: Colors.grey, height: 32),
          
          const Text('Açılış Saati', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectTime('open'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 12),
                  Text(_formatTimeOfDay(_openTime), style: const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          const Text('Kapanış Saati', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectTime('close'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 12),
                  Text(_formatTimeOfDay(_closeTime), style: const TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          const Text('Randevu Aralığı (dakika)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _slotDuration.toDouble(),
                  min: 15,
                  max: 120,
                  divisions: (120 - 15) ~/ 5,
                  label: '$_slotDuration dk',
                  onChanged: (value) {
                    setState(() {
                      _slotDuration = value.toInt();
                    });
                  },
                  activeColor: const Color(0xFFD4AF37),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$_slotDuration dk', style: const TextStyle(color: Color(0xFFD4AF37))),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveWorkingHours,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Kaydet', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Not: Çalışma saatlerinde yapacağınız değişiklikler, mevcut randevuları etkilememesi için en ileri tarihteki randevudan sonraki günler için geçerli olacaktır.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}