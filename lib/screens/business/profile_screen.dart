import 'package:bapp1/screens/business/business_chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'business_chat_screen.dart'; // CHAT SAYFASI EKLENDİ

// ==================== CLOUDINARY SERVİSİ ====================

class CloudinaryService {
  static const String cloudName = 'du6swar0j';
  static const String uploadPreset = 'ml_default';

  Future<String> uploadImage(XFile imageFile) async {
    final Uint8List bytes = await imageFile.readAsBytes();
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(http.MultipartFile.fromBytes('file', bytes,
        filename: 'img_${DateTime.now().millisecondsSinceEpoch}.jpg'));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return data['secure_url'] as String;
    }
    final errMsg = (data['error'] as Map<String, dynamic>?)?['message'] ??
        'Bilinmeyen hata';
    throw Exception('Cloudinary hatası: $errMsg');
  }
}

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

class Review {
  final String id;
  final String barberId;
  final String customerId;
  final String customerName;
  final String? customerProfileImageUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.barberId,
    required this.customerId,
    required this.customerName,
    this.customerProfileImageUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic> map) {
    return Review(
      id: id,
      barberId: map['barberId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? 'Misafir',
      customerProfileImageUrl: map['customerProfileImageUrl'],
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class GalleryItem {
  final String url;
  final String caption;
  final List<String> likes;
  final DateTime createdAt;

  GalleryItem({
    required this.url,
    required this.caption,
    required this.likes,
    required this.createdAt,
  });

  factory GalleryItem.fromMap(Map<String, dynamic> map) {
    return GalleryItem(
      url: map['url'] ?? '',
      caption: map['caption'] ?? '',
      likes: List<String>.from(map['likes'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'caption': caption,
      'likes': likes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

// ==================== FIREBASE SERVİSİ ====================

class BarberFirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<DocumentSnapshot> getBarberProfile(String barberId) =>
      _db.collection('users').doc(barberId).get();

  Future<void> updateBarberProfile(String barberId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(barberId).update(data);
  }

  Future<String> uploadProfileImage(String barberId, XFile imageFile) async {
    final url = await _cloudinary.uploadImage(imageFile);
    await updateBarberProfile(barberId, {'profileImageUrl': url});
    return url;
  }

  Future<List<Review>> getReviews(String barberId) async {
    final snap = await _db
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => Review.fromMap(d.id, d.data()))
        .toList();
  }

  Future<List<BarberService>> getServices(String barberId) async {
    final snap = await _db
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .get();
    return snap.docs
        .map((d) => BarberService.fromMap(d.id, d.data()))
        .toList();
  }

  Stream<List<BarberService>> servicesStream(String barberId) {
    return _db
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BarberService.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<GalleryItem>> galleryStream(String barberId) {
    return _db
        .collection('users')
        .doc(barberId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return [];
      final data = doc.data() as Map<String, dynamic>;
      final rawList = data['gallery'] as List<dynamic>? ?? [];
      return rawList
          .whereType<Map<String, dynamic>>()
          .map((m) => GalleryItem.fromMap(m))
          .toList();
    });
  }

  // Çalışma saatleri stream'i
  Stream<DocumentSnapshot?> getWorkingHoursStream(String barberId) {
    return _db
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .snapshots()
        .map((query) => query.docs.isNotEmpty ? query.docs.first : null);
  }

  Future<void> addGalleryItem({
    required String barberId,
    required String imageUrl,
    required String caption,
  }) async {
    final newItem = GalleryItem(
      url: imageUrl,
      caption: caption,
      likes: [],
      createdAt: DateTime.now(),
    );
    await _db.collection('users').doc(barberId).update({
      'gallery': FieldValue.arrayUnion([newItem.toMap()])
    });
  }

  Future<String> uploadGalleryImage(String barberId, XFile imageFile, String caption) async {
    final url = await _cloudinary.uploadImage(imageFile);
    await addGalleryItem(barberId: barberId, imageUrl: url, caption: caption);
    return url;
  }

  Future<void> updateGalleryCaption({
    required String barberId,
    required String imageUrl,
    required String newCaption,
    required List<GalleryItem> currentGallery,
  }) async {
    final updatedGallery = currentGallery.map((item) {
      if (item.url != imageUrl) return item.toMap();
      return {
        'url': item.url,
        'caption': newCaption,
        'likes': item.likes,
        'createdAt': Timestamp.fromDate(item.createdAt),
      };
    }).toList();

    await _db
        .collection('users')
        .doc(barberId)
        .update({'gallery': updatedGallery});
  }

  Future<void> deleteGalleryItem({
    required String barberId,
    required String imageUrl,
    required List<GalleryItem> currentGallery,
  }) async {
    final updatedGallery = currentGallery
        .where((item) => item.url != imageUrl)
        .map((item) => item.toMap())
        .toList();

    await _db
        .collection('users')
        .doc(barberId)
        .update({'gallery': updatedGallery});
  }

  Future<void> toggleLike({
    required String barberId,
    required String imageUrl,
    required String currentUserId,
    required bool isLiked,
    required List<GalleryItem> currentGallery,
  }) async {
    final updatedGallery = currentGallery.map((item) {
      if (item.url != imageUrl) return item.toMap();
      final updatedLikes = List<String>.from(item.likes);
      if (isLiked) {
        updatedLikes.remove(currentUserId);
      } else {
        if (!updatedLikes.contains(currentUserId)) {
          updatedLikes.add(currentUserId);
        }
      }
      return {
        'url': item.url,
        'caption': item.caption,
        'likes': updatedLikes,
        'createdAt': Timestamp.fromDate(item.createdAt),
      };
    }).toList();

    await _db
        .collection('users')
        .doc(barberId)
        .update({'gallery': updatedGallery});
  }

  Future<void> updateWorkingHours(String barberId, Map<String, dynamic> data) async {
    final q = await _db
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .get();
    
    if (q.docs.isNotEmpty) {
      await _db.collection('workingHours').doc(q.docs.first.id).update(data);
    } else {
      await _db.collection('workingHours').add({
        'barberId': barberId,
        ...data,
      });
    }
  }
}

// ==================== ANA EKRAN ====================

class BarberProfileScreen extends StatefulWidget {
  final String barberId;

  const BarberProfileScreen({super.key, required this.barberId});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen>
    with SingleTickerProviderStateMixin {
  final _firebaseService = BarberFirebaseService();
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  // Profil verileri
  String _shopName = '';
  String _barberName = '';
  String _address = '';
  String _about = '';
  String? _profileImageUrl;
  double _rating = 0.0;
  int _reviewCount = 0;
  List<Review> _reviews = [];

  // Çalışma saatleri
  Map<String, bool> _dayStatus = {};
  String _openTime = '09:00';
  String _closeTime = '20:00';
  bool _isLoadingHours = true;

  // Hizmetler
  List<BarberService> _services = [];

  // Düzenleme durumları
  bool _isEditingShopName = false;
  bool _isEditingBarberName = false;
  bool _isEditingAddress = false;
  bool _isEditingAbout = false;
  bool _isEditingWorkingHours = false;

  // Controller'lar
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _barberNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _openTimeController = TextEditingController();
  final TextEditingController _closeTimeController = TextEditingController();

  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  // Çalışma saatleri için geçici state
  Map<String, bool> _tempDayStatus = {};
  
  // Stream aboneliği için
  StreamSubscription<DocumentSnapshot?>? _workingHoursSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenWorkingHours();
    _loadAllData();
  }

  @override
  void dispose() {
    _workingHoursSubscription?.cancel();
    _tabController.dispose();
    _shopNameController.dispose();
    _barberNameController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    _openTimeController.dispose();
    _closeTimeController.dispose();
    super.dispose();
  }

  // Çalışma saatleri dinleme metodu
  void _listenWorkingHours() {
    setState(() => _isLoadingHours = true);
    
    _workingHoursSubscription = _firebaseService
        .getWorkingHoursStream(widget.barberId)
        .listen((doc) {
      if (doc != null && doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _dayStatus = Map<String, bool>.from(data['dayStatus'] ?? {});
          _openTime = data['openTime'] ?? '09:00';
          _closeTime = data['closeTime'] ?? '20:00';
          _isLoadingHours = false;
        });
      } else {
        setState(() => _isLoadingHours = false);
      }
    }, onError: (e, stackTrace) {
      setState(() => _isLoadingHours = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Çalışma saati yüklenirken hata: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadProfile(),
      _loadReviews(),
      _loadServices(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadProfile() async {
    final doc = await _firebaseService.getBarberProfile(widget.barberId);
    if (!doc.exists) return;
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      _shopName = data['shopName'] ?? '';
      _barberName = data['nameSurname'] ?? '';
      _address = data['address'] ?? '';
      _about = data['about'] ?? '';
      _profileImageUrl = data['profileImageUrl'];
      _shopNameController.text = _shopName;
      _barberNameController.text = _barberName;
      _addressController.text = _address;
      _aboutController.text = _about;
    });
  }

  Future<void> _loadReviews() async {
    final reviews = await _firebaseService.getReviews(widget.barberId);
    double total = 0;
    for (var r in reviews) {
      total += r.rating;
    }
    setState(() {
      _reviews = reviews;
      _reviewCount = reviews.length;
      _rating = reviews.isEmpty ? 0.0 : total / reviews.length;
    });
  }

  Future<void> _loadServices() async {
    final services = await _firebaseService.getServices(widget.barberId);
    setState(() {
      _services = services;
    });
  }

  // ==================== PROFİL RESMİ YÜKLEME ====================

  Future<void> _pickAndUploadProfileImage() async {
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
              title: const Text('Kamerayla Çek',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
              title: const Text('Galeriden Seç',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (pickedFile != null) {
        setState(() => _isUploadingImage = true);
        final url = await _firebaseService.uploadProfileImage(widget.barberId, pickedFile);
        setState(() {
          _profileImageUrl = url;
          _isUploadingImage = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profil fotoğrafı güncellendi'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ==================== BİLGİ DÜZENLEME ====================

  Future<void> _saveField(String field, String value, VoidCallback onSuccess) async {
    if (value.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await _firebaseService.updateBarberProfile(widget.barberId, {field: value});
      onSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Güncellendi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _startEditShopName() {
    _shopNameController.text = _shopName;
    setState(() => _isEditingShopName = true);
  }

  void _saveShopName() {
    _saveField('shopName', _shopNameController.text.trim(), () {
      setState(() {
        _shopName = _shopNameController.text.trim();
        _isEditingShopName = false;
      });
    });
  }

  void _startEditBarberName() {
    _barberNameController.text = _barberName;
    setState(() => _isEditingBarberName = true);
  }

  void _saveBarberName() {
    _saveField('nameSurname', _barberNameController.text.trim(), () {
      setState(() {
        _barberName = _barberNameController.text.trim();
        _isEditingBarberName = false;
      });
    });
  }

  void _startEditAddress() {
    _addressController.text = _address;
    setState(() => _isEditingAddress = true);
  }

  void _saveAddress() {
    _saveField('address', _addressController.text.trim(), () {
      setState(() {
        _address = _addressController.text.trim();
        _isEditingAddress = false;
      });
    });
  }

  void _startEditAbout() {
    _aboutController.text = _about;
    setState(() => _isEditingAbout = true);
  }

  void _saveAbout() {
    _saveField('about', _aboutController.text.trim(), () {
      setState(() {
        _about = _aboutController.text.trim();
        if (_about.isEmpty) _about = 'Henüz açıklama eklenmemiş.';
        _isEditingAbout = false;
      });
    });
  }

  // ==================== ÇALIŞMA SAATLERİ DÜZENLEME ====================

  void _startEditWorkingHours() {
    _openTimeController.text = _openTime;
    _closeTimeController.text = _closeTime;
    _tempDayStatus = Map.from(_dayStatus);
    setState(() {
      _isEditingWorkingHours = true;
    });
  }

  void _toggleDayStatus(String dayKey) {
    setState(() {
      _tempDayStatus[dayKey] = !(_tempDayStatus[dayKey] ?? false);
    });
  }

  Future<void> _saveWorkingHours() async {
    final newOpenTime = _openTimeController.text.trim();
    final newCloseTime = _closeTimeController.text.trim();
    
    if (newOpenTime.isEmpty || newCloseTime.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen saatleri girin'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _firebaseService.updateWorkingHours(widget.barberId, {
        'openTime': newOpenTime,
        'closeTime': newCloseTime,
        'dayStatus': _tempDayStatus,
      });
      setState(() {
        _isEditingWorkingHours = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çalışma saatleri güncellendi'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _navigateToCustomerProfile(String customerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProfileViewScreen(customerId: customerId),
      ),
    );
  }

  // ==================== CHAT NAVIGASYON ====================
  
  void _navigateToChat() {
    final currentUserId = _firebaseService.currentUserId;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sohbet edebilmek için giriş yapmalısınız.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => BusinessChatListScreen(
      barberId: currentUserId,
    ),
  ),
);
  }

  // ==================== HİZMETLER BÖLÜMÜ (GÜNCELLENMİŞ) ====================

Widget _buildServicesSection() {
  return StreamBuilder<List<BarberService>>(
    stream: _firebaseService.servicesStream(widget.barberId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ),
        );
      }
      
      final services = snapshot.data ?? [];
      
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.content_cut, color: Color(0xFFD4AF37), size: 20),
                SizedBox(width: 8),
                Text(
                  ' Hizmetler ve Fiyatlar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (services.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Henüz hizmet eklenmemiş.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              // SCROLL EDİLEBİLİR LİSTE - maxHeight ile sınırlandırıldı
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5, // Ekranın yarısı kadar yükseklik
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const AlwaysScrollableScrollPhysics(), // Kaydırmayı aktif et
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Colors.grey,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.content_cut,
                              color: Color(0xFFD4AF37),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (service.description.isNotEmpty)
                                  Text(
                                    service.description,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${service.price.toStringAsFixed(0)} ₺',
                                style: const TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${service.durationMinutes} dk',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final isOwner = _firebaseService.currentUserId == widget.barberId;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Berber Profili', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // CHAT İKONU EKLENDİ
          IconButton(
            onPressed: _navigateToChat,
            icon: const Icon(Icons.chat, color: Color(0xFFD4AF37)),
            tooltip: 'Mesaj Gönder',
          ),
          if (isOwner)
            IconButton(
              onPressed: _pickAndUploadProfileImage,
              icon: const Icon(Icons.camera_alt, color: Color(0xFFD4AF37)),
              tooltip: 'Profil fotoğrafını değiştir',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : Stack(
              children: [
                NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(child: _buildProfileHeader(isOwner)),
                    SliverToBoxAdapter(child: _buildAboutSection(isOwner)),
                    SliverToBoxAdapter(child: _buildWorkingHoursSection(isOwner)),
                    SliverToBoxAdapter(child: _buildServicesSection()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          tabs: const [
                            Tab(text: ' Galeri'),
                            Tab(text: ' Yorumlar'),
                          ],
                          indicatorColor: const Color(0xFFD4AF37),
                          labelColor: const Color(0xFFD4AF37),
                          unselectedLabelColor: Colors.grey,
                          dividerColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _GalleryTab(
                        barberId: widget.barberId,
                        firebaseService: _firebaseService,
                        isOwner: isOwner,
                      ),
                      _ReviewsTab(
                        reviews: _reviews,
                        onTapCustomer: _navigateToCustomerProfile,
                      ),
                    ],
                  ),
                ),
                if (_isSaving || _isUploadingImage)
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

  Widget _buildProfileHeader(bool isOwner) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : null,
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
            ],
          ),
          const SizedBox(height: 14),
          
          // Dükkan Adı - Editable
          _buildEditableField(
            value: _shopName,
            isEditing: _isEditingShopName,
            controller: _shopNameController,
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            onEdit: _startEditShopName,
            onSave: _saveShopName,
            isOwner: isOwner,
          ),
          
          const SizedBox(height: 6),
          
          // Berber Adı - Editable
          _buildEditableField(
            value: _barberName,
            isEditing: _isEditingBarberName,
            controller: _barberNameController,
            textStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            onEdit: _startEditBarberName,
            onSave: _saveBarberName,
            isOwner: isOwner,
          ),
          
          const SizedBox(height: 12),
          
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
            const SizedBox(width: 4),
            Text(_rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                    color: Colors.grey, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('$_reviewCount yorum',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          
          // Adres - Editable
          _buildEditableField(
            value: _address,
            isEditing: _isEditingAddress,
            controller: _addressController,
            textStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            onEdit: _startEditAddress,
            onSave: _saveAddress,
            isOwner: isOwner,
            isAddress: true,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required TextStyle textStyle,
    required VoidCallback onEdit,
    required VoidCallback onSave,
    required bool isOwner,
    bool isAddress = false,
  }) {
    if (!isOwner) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isAddress) const Icon(Icons.location_on, color: Colors.grey, size: 14),
          if (isAddress) const SizedBox(width: 6),
          Flexible(
            child: Text(
              value.isEmpty ? 'Belirtilmemiş' : value,
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isAddress) const Icon(Icons.location_on, color: Colors.grey, size: 14),
        if (isAddress) const SizedBox(width: 6),
        if (isEditing)
          Expanded(
            child: TextField(
              controller: controller,
              style: textStyle,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSave(),
            ),
          )
        else
          Flexible(
            child: Text(
              value.isEmpty ? (isAddress ? 'Adres eklenmemiş' : 'Belirtilmemiş') : value,
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
        if (isOwner) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: isEditing ? onSave : onEdit,
            child: Container(
              padding: EdgeInsets.all(isAddress ? 4 : 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isEditing ? Icons.check : Icons.edit,
                color: const Color(0xFFD4AF37),
                size: isAddress ? 14 : 18,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAboutSection(bool isOwner) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              const Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
              const SizedBox(width: 8),
              const Text('Hakkımızda',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              if (isOwner) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _startEditAbout,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit,
                        color: Color(0xFFD4AF37), size: 16),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_isEditingAbout && isOwner)
            Column(
              children: [
                TextField(
                  controller: _aboutController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Dükkanınız hakkında bilgi yazın...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                      ),
                      child: const Text('Kaydet', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              _about.isEmpty ? 'Henüz açıklama eklenmemiş.' : _about,
              style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursSection(bool isOwner) {
    final days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
              const Text(' Çalışma Saatleri',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              if (isOwner) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _startEditWorkingHours,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Color(0xFFD4AF37), size: 16),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          
          if (_isLoadingHours)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              ),
            )
          else if (_isEditingWorkingHours && isOwner)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _openTimeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Açılış Saati',
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintText: '09:00',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _closeTimeController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Kapanış Saati',
                          labelStyle: const TextStyle(color: Colors.grey),
                          hintText: '20:00',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: const Color(0xFF2A2A2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final dayKey = (i + 1).toString();
                    final isOpen = _tempDayStatus[dayKey] ?? false;
                    return FilterChip(
                      label: Text(days[i]),
                      selected: isOpen,
                      onSelected: (_) => _toggleDayStatus(dayKey),
                      backgroundColor: const Color(0xFF2A2A2A),
                      selectedColor: const Color(0xFFD4AF37).withOpacity(0.3),
                      checkmarkColor: const Color(0xFFD4AF37),
                      labelStyle: TextStyle(
                        color: isOpen ? const Color(0xFFD4AF37) : Colors.white70,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditingWorkingHours = false),
                      child: const Text('İptal', style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveWorkingHours,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                      ),
                      child: const Text('Kaydet', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                Row(children: [
                  const Icon(Icons.access_time, color: Color(0xFFD4AF37), size: 18),
                  const SizedBox(width: 8),
                  Text('$_openTime - $_closeTime',
                      style: const TextStyle(color: Colors.white, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (i) {
                    final dayKey = (i + 1).toString();
                    final isOpen = _dayStatus[dayKey] ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFFD4AF37).withOpacity(0.15)
                            : Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isOpen
                              ? const Color(0xFFD4AF37).withOpacity(0.4)
                              : Colors.red.withOpacity(0.4),
                        ),
                      ),
                      child: Text(days[i],
                          style: TextStyle(
                              color: isOpen ? const Color(0xFFD4AF37) : Colors.red,
                              fontSize: 12)),
                    );
                  }),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ==================== GALERİ TAB ====================

class _GalleryTab extends StatefulWidget {
  final String barberId;
  final BarberFirebaseService firebaseService;
  final bool isOwner;

  const _GalleryTab({
    required this.barberId,
    required this.firebaseService,
    required this.isOwner,
  });

  @override
  State<_GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<_GalleryTab> {
  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinary = CloudinaryService();
  bool _isUploading = false;

  Future<void> _addGalleryImage() async {
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
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFD4AF37)),
              title: const Text('Galeriden Seç', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (pickedFile != null) {
        _showCaptionDialog(pickedFile);
      }
    } catch (e) {
      print('Resim seçme hatası: $e');
    }
  }

  Future<void> _showCaptionDialog(XFile imageFile) async {
    final captionController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Fotoğraf Açıklaması', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: captionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Açıklama girin...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _uploadImage(imageFile, captionController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('Yükle'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadImage(XFile imageFile, String caption) async {
    setState(() => _isUploading = true);
    try {
      await widget.firebaseService.uploadGalleryImage(
        widget.barberId, 
        imageFile, 
        caption,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf eklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _editCaption(GalleryItem item, List<GalleryItem> items) async {
    final captionController = TextEditingController(text: item.caption);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Açıklamayı Düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: captionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Açıklama girin...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firebaseService.updateGalleryCaption(
                barberId: widget.barberId,
                imageUrl: item.url,
                newCaption: captionController.text.trim(),
                currentGallery: items,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Açıklama güncellendi'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(GalleryItem item, List<GalleryItem> items) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Fotoğrafı Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu fotoğrafı silmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firebaseService.deleteGalleryItem(
                barberId: widget.barberId,
                imageUrl: item.url,
                currentGallery: items,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fotoğraf silindi'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showFullScreen(List<GalleryItem> items, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryFullScreen(
          items: items,
          initialIndex: index,
          isOwner: widget.isOwner,
          barberId: widget.barberId,
          firebaseService: widget.firebaseService,
        ),
      ),
    );
  }

  void _showLikers(BuildContext context, List<String> likerIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LikersSheet(likerIds: likerIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = widget.firebaseService.currentUserId;
    
    return Stack(
      children: [
        Column(
          children: [
            if (widget.isOwner)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: _addGalleryImage,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Fotoğraf Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: StreamBuilder<List<GalleryItem>>(
                stream: widget.firebaseService.galleryStream(widget.barberId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFD4AF37))
                    );
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Henüz galeri fotoğrafı yok.',
                                style: TextStyle(color: Colors.grey)),
                            SizedBox(height: 8),
                            Text('"Fotoğraf Ekle" butonu ile ekleme yapın.',
                                style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isLiked = currentUid != null && item.likes.contains(currentUid);
                      return _GalleryCard(
                        item: item,
                        isLiked: isLiked,
                        isOwner: widget.isOwner,
                        currentUid: currentUid,
                        onTap: () => _showFullScreen(items, index),
                        onLike: currentUid == null
                            ? null
                            : () async {
                                await widget.firebaseService.toggleLike(
                                  barberId: widget.barberId,
                                  imageUrl: item.url,
                                  currentUserId: currentUid!,
                                  isLiked: isLiked,
                                  currentGallery: items,
                                );
                              },
                        onEdit: widget.isOwner ? () => _editCaption(item, items) : null,
                        onDelete: widget.isOwner ? () => _confirmDelete(item, items) : null,
                        onLikersView: () => _showLikers(context, item.likes),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withOpacity(0.7),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  SizedBox(height: 16),
                  Text('Yükleniyor...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  final bool isLiked;
  final bool isOwner;
  final String? currentUid;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onLikersView;

  const _GalleryCard({
    required this.item,
    required this.isLiked,
    required this.isOwner,
    required this.currentUid,
    required this.onTap,
    required this.onLike,
    required this.onEdit,
    required this.onDelete,
    required this.onLikersView,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      item.url,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                  if (isOwner)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: onEdit,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.caption.isNotEmpty)
                    Text(
                      item.caption,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: onLike,
                        child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.grey,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: onLikersView,
                        child: Text(
                          '${item.likes.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
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

// ==================== GALERİ FULLSCREEN ====================

class _GalleryFullScreen extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  final bool isOwner;
  final String barberId;
  final BarberFirebaseService firebaseService;

  const _GalleryFullScreen({
    required this.items,
    required this.initialIndex,
    required this.isOwner,
    required this.barberId,
    required this.firebaseService,
  });

  @override
  State<_GalleryFullScreen> createState() => _GalleryFullScreenState();
}

class _GalleryFullScreenState extends State<_GalleryFullScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _editCaption() async {
    final captionController = TextEditingController(text: widget.items[_currentIndex].caption);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Açıklamayı Düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: captionController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Açıklama girin...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firebaseService.updateGalleryCaption(
                barberId: widget.barberId,
                imageUrl: widget.items[_currentIndex].url,
                newCaption: captionController.text.trim(),
                currentGallery: widget.items,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Açıklama güncellendi'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
            ),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('Fotoğrafı Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu fotoğrafı silmek istediğinize emin misiniz?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.firebaseService.deleteGalleryItem(
                barberId: widget.barberId,
                imageUrl: widget.items[_currentIndex].url,
                currentGallery: widget.items,
              );
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fotoğraf silindi'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLikers(BuildContext context) {
    final item = widget.items[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LikersSheet(likerIds: item.likes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_currentIndex];
    final currentUid = widget.firebaseService.currentUserId;
    final isLiked = currentUid != null && item.likes.contains(currentUid);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: const TextStyle(color: Colors.white),
        ),
        actions: widget.isOwner
            ? [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
                  onPressed: _editCaption,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (_, i) => Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.items[i].url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 60),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: const Color(0xFF1C1C1C).withOpacity(0.9),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.items[i].caption.isNotEmpty)
                      Text(
                        widget.items[i].caption,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (currentUid == null) return;
                            await widget.firebaseService.toggleLike(
                              barberId: widget.barberId,
                              imageUrl: widget.items[i].url,
                              currentUserId: currentUid,
                              isLiked: isLiked,
                              currentGallery: widget.items,
                            );
                          },
                          child: Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.red : Colors.grey,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showLikers(context),
                          child: Text(
                            '${widget.items[i].likes.length} beğeni',
                            style: const TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== YORUMLAR TAB ====================

class _ReviewsTab extends StatelessWidget {
  final List<Review> reviews;
  final Function(String customerId) onTapCustomer;

  const _ReviewsTab({
    required this.reviews,
    required this.onTapCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (reviews.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('Henüz yorum yapılmamış.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...reviews.map((r) => _ReviewCard(
                review: r,
                onTap: () => onTapCustomer(r.customerId),
              )),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTap;

  const _ReviewCard({
    required this.review,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onTap,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                  backgroundImage: review.customerProfileImageUrl != null
                      ? NetworkImage(review.customerProfileImageUrl!)
                      : null,
                  child: review.customerProfileImageUrl == null
                      ? Text(
                          review.customerName.isNotEmpty
                              ? review.customerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onTap,
                      child: Text(
                        review.customerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14),
                  const SizedBox(width: 3),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment,
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ==================== BEĞENENLER SHEET ====================

class _LikersSheet extends StatelessWidget {
  final List<String> likerIds;

  const _LikersSheet({required this.likerIds});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Beğenenler',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (likerIds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Henüz beğeni yok.', style: TextStyle(color: Colors.grey)),
          )
        else
          ...likerIds.map((uid) => _LikerTile(uid: uid)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _LikerTile extends StatelessWidget {
  final String uid;

  const _LikerTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(0xFF2A2A2A),
              child: Icon(Icons.person, color: Colors.grey),
            ),
            title: Text('...', style: TextStyle(color: Colors.white)),
          );
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['nameSurname'] ?? data['name'] ?? 'Kullanıcı';
        final photo = data['profileImageUrl'];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(name, style: const TextStyle(color: Colors.white)),
        );
      },
    );
  }
}

// ==================== MÜŞTERİ PROFİLİ ====================

class CustomerProfileViewScreen extends StatelessWidget {
  final String customerId;

  const CustomerProfileViewScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Müşteri Profili', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(customerId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            );
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text('Kullanıcı bulunamadı.', style: TextStyle(color: Colors.grey)),
            );
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['nameSurname'] ?? data['name'] ?? 'Kullanıcı';
          final email = data['email'] ?? 'E-posta yok';
          final phone = data['phone'] ?? 'Telefon yok';
          final photo = data['profileImageUrl'];

          return Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(email, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(phone, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}