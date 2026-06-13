import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'customer_chat_list.dart';

// ==================== LOGGER SINIFI ====================
enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
}

class AppLogger {
  static const String tag = 'CUSTOMER_APP';
  static bool isDebugMode = true;

  static const Map<LogLevel, String> _colors = {
    LogLevel.debug: '\x1B[36m',
    LogLevel.info: '\x1B[34m',
    LogLevel.warning: '\x1B[33m',
    LogLevel.error: '\x1B[31m',
    LogLevel.success: '\x1B[32m',
  };
  static const String _resetColor = '\x1B[0m';

  static void log(
    String message, {
    LogLevel level = LogLevel.info,
    dynamic error,
    StackTrace? stackTrace,
    String? methodName,
  }) {
    if (!isDebugMode) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    final emoji = _getEmoji(level);
    final method = methodName != null ? '[$methodName] ' : '';

    final logMessage =
        '$emoji $timestamp ${_colors[level]}[${level.name.toUpperCase()}]$_resetColor '
        '$method$message';

    // ignore: avoid_print
    print(logMessage);

    if (error != null) {
      // ignore: avoid_print
      print(
          '${_colors[LogLevel.error]}╔══════════════════ HATA DETAYI ══════════════════$_resetColor');
      // ignore: avoid_print
      print('${_colors[LogLevel.error]}║ Hata: $error$_resetColor');
      if (stackTrace != null) {
        // ignore: avoid_print
        print('${_colors[LogLevel.error]}║ Stack Trace:$_resetColor');
        // ignore: avoid_print
        print(stackTrace);
      }
      // ignore: avoid_print
      print(
          '${_colors[LogLevel.error]}╚════════════════════════════════════════════════╝$_resetColor');
    }
  }

  static void d(String message, {String? methodName}) =>
      log(message, level: LogLevel.debug, methodName: methodName);

  static void i(String message, {String? methodName}) =>
      log(message, level: LogLevel.info, methodName: methodName);

  static void w(String message, {String? methodName}) =>
      log(message, level: LogLevel.warning, methodName: methodName);

  static void e(String message,
          {dynamic error,
          StackTrace? stackTrace,
          String? methodName}) =>
      log(message,
          level: LogLevel.error,
          error: error,
          stackTrace: stackTrace,
          methodName: methodName);

  static void s(String message, {String? methodName}) =>
      log(message, level: LogLevel.success, methodName: methodName);

  static String _getEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  static Future<T> performance<T>(
      String operation, Future<T> Function() callback) async {
    final startTime = DateTime.now();
    i('⏱️ $operation başladı');

    try {
      final result = await callback();
      final duration = DateTime.now().difference(startTime);
      s('⏱️ $operation tamamlandı (${duration.inMilliseconds}ms)');
      return result;
    } catch (error, stack) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.e('⏱️ $operation başarısız (${duration.inMilliseconds}ms)',
          error: error, stackTrace: stack);
      rethrow;
    }
  }
}

// ==================== CLOUDINARY SERVİSİ ====================
class CloudinaryService {
  static const String cloudName = 'du6swar0j';
  static const String uploadPreset = 'ml_default';

  Future<String> uploadImage(XFile imageFile) async {
    AppLogger.i('Cloudinary yükleme başlıyor: ${imageFile.path}',
        methodName: 'CloudinaryService.uploadImage');

    try {
      final Uint8List bytes = await imageFile.readAsBytes();
      AppLogger.d(
          'Dosya boyutu: ${(bytes.length / 1024).toStringAsFixed(2)} KB',
          methodName: 'CloudinaryService.uploadImage');

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'customer_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final url = data['secure_url'] as String;
        AppLogger.s('Cloudinary yükleme başarılı: $url',
            methodName: 'CloudinaryService.uploadImage');
        return url;
      } else {
        final errorMessage =
            (data['error'] as Map<String, dynamic>?)?['message'] ??
                'Bilinmeyen hata';
        AppLogger.e('Cloudinary hata yanıtı: $errorMessage',
            methodName: 'CloudinaryService.uploadImage');
        throw Exception('Cloudinary yükleme hatası: $errorMessage');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Cloudinary yükleme başarısız',
          error: e,
          stackTrace: stackTrace,
          methodName: 'CloudinaryService.uploadImage');
      rethrow;
    }
  }
}

// ==================== MODELLER ====================
class Appointment {
  final String id;
  final String barberId;
  final String barberName;
  final String barberShopName;
  final String serviceName;
  final double price;
  final int durationMinutes;
  final DateTime dateTime;
  final String status;

  Appointment({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.barberShopName,
    required this.serviceName,
    required this.price,
    required this.durationMinutes,
    required this.dateTime,
    required this.status,
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    return Appointment(
      id: id,
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      barberShopName: map['barberShopName'] ?? '',
      serviceName: map['serviceName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      durationMinutes: map['durationMinutes'] ?? 0,
      dateTime: (map['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
    );
  }
}

class FavoriteBarber {
  final String barberId;
  final String barberName;
  final String shopName;
  final String? profileImageUrl;
  final double rating;
  final String address;

  FavoriteBarber({
    required this.barberId,
    required this.barberName,
    required this.shopName,
    this.profileImageUrl,
    required this.rating,
    required this.address,
  });

  factory FavoriteBarber.fromMap(Map<String, dynamic> map) {
    return FavoriteBarber(
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      shopName: map['shopName'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      rating: (map['rating'] ?? 0).toDouble(),
      address: map['address'] ?? '',
    );
  }
}

// YORUM MODELİ - CustomerReview sınıfı
class CustomerReview {
  final String id;
  final String barberId;
  final String barberName;
  final String barberShopName;
  final String? barberProfileImageUrl;
  final double rating;
  final String comment;
  final DateTime createdAt;

  CustomerReview({
    required this.id,
    required this.barberId,
    required this.barberName,
    required this.barberShopName,
    this.barberProfileImageUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory CustomerReview.fromMap(String id, Map<String, dynamic> map) {
    return CustomerReview(
      id: id,
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      barberShopName: map['barberShopName'] ?? '',
      barberProfileImageUrl: map['barberProfileImageUrl'],
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// ==================== FIREBASE SERVİSİ ====================
class CustomerFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Future<DocumentSnapshot> getUserById(String uid) async {
    AppLogger.i('Kullanıcı bilgisi getiriliyor: $uid',
        methodName: 'getUserById');
    try {
      final result = await _firestore.collection('users').doc(uid).get();
      if (result.exists) {
        AppLogger.s('Kullanıcı bulundu: $uid', methodName: 'getUserById');
      } else {
        AppLogger.w('Kullanıcı bulunamadı: $uid', methodName: 'getUserById');
      }
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('Kullanıcı getirme hatası',
          error: e, stackTrace: stackTrace, methodName: 'getUserById');
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    AppLogger.i('Kullanıcı güncelleniyor: $uid', methodName: 'updateUser');
    try {
      await _firestore.collection('users').doc(uid).update(data);
      AppLogger.s('Kullanıcı güncellendi: $uid', methodName: 'updateUser');
    } catch (e, stackTrace) {
      AppLogger.e('Kullanıcı güncelleme hatası',
          error: e, stackTrace: stackTrace, methodName: 'updateUser');
      rethrow;
    }
  }

  Future<String> uploadProfileImage(String userId, XFile imageFile) async {
    AppLogger.i('Profil fotoğrafı yükleniyor (Cloudinary)',
        methodName: 'uploadProfileImage');

    try {
      final downloadUrl = await AppLogger.performance(
        'Cloudinary yükleme',
        () => _cloudinaryService.uploadImage(imageFile),
      );

      await updateUser(userId, {'profileImageUrl': downloadUrl});

      AppLogger.s('Profil fotoğrafı kaydedildi', methodName: 'uploadProfileImage');
      return downloadUrl;
    } catch (e, stackTrace) {
      AppLogger.e('Profil fotoğrafı yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: 'uploadProfileImage');
      rethrow;
    }
  }

  // MÜŞTERİNİN YAPTIĞI YORUMLARI GETİR
  Future<List<CustomerReview>> getMyReviews(String userId) async {
    // ignore: avoid_print
    print('\n┌─────────────────────────────────────────────────┐');
    // ignore: avoid_print
    print('│ SERVİS: getMyReviews çağrıldı');
    // ignore: avoid_print
    print('│ userId: $userId');
    // ignore: avoid_print
    print('└─────────────────────────────────────────────────┘');
    
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('customerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      // ignore: avoid_print
      print('Sorgu sonucu: ${snapshot.docs.length} doküman');
      
      final result = snapshot.docs.map((doc) {
        final data = doc.data();
        return CustomerReview(
          id: doc.id,
          barberId: data['barberId'] ?? '',
          barberName: data['barberName'] ?? '',
          barberShopName: data['barberShopName'] ?? '',
          barberProfileImageUrl: data['barberProfileImageUrl'],
          rating: (data['rating'] ?? 0).toDouble(),
          comment: data['comment'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      
      // ignore: avoid_print
      print('Dönüştürülen: ${result.length} yorum\n');
      return result;
      
    } catch (e) {
      // ignore: avoid_print
      print('SERVİS HATASI: $e\n');
      rethrow;
    }
  }

  Future<List<FavoriteBarber>> getFavoriteBarbers(String userId) async {
    AppLogger.i('Favori berberler getiriliyor: $userId', methodName: 'getFavoriteBarbers');
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final favoriteIds = List<String>.from(userDoc.data()?['favoriteBarbers'] ?? []);

      if (favoriteIds.isEmpty) {
        return [];
      }

      final List<FavoriteBarber> favorites = [];
      for (String barberId in favoriteIds) {
        final barberDoc = await _firestore.collection('users').doc(barberId).get();
        if (barberDoc.exists) {
          final data = barberDoc.data()!;
          
          final reviewsSnapshot = await _firestore
              .collection('reviews')
              .where('barberId', isEqualTo: barberId)
              .get();
          
          double totalRating = 0;
          for (var review in reviewsSnapshot.docs) {
            totalRating += (review.data()['rating'] ?? 0).toDouble();
          }
          final averageRating = reviewsSnapshot.docs.isEmpty ? 0 : totalRating / reviewsSnapshot.docs.length;

          favorites.add(FavoriteBarber(
            barberId: barberId,
            barberName: data['nameSurname'] ?? 'Berber',
            shopName: data['shopName'] ?? 'Dükkan',
            profileImageUrl: data['profileImageUrl'],
            rating: averageRating.toDouble(), 
            address: data['address'] ?? 'Adres yok',
          ));
        }
      }

      AppLogger.s('${favorites.length} favori berber bulundu',
          methodName: 'getFavoriteBarbers');
      return favorites;
    } catch (e, stackTrace) {
      AppLogger.e('Favori berber getirme hatası',
          error: e, stackTrace: stackTrace, methodName: 'getFavoriteBarbers');
      rethrow;
    }
  }

  Future<void> removeFavoriteBarber(String userId, String barberId) async {
    AppLogger.i('Favori berber siliniyor: $barberId', methodName: 'removeFavoriteBarber');
    try {
      await _firestore.collection('users').doc(userId).update({
        'favoriteBarbers': FieldValue.arrayRemove([barberId])
      });
      AppLogger.s('Favori berber silindi', methodName: 'removeFavoriteBarber');
    } catch (e, stackTrace) {
      AppLogger.e('Favori berber silme hatası',
          error: e, stackTrace: stackTrace, methodName: 'removeFavoriteBarber');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats(String userId) async {
    AppLogger.i('İstatistikler getiriliyor', methodName: 'getStats');
    try {
      final favoriteCount = (await getFavoriteBarbers(userId)).length;

      return {
        'favoriteCount': favoriteCount,
      };
    } catch (e, stackTrace) {
      AppLogger.e('İstatistik getirme hatası',
          error: e, stackTrace: stackTrace, methodName: 'getStats');
      rethrow;
    }
  }
}

// ==================== MÜŞTERİ PROFİL EKRANI ====================
class CustomerProfileScreen extends StatefulWidget {
  final String customerId;

  const CustomerProfileScreen({super.key, required this.customerId});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final CustomerFirestoreService _firestoreService = CustomerFirestoreService();
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ImagePicker _imagePicker = ImagePicker();

  // Profil bilgileri
  String _fullName = 'Yükleniyor...';
  String _email = 'Yükleniyor...';
  String _phone = 'Yükleniyor...';
  String _address = 'Yükleniyor...';
  String? _profileImageUrl;
  DateTime? _birthDate;

  // Düzenleme durumları
  bool _isEditingFullName = false;
  bool _isEditingPhone = false;
  bool _isEditingAddress = false;
  bool _isEditingBirthDate = false;

  // Controller'lar
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Veriler
  List<CustomerReview> _myReviews = [];
  List<FavoriteBarber> _favoriteBarbers = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  bool _isLoadingReviews = true;
  bool _isLoadingFavorites = true;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    AppLogger.i('Müşteri profil ekranı başlatılıyor', methodName: 'initState');
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    AppLogger.i('Tüm veriler yükleniyor', methodName: '_loadAllData');
    setState(() => _isLoading = true);

    try {
      await AppLogger.performance('Tüm verileri yükle', () async {
        await Future.wait([
          _loadProfileData(),
          _loadMyReviews(),
          _loadFavoriteBarbers(),
          _loadStats(),
        ]);
        return null;
      });
      AppLogger.s('Tüm veriler başarıyla yüklendi', methodName: '_loadAllData');
    } catch (e, stackTrace) {
      AppLogger.e('Veri yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: '_loadAllData');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    AppLogger.i('Profil verileri yükleniyor', methodName: '_loadProfileData');

    if (currentUserId == null) return;

    try {
      final userDoc = await _firestoreService.getUserById(currentUserId!);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _fullName = data['fullName'] ?? data['nameSurname'] ?? 'İsim girilmemiş';
          _email = data['email'] ?? 'E-posta yok';
          _phone = data['phone'] ?? 'Telefon yok';
          _address = data['address'] ?? 'Adres yok';
          _profileImageUrl = data['profileImageUrl'];
          if (data['birthDate'] != null) {
            _birthDate = (data['birthDate'] as Timestamp).toDate();
          }
        });

        _fullNameController.text = _fullName;
        _phoneController.text = _phone;
        _addressController.text = _address;
      }
    } catch (e, stackTrace) {
      AppLogger.e('Profil verisi yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: '_loadProfileData');
    }
  }

  Future<void> _loadMyReviews() async {
    AppLogger.i('Yorumlar yükleniyor', methodName: '_loadMyReviews');
    setState(() => _isLoadingReviews = true);

    try {
      // ============ 1. OTURUM KONTROLÜ ============
      // ignore: avoid_print
      print('\n╔════════════════════════════════════════════════════════════╗');
      // ignore: avoid_print
      print('║              YORUM DEBUG BAŞLANGIÇ                         ║');
      // ignore: avoid_print
      print('╚════════════════════════════════════════════════════════════╝');
      
      // ignore: avoid_print
      print('\n📱 [1] OTURUM BİLGİLERİ');
      // ignore: avoid_print
      print('    Kullanıcı ID: ${currentUserId ?? "NULL - Oturum açık değil!"}');
      
      if (currentUserId == null) {
        // ignore: avoid_print
        print('    ❌ HATA: Kullanıcı oturumu açık değil!');
        setState(() => _isLoadingReviews = false);
        return;
      }
      
      // ============ 2. TÜM YORUMLARI KONTROL ET ============
      // ignore: avoid_print
      print('\n📊 [2] REVIEWS KOLEKSİYONU KONTROLÜ');
      
      final allReviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .get();
      
      // ignore: avoid_print
      print('    Toplam yorum sayısı: ${allReviewsSnapshot.docs.length}');
      
      if (allReviewsSnapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('    ⚠️ UYARI: "reviews" koleksiyonunda hiç belge yok!');
        // ignore: avoid_print
        print('    💡 Çözüm: Önce bir yorum oluşturmanız gerekiyor.');
      } else {
        // ignore: avoid_print
        print('    ✅ "reviews" koleksiyonunda ${allReviewsSnapshot.docs.length} belge var.');
        
        // Her bir yorumu detaylı göster (ilk 5)
        final showCount = allReviewsSnapshot.docs.length > 5 ? 5 : allReviewsSnapshot.docs.length;
        // ignore: avoid_print
        print('\n    📝 İLK $showCount YORUMUN DETAYI:');
        
        for (int i = 0; i < showCount; i++) {
          final doc = allReviewsSnapshot.docs[i];
          final data = doc.data();
          
          // ignore: avoid_print
          print('\n    ┌─────────────────────────────────────────────────');
          // ignore: avoid_print
          print('    │ Yorum #${i+1}');
          // ignore: avoid_print
          print('    │ Belge ID: ${doc.id}');
          // ignore: avoid_print
          print('    │');
          // ignore: avoid_print
          print('    │ 🔑 Tüm Alanlar: ${data.keys.join(", ")}');
          // ignore: avoid_print
          print('    │');
          
          // Her alanı tek tek göster
          data.forEach((key, value) {
            String valueStr = value.toString();
            if (valueStr.length > 50) valueStr = valueStr.substring(0, 50) + '...';
            // ignore: avoid_print
            print('    │ 📍 $key: $valueStr');
          });
          
          // ignore: avoid_print
          print('    └─────────────────────────────────────────────────');
        }
        
        if (allReviewsSnapshot.docs.length > 5) {
          // ignore: avoid_print
          print('\n    ... ve ${allReviewsSnapshot.docs.length - 5} yorum daha.');
        }
      }
      
      // ============ 3. CUSTOMER ID İLE ARA ============
      // ignore: avoid_print
      print('\n🔍 [3] CUSTOMER_ID İLE ARAMA');
      // ignore: avoid_print
      print('    Aranan değer: $currentUserId');
      
      final myReviewsQuery = await FirebaseFirestore.instance
          .collection('reviews')
          .where('customerId', isEqualTo: currentUserId)
          .get();
      
      // ignore: avoid_print
      print('    "customerId" ile bulunan: ${myReviewsQuery.docs.length} yorum');
      
      if (myReviewsQuery.docs.isEmpty) {
        // ignore: avoid_print
        print('    ⚠️ "customerId" alanı ile hiç yorum bulunamadı!');
        // ignore: avoid_print
        print('    💡 Alternatif alan adlarını kontrol ediyorum...');
        
        // ============ 4. ALTERNATİF ALAN ADLARINI DENE ============
        // ignore: avoid_print
        print('\n🔎 [4] ALTERNATİF ALAN ADLARI İLE ARAMA');
        
        final alternativeFields = {
          'userId': 'userId alanı',
          'customer_id': 'customer_id alanı', 
          'user_id': 'user_id alanı',
          'uid': 'uid alanı',
          'customerUid': 'customerUid alanı',
          'authorId': 'authorId alanı',
          'createdBy': 'createdBy alanı',
        };
        
        bool foundAny = false;
        
        for (var entry in alternativeFields.entries) {
          final fieldName = entry.key;
          final fieldDesc = entry.value;
          
          try {
            final altQuery = await FirebaseFirestore.instance
                .collection('reviews')
                .where(fieldName, isEqualTo: currentUserId)
                .get();
            
            if (altQuery.docs.isNotEmpty) {
              // ignore: avoid_print
              print('\n    ✅ $fieldDesc ile ${altQuery.docs.length} yorum BULUNDU!');
              // ignore: avoid_print
              print('       Örnek yorum verisi:');
              final sampleData = altQuery.docs.first.data();
              sampleData.forEach((key, value) {
                // ignore: avoid_print
                print('         - $key: $value');
              });
              foundAny = true;
            } else {
              // ignore: avoid_print
              print('    ❌ $fieldDesc ile yorum bulunamadı');
            }
          } catch (e) {
            // ignore: avoid_print
            print('    ⚠️ $fieldDesc sorgusu hata verdi: $e');
          }
        }
        
        if (!foundAny) {
          // ignore: avoid_print
          print('\n    ❌ HİÇBİR ALAN ADI İLE EŞLEŞME BULUNAMADI!');
          // ignore: avoid_print
          print('    📌 ÖNERİ: Firestore\'daki yorum belgelerinde hangi alan adının');
          // ignore: avoid_print
          print('             kullanıldığını kontrol edin.');
          // ignore: avoid_print
          print('             Yukarıdaki "Tüm Alanlar" bölümünde görebilirsiniz.');
        }
        
      } else {
        // ignore: avoid_print
        print('    ✅ "customerId" alanı ile ${myReviewsQuery.docs.length} yorum bulundu!');
        
        // Bulunan yorumları göster
        for (var doc in myReviewsQuery.docs) {
          // ignore: avoid_print
          print('\n    📝 Bulunan yorum:');
          // ignore: avoid_print
          print('       ID: ${doc.id}');
          final data = doc.data();
          data.forEach((key, value) {
            // ignore: avoid_print
            print('       $key: $value');
          });
        }
      }
      
      // ============ 5. SERVİS METODU İLE VERİ ÇEK ============
      // ignore: avoid_print
      print('\n📦 [5] SERVİS METODU İLE VERİ ÇEKME');
      
      final reviews = await _firestoreService.getMyReviews(currentUserId!);
      // ignore: avoid_print
      print('    Servis metodundan dönen yorum sayısı: ${reviews.length}');
      
      if (reviews.isNotEmpty) {
        // ignore: avoid_print
        print('\n    📝 İlk yorum detayı:');
        // ignore: avoid_print
        print('       - Berber Dükkan: ${reviews.first.barberShopName}');
        // ignore: avoid_print
        print('       - Berber Adı: ${reviews.first.barberName}');
        // ignore: avoid_print
        print('       - Puan: ${reviews.first.rating}');
        // ignore: avoid_print
        print('       - Yorum: ${reviews.first.comment}');
        // ignore: avoid_print
        print('       - Tarih: ${reviews.first.createdAt}');
      }
      
      // ============ 6. SONUÇ ÖZETİ ============
      // ignore: avoid_print
      print('\n╔════════════════════════════════════════════════════════════╗');
      // ignore: avoid_print
      print('║                    DEBUG SONUÇ ÖZETİ                       ║');
      // ignore: avoid_print
      print('╠════════════════════════════════════════════════════════════╣');
      // ignore: avoid_print
      print('║ Toplam yorum: ${allReviewsSnapshot.docs.length}                                          ║');
      // ignore: avoid_print
      print('║ Kullanıcıya ait: ${reviews.length}                                          ║');
      
      if (allReviewsSnapshot.docs.isNotEmpty && reviews.isEmpty) {
        // ignore: avoid_print
        print('╠════════════════════════════════════════════════════════════╣');
        // ignore: avoid_print
        print('║ ⚠️  UYARI: Yorumlar var ama kullanıcıya ait değil!         ║');
        // ignore: avoid_print
        print('║                                                            ║');
        // ignore: avoid_print
        print('║ ÇÖZÜM: Yukarıdaki "Tüm Alanlar" bölümüne bakın.            ║');
        // ignore: avoid_print
        print('║        Hangi alan adının kullanıldığını bulun ve           ║');
        // ignore: avoid_print
        print('║        getMyReviews metodundaki "where" koşulunu güncelleyin.║');
      } else if (allReviewsSnapshot.docs.isEmpty) {
        // ignore: avoid_print
        print('╠════════════════════════════════════════════════════════════╣');
        // ignore: avoid_print
        print('║ ⚠️  UYARI: Veritabanında hiç yorum yok!                    ║');
        // ignore: avoid_print
        print('║                                                            ║');
        // ignore: avoid_print
        print('║ ÇÖZÜM: Önce bir berbere yorum yapın.                       ║');
      } else if (reviews.isNotEmpty) {
        // ignore: avoid_print
        print('╠════════════════════════════════════════════════════════════╣');
        // ignore: avoid_print
        print('║ ✅ BAŞARILI: Yorumlar başarıyla yüklendi!                  ║');
      }
      
      // ignore: avoid_print
      print('╚════════════════════════════════════════════════════════════╝\n');
      
      setState(() {
        _myReviews = reviews;
        _isLoadingReviews = false;
      });
      
      if (reviews.isEmpty && allReviewsSnapshot.docs.isNotEmpty) {
        _showSnackBar('Size ait yorum bulunamadı. Farklı bir hesapla mı yorum yaptınız?', isError: false);
      } else if (allReviewsSnapshot.docs.isEmpty) {
        _showSnackBar('Henüz hiç yorum yapılmamış. İlk yorumu siz yapın!', isError: false);
      } else if (reviews.isNotEmpty) {
        _showSnackBar('${reviews.length} yorumunuz yüklendi', isError: false);
      }
      
    } catch (e, stackTrace) {
      // ============ HATA DETAYI ============
      // ignore: avoid_print
      print('\n╔════════════════════════════════════════════════════════════╗');
      // ignore: avoid_print
      print('║                    YORUM YÜKLEME HATASI                     ║');
      // ignore: avoid_print
      print('╠════════════════════════════════════════════════════════════╣');
      // ignore: avoid_print
      print('║ HATA TİPİ: ${e.runtimeType}');
      // ignore: avoid_print
      print('║ HATA MESAJI: $e');
      // ignore: avoid_print
      print('╠════════════════════════════════════════════════════════════╣');
      // ignore: avoid_print
      print('║ STACK TRACE:');
      // ignore: avoid_print
      print('║ $stackTrace');
      // ignore: avoid_print
      print('╚════════════════════════════════════════════════════════════╝\n');
      
      AppLogger.e('Yorum yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: '_loadMyReviews');
      setState(() => _isLoadingReviews = false);
      _showSnackBar('Yorumlar yüklenirken hata oluştu: ${e.toString().substring(0, 100)}', isError: true);
    }
  }

  Future<void> _loadFavoriteBarbers() async {
    AppLogger.i('Favori berberler yükleniyor', methodName: '_loadFavoriteBarbers');
    setState(() => _isLoadingFavorites = true);

    try {
      final favorites = await _firestoreService.getFavoriteBarbers(currentUserId!);
      setState(() {
        _favoriteBarbers = favorites;
        _isLoadingFavorites = false;
      });
    } catch (e, stackTrace) {
      AppLogger.e('Favori berber yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: '_loadFavoriteBarbers');
      setState(() => _isLoadingFavorites = false);
    }
  }

  Future<void> _loadStats() async {
    AppLogger.i('İstatistikler yükleniyor', methodName: '_loadStats');
    try {
      final stats = await _firestoreService.getStats(currentUserId!);
      setState(() {
        _stats = stats;
      });
    } catch (e, stackTrace) {
      AppLogger.e('İstatistik yükleme hatası',
          error: e, stackTrace: stackTrace, methodName: '_loadStats');
    }
  }

  // ==================== DÜZENLEME FONKSİYONLARI ====================
  void _startEditFullName() {
    _fullNameController.text = _fullName;
    setState(() => _isEditingFullName = true);
  }

  void _saveFullName() async {
    final newName = _fullNameController.text.trim();
    if (newName.isEmpty) {
      _showSnackBar('İsim boş olamaz', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentUserId!, {'fullName': newName, 'nameSurname': newName});
      setState(() {
        _fullName = newName;
        _isEditingFullName = false;
        _isSaving = false;
      });
      _showSnackBar('İsim güncellendi');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  void _startEditPhone() {
    _phoneController.text = _phone;
    setState(() => _isEditingPhone = true);
  }

  void _savePhone() async {
    final newPhone = _phoneController.text.trim();
    if (newPhone.isEmpty) {
      _showSnackBar('Telefon boş olamaz', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentUserId!, {'phone': newPhone});
      setState(() {
        _phone = newPhone;
        _isEditingPhone = false;
        _isSaving = false;
      });
      _showSnackBar('Telefon güncellendi');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  void _startEditAddress() {
    _addressController.text = _address;
    setState(() => _isEditingAddress = true);
  }

  void _saveAddress() async {
    final newAddress = _addressController.text.trim();
    if (newAddress.isEmpty) {
      _showSnackBar('Adres boş olamaz', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentUserId!, {'address': newAddress});
      setState(() {
        _address = newAddress;
        _isEditingAddress = false;
        _isSaving = false;
      });
      _showSnackBar('Adres güncellendi');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  void _startEditBirthDate() {
    setState(() => _isEditingBirthDate = true);
  }

  Future<void> _saveBirthDate(DateTime newDate) async {
    setState(() => _isSaving = true);
    try {
      await _firestoreService.updateUser(currentUserId!, {'birthDate': Timestamp.fromDate(newDate)});
      setState(() {
        _birthDate = newDate;
        _isEditingBirthDate = false;
        _isSaving = false;
      });
      _showSnackBar('Doğum tarihi güncellendi');
    } catch (e) {
      setState(() => _isSaving = false);
      _showSnackBar('Hata: $e', isError: true);
    }
  }

  // ==================== ŞİFRE DEĞİŞTİRME ====================
  Future<void> _changePassword() async {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();
    
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1C1C1C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock_reset, color: Color(0xFFD4AF37)),
                SizedBox(width: 10),
                Text('Şifre Değiştir', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Mevcut Şifre',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4AF37)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mevcut şifrenizi girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4AF37)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Yeni şifrenizi girin';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Yeni Şifre (Tekrar)',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFD4AF37)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifreyi tekrar girin';
                        }
                        if (value != newPasswordController.text) {
                          return 'Şifreler eşleşmiyor';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('İptal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context);
                    setState(() => _isSaving = true);
                    
                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      final credential = EmailAuthProvider.credential(
                        email: user!.email!,
                        password: currentPasswordController.text,
                      );
                      
                      await user.reauthenticateWithCredential(credential);
                      await user.updatePassword(newPasswordController.text);
                      
                      _showSnackBar('Şifre başarıyla değiştirildi');
                      AppLogger.s('Şifre değiştirildi', methodName: '_changePassword');
                    } on FirebaseAuthException catch (e) {
                      String errorMessage;
                      switch (e.code) {
                        case 'wrong-password':
                          errorMessage = 'Mevcut şifre yanlış';
                          break;
                        case 'weak-password':
                          errorMessage = 'Şifre çok zayıf';
                          break;
                        case 'requires-recent-login':
                          errorMessage = 'Lütfen önce tekrar giriş yapın';
                          break;
                        default:
                          errorMessage = 'Hata: ${e.message}';
                      }
                      _showSnackBar(errorMessage, isError: true);
                      AppLogger.e('Şifre değiştirme hatası', error: e);
                    } catch (e) {
                      _showSnackBar('Beklenmeyen hata: $e', isError: true);
                      AppLogger.e('Şifre değiştirme hatası', error: e);
                    } finally {
                      setState(() => _isSaving = false);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Değiştir'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== PROFİL FOTOĞRAFI ====================
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
        maxWidth: 500,
        maxHeight: 500,
      );

      if (pickedFile != null) {
        await _uploadImage(pickedFile);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Resim seçme hatası',
          error: e, stackTrace: stackTrace, methodName: '_pickImage');
    }
  }

  Future<void> _uploadImage(XFile imageFile) async {
    if (currentUserId == null) {
      _showSnackBar('Oturum açık değil!', isError: true);
      return;
    }

    setState(() => _isUploadingImage = true);

    try {
      final imageUrl = await _firestoreService.uploadProfileImage(currentUserId!, imageFile);
      setState(() {
        _profileImageUrl = imageUrl;
        _isUploadingImage = false;
      });
      _showSnackBar('Profil fotoğrafı güncellendi');
    } catch (e) {
      setState(() => _isUploadingImage = false);
      _showSnackBar('Yükleme hatası: $e', isError: true);
    }
  }

  // ==================== YARDIMCI FONKSİYONLAR ====================
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    
    if (difference.inDays == 0) {
      return 'Bugün';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} hafta önce';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} ay önce';
    } else {
      return '${(difference.inDays / 365).floor()} yıl önce';
    }
  }

  // ==================== BUILD ====================
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
            onPressed: () {
              AppLogger.i('Mesajlar sayfasına gidiliyor', methodName: 'CustomerProfileScreen - Mesajlar');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerChatList(),
                ),
              );
            },
            icon: const Icon(Icons.chat, color: Color(0xFFD4AF37)),
            tooltip: 'Mesajlar',
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
                      const SizedBox(height: 20),
                      _buildStatsSection(),
                      const SizedBox(height: 20),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        height: 50,
                        child: TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: ' Yorumlarım', icon: Icon(Icons.rate_review)),
                            Tab(text: ' Favoriler', icon: Icon(Icons.favorite)),
                            Tab(text: ' Bilgilerim', icon: Icon(Icons.info)),
                          ],
                          indicatorColor: const Color(0xFFD4AF37),
                          labelColor: const Color(0xFFD4AF37),
                          unselectedLabelColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 450,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildMyReviewsTab(),
                            _buildFavoritesTab(),
                            _buildPersonalInfoTab(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
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

  // ==================== PROFİL BAŞLIK ====================
  Widget _buildProfileHeader() {
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
                radius: 60,
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                    ? NetworkImage(_profileImageUrl!)
                    : null,
                child: _profileImageUrl == null || _profileImageUrl!.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Color(0xFFD4AF37))
                    : null,
              ),
              if (_isUploadingImage)
                Container(
                  width: 120,
                  height: 120,
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F0F0F), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isEditingFullName)
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _fullNameController,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                    onSubmitted: (_) => _saveFullName(),
                  ),
                )
              else
                Text(
                  _fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isEditingFullName ? _saveFullName : _startEditFullName,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEditingFullName ? Icons.check : Icons.edit,
                    color: const Color(0xFFD4AF37),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _email,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ==================== İSTATİSTİKLER ====================
  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.rate_review, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(height: 4),
                Text(
                  '${_myReviews.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('Yorumum', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.favorite, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(height: 4),
                Text(
                  '${_stats['favoriteCount'] ?? 0}',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Text('Favori Berber', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== YORUMLARIM TAB ====================
  Widget _buildMyReviewsTab() {
    if (_isLoadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myReviews.isEmpty) {
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
              Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('Henüz yorum yapmamışsınız.', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text('Randevu aldıktan sonra berberi değerlendirin.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _myReviews.length,
      itemBuilder: (context, index) {
        final review = _myReviews[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                    backgroundImage: review.barberProfileImageUrl != null && review.barberProfileImageUrl!.isNotEmpty
                        ? NetworkImage(review.barberProfileImageUrl!)
                        : null,
                    child: review.barberProfileImageUrl == null || review.barberProfileImageUrl!.isEmpty
                        ? const Icon(Icons.store, color: Color(0xFFD4AF37), size: 20)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.barberShopName,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          review.barberName,
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            review.rating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(review.createdAt),
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
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
      },
    );
  }

  // ==================== FAVORİLER TAB ====================
  Widget _buildFavoritesTab() {
    if (_isLoadingFavorites) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_favoriteBarbers.isEmpty) {
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
              Icon(Icons.favorite_border, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text('Favori berberiniz bulunmuyor.', style: TextStyle(color: Colors.grey)),
              SizedBox(height: 8),
              Text('Beğendiğiniz berberleri favorilere ekleyin.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _favoriteBarbers.length,
      itemBuilder: (context, index) {
        final barber = _favoriteBarbers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                backgroundImage: barber.profileImageUrl != null && barber.profileImageUrl!.isNotEmpty
                    ? NetworkImage(barber.profileImageUrl!)
                    : null,
                child: barber.profileImageUrl == null || barber.profileImageUrl!.isEmpty
                    ? const Icon(Icons.store, color: Color(0xFFD4AF37), size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barber.shopName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      barber.barberName,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFD4AF37), size: 14),
                        const SizedBox(width: 4),
                        Text(barber.rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on, color: Colors.grey, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            barber.address,
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () async {
                  await _firestoreService.removeFavoriteBarber(currentUserId!, barber.barberId);
                  _loadFavoriteBarbers();
                  _loadStats();
                  _showSnackBar('Favorilerden çıkarıldı');
                },
                icon: const Icon(Icons.favorite, color: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== KİŞİSEL BİLGİLER TAB ====================
  Widget _buildPersonalInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.phone,
            label: 'Telefon',
            value: _phone,
            isEditing: _isEditingPhone,
            controller: _phoneController,
            onEdit: _startEditPhone,
            onSave: _savePhone,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'Adres',
            value: _address,
            isEditing: _isEditingAddress,
            controller: _addressController,
            onEdit: _startEditAddress,
            onSave: _saveAddress,
          ),
          const SizedBox(height: 16),
          _buildDateRow(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hesap Bilgileri', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.email, color: Color(0xFFD4AF37)),
                  title: const Text('E-posta', style: TextStyle(color: Colors.grey)),
                  subtitle: Text(_email, style: const TextStyle(color: Colors.white)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFFD4AF37)),
                  title: const Text('Şifre', style: TextStyle(color: Colors.grey)),
                  subtitle: const Text('••••••••', style: TextStyle(color: Colors.white)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _changePassword,
                    icon: const Icon(Icons.lock_reset, color: Color(0xFFD4AF37)),
                    label: const Text('Şifre Değiştir', style: TextStyle(color: Color(0xFFD4AF37))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isEditing,
    required TextEditingController controller,
    required VoidCallback onEdit,
    required VoidCallback onSave,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                if (isEditing)
                  TextField(
                    controller: controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                    onSubmitted: (_) => onSave(),
                  )
                else
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          GestureDetector(
            onTap: isEditing ? onSave : onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(isEditing ? Icons.check : Icons.edit, color: const Color(0xFFD4AF37), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.cake, color: Color(0xFFD4AF37), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Doğum Tarihi', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                if (_isEditingBirthDate)
                  GestureDetector(
                    onTap: () async {
                      final newDate = await showDatePicker(
                        context: context,
                        initialDate: _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.dark(primary: Color(0xFFD4AF37)),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (newDate != null) {
                        await _saveBirthDate(newDate);
                      } else {
                        setState(() => _isEditingBirthDate = false);
                      }
                    },
                    child: Text(
                      _birthDate != null ? DateFormat('dd MMMM yyyy').format(_birthDate!) : 'Seçilmedi',
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
                    ),
                  )
                else
                  Text(
                    _birthDate != null ? DateFormat('dd MMMM yyyy').format(_birthDate!) : 'Belirtilmemiş',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _isEditingBirthDate ? () => setState(() => _isEditingBirthDate = false) : _startEditBirthDate,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(_isEditingBirthDate ? Icons.close : Icons.edit, color: const Color(0xFFD4AF37), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}