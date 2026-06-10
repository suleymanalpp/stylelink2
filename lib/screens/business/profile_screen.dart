import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// ==================== MODELLER ====================

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

// ==================== FIREBASE SERVİSLERİ ====================

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Kullanıcı bilgisi getir
  Future<DocumentSnapshot> getUserById(String uid) async {
    return await _firestore.collection('users').doc(uid).get();
  }

  // Kullanıcı bilgisi güncelle
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Hizmetleri getir (tek seferlik)
  Future<List<BarberService>> getServicesForBarber(String barberId) async {
    final snapshot = await _firestore
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return BarberService.fromMap(doc.id, data);
    }).toList();
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

  // Yorum sayısını getir
  Future<int> getReviewCount(String barberId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .get();
    return snapshot.docs.length;
  }

  // Ortalama puanı getir
  Future<double> getAverageRating(String barberId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .get();
    
    if (snapshot.docs.isEmpty) return 0.0;
    
    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data()['rating'] ?? 0).toDouble();
    }
    return total / snapshot.docs.length;
  }

  // Profil fotoğrafı yükle
  Future<String> uploadProfileImage(String userId, File imageFile) async {
    final ref = _storage.ref().child('profile_images/$userId.jpg');
    await ref.putFile(imageFile);
    final downloadUrl = await ref.getDownloadURL();
    
    await updateUser(userId, {'profileImageUrl': downloadUrl});
    
    return downloadUrl;
  }
}

// ==================== ANA EKRAN ====================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreService _firestoreService = FirestoreService();
  final String? currentBarberId = FirebaseAuth.instance.currentUser?.uid;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Profil bilgileri
  String _shopName = 'Yükleniyor...';
  String _barberName = 'Yükleniyor...';
  String _phone = 'Yükleniyor...';
  String _email = 'Yükleniyor...';
  String _address = 'Yükleniyor...';
  String _about = 'Yükleniyor...';
  double _rating = 0.0;
  int _reviewCount = 0;
  String? _profileImageUrl;
  
  // Düzenleme durumları
  bool _isEditingShopName = false;
  bool _isEditingBarberName = false;
  bool _isEditingAddress = false;
  bool _isEditingAbout = false;
  
  // Düzenleme controller'ları
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _barberNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  
  // Çalışma saatleri
  Map<String, bool> _dayStatus = {};
  String _openTime = '09:00';
  String _closeTime = '20:00';
  bool _isLoadingHours = true;
  
  // Hizmetler
  List<BarberService> _services = [];
  bool _isLoadingServices = true;
  bool _isLoading = true;
  
  // Yükleme durumları
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadProfileData(),
      _loadWorkingHours(),
      _loadServices(),
      _loadReviews(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadProfileData() async {
    final userDoc = await _firestoreService.getUserById(currentBarberId!);
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      setState(() {
        _shopName = data['shopName'] ?? 'Dükkan Adı Yok';
        _barberName = data['nameSurname'] ?? 'Berber Adı Yok';
        _phone = data['phone'] ?? 'Telefon yok';
        _email = data['email'] ?? 'E-posta yok';
        _address = data['address'] ?? 'Adres yok';
        _about = data['about'] ?? 'Henüz açıklama eklenmemiş.';
        _profileImageUrl = data['profileImageUrl'];
      });
      
      _shopNameController.text = _shopName;
      _barberNameController.text = _barberName;
      _addressController.text = _address;
      _aboutController.text = _about;
    }
  }

  Future<void> _loadWorkingHours() async {
    setState(() => _isLoadingHours = true);
    final workingHoursDoc = await _firestoreService.getWorkingHours(currentBarberId!);
    
    if (workingHoursDoc != null && workingHoursDoc.exists) {
      final data = workingHoursDoc.data() as Map<String, dynamic>;
      setState(() {
        _dayStatus = Map<String, bool>.from(data['dayStatus'] ?? {});
        _openTime = data['openTime'] ?? '09:00';
        _closeTime = data['closeTime'] ?? '20:00';
        _isLoadingHours = false;
      });
    } else {
      setState(() => _isLoadingHours = false);
    }
  }

  Future<void> _loadServices() async {
    setState(() => _isLoadingServices = true);
    final services = await _firestoreService.getServicesForBarber(currentBarberId!);
    setState(() {
      _services = services;
      _isLoadingServices = false;
    });
  }

  Future<void> _loadReviews() async {
    final reviewCount = await _firestoreService.getReviewCount(currentBarberId!);
    final rating = await _firestoreService.getAverageRating(currentBarberId!);
    setState(() {
      _reviewCount = reviewCount;
      _rating = rating;
    });
  }

  // ==================== DÜZENLEME FONKSİYONLARI ====================
  
  void _startEditShopName() {
    _shopNameController.text = _shopName;
    setState(() => _isEditingShopName = true);
  }

  void _saveShopName() async {
    final newName = _shopNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dükkan adı boş olamaz'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentBarberId!, {'shopName': newName});
      setState(() {
        _shopName = newName;
        _isEditingShopName = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dükkan adı güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startEditBarberName() {
    _barberNameController.text = _barberName;
    setState(() => _isEditingBarberName = true);
  }

  void _saveBarberName() async {
    final newName = _barberNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berber adı boş olamaz'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentBarberId!, {'nameSurname': newName});
      setState(() {
        _barberName = newName;
        _isEditingBarberName = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berber adı güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startEditAddress() {
    _addressController.text = _address;
    setState(() => _isEditingAddress = true);
  }

  void _saveAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adres boş olamaz'), backgroundColor: Colors.red),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentBarberId!, {'address': newAddress});
      setState(() {
        _address = newAddress;
        _isEditingAddress = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adres güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startEditAbout() {
    _aboutController.text = _about;
    setState(() => _isEditingAbout = true);
  }

  void _saveAbout() async {
    final newAbout = _aboutController.text.trim();
    
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentBarberId!, {'about': newAbout});
      setState(() {
        _about = newAbout.isEmpty ? 'Henüz açıklama eklenmemiş.' : newAbout;
        _isEditingAbout = false;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Açıklama güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ==================== PROFİL FOTOĞRAFI YÜKLEME ====================
  
  Future<void> _pickAndUploadImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
              title: const Text('Kamerayla Çek', style: TextStyle(color: Colors.white)),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
              title: const Text('Galeriden Seç', style: TextStyle(color: Colors.white)),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 500,
      maxHeight: 500,
    );
    
    if (pickedFile != null) {
      await _uploadImage(File(pickedFile.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isUploadingImage = true);
    
    try {
      final imageUrl = await _firestoreService.uploadProfileImage(currentBarberId!, imageFile);
      setState(() {
        _profileImageUrl = imageUrl;
        _isUploadingImage = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil fotoğrafı güncellendi'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isUploadingImage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yükleme hatası: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Profilim', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _pickAndUploadImage,
            icon: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
            tooltip: 'Profil fotoğrafını değiştir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(),
                      _buildContactButtons(),
                      const SizedBox(height: 20),
                      _buildAboutSection(),
                      const SizedBox(height: 20),
                      
                      // 🔥 TABBAR İLE HİZMETLER VE ÇALIŞMA SAATLERİ
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 50,
                        child: TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: ' Hizmetler', icon: Icon(Icons.content_cut)),
                            Tab(text: ' Çalışma Saatleri', icon: Icon(Icons.schedule)),
                          ],
                          indicatorColor: const Color(0xFFD4AF37),
                          labelColor: const Color(0xFFD4AF37),
                          unselectedLabelColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // TABBAR VIEW
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildServicesTab(),
                            _buildWorkingHoursTab(),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      _buildStatsSection(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                    ),
                  ),
              ],
            ),
    );
  }

  // ==================== PROFİL BAŞLIK BÖLÜMÜ ====================
  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // PROFİL FOTOĞRAFI
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  shape: BoxShape.circle,
                  image: _profileImageUrl != null
                      ? DecorationImage(image: NetworkImage(_profileImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.store, size: 50, color: Color(0xFFD4AF37))
                    : null,
              ),
              if (_isUploadingImage)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F0F), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // DÜKKAN ADI
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isEditingShopName)
                Expanded(
                  child: TextField(
                    controller: _shopNameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _saveShopName(),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    _shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isEditingShopName ? _saveShopName : _startEditShopName,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditingShopName ? Icons.check : Icons.edit,
                    color: const Color(0xFFD4AF37),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // BERBER ADI
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isEditingBarberName)
                Expanded(
                  child: TextField(
                    controller: _barberNameController,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _saveBarberName(),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    _barberName,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isEditingBarberName ? _saveBarberName : _startEditBarberName,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditingBarberName ? Icons.check : Icons.edit,
                    color: const Color(0xFFD4AF37),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // PUAN VE YORUM
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
              const SizedBox(width: 4),
              Text(
                _rating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_reviewCount yorum',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // ADRES
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              if (_isEditingAddress)
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _saveAddress(),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    _address,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _isEditingAddress ? _saveAddress : _startEditAddress,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditingAddress ? Icons.check : Icons.edit,
                    color: const Color(0xFFD4AF37),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== İLETİŞİM BUTONLARI ====================
  Widget _buildContactButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Arama özelliği yakında...')),
                );
              },
              icon: const Icon(Icons.phone),
              label: const Text('Ara'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1C),
                foregroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mesajlaşma özelliği yakında...')),
                );
              },
              icon: const Icon(Icons.chat),
              label: const Text('Mesaj'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1C),
                foregroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yol tarifi özelliği yakında...')),
                );
              },
              icon: const Icon(Icons.directions),
              label: const Text('Yol Tarifi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C1C1C),
                foregroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HAKKIMIZDA BÖLÜMÜ ====================
 // ==================== HAKKIMIZDA BÖLÜMÜ ====================
Widget _buildAboutSection() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              ' Hakkımızda',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            // 🔥 SADECE BURASI DEĞİŞTİ - Daire içine alındı
            GestureDetector(
              onTap: _startEditAbout,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Color(0xFFD4AF37), size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingAbout)
          TextField(
            controller: _aboutController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Dükkanınız hakkında bilgi yazın...',
              hintStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: const Color(0xFF2A2A2A),
            ),
            maxLines: 4,
            onSubmitted: (_) => _saveAbout(),
          )
        else
          Text(
            _about,
            style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
        if (_isEditingAbout) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _isEditingAbout = false),
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _saveAbout,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                child: const Text('Kaydet', style: TextStyle(color: Colors.black)),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

  // ==================== HİZMETLER TAB ====================
  Widget _buildServicesTab() {
    if (_isLoadingServices) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_services.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.content_cut, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Henüz hizmet eklenmemiş.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _services.length,
      itemBuilder: (context, index) {
        final service = _services[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      service.description,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${service.price.toStringAsFixed(0)} ₺',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${service.durationMinutes} dk',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== ÇALIŞMA SAATLERİ TAB ====================
  Widget _buildWorkingHoursTab() {
    if (_isLoadingHours) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 24),
                const SizedBox(width: 12),
                Text(
                  '$_openTime - $_closeTime',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: days.asMap().entries.map((entry) {
                final index = entry.key;
                final dayName = entry.value;
                final dayKey = (index + 1).toString();
                final isOpen = _dayStatus[dayKey] ?? false;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          dayName,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: isOpen ? const Color(0xFFD4AF37) : Colors.red,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isOpen ? 'Açık' : 'Kapalı',
                        style: TextStyle(
                          color: isOpen ? const Color(0xFFD4AF37) : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== İSTATİSTİKLER BÖLÜMÜ ====================
  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 İstatistikler',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFD4AF37), size: 28),
                    const SizedBox(height: 4),
                    Text(
                      _rating.toStringAsFixed(1),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Ortalama Puan', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.comment, color: Color(0xFFD4AF37), size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '$_reviewCount',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Toplam Yorum', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 28),
                    const SizedBox(height: 4),
                    Text(
                      '${_services.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Text('Hizmet Sayısı', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}