import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_appointment_screen.dart';
import 'customer_chat_screen.dart';
import 'customer_profile_screen.dart';

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

class _FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<DocumentSnapshot> getBarberProfile(String barberId) =>
      _db.collection('users').doc(barberId).get();

  Future<List<BarberService>> getBarberServices(String barberId) async {
    final snap = await _db
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .get();
    return snap.docs
        .map((d) => BarberService.fromMap(d.id, d.data()))
        .toList();
  }

  Future<Map<String, dynamic>?> getWorkingHours(String barberId) async {
    final q = await _db
        .collection('workingHours')
        .where('barberId', isEqualTo: barberId)
        .limit(1)
        .get();
    return q.docs.isNotEmpty ? q.docs.first.data() : null;
  }

  // Berberin rating ve reviewCount değerlerini güncelle
  Future<void> updateBarberRating(String barberId) async {
    // Berberin tüm yorumlarını al
    final reviewsSnapshot = await _db
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .get();
    
    final reviewCount = reviewsSnapshot.docs.length;
    
    double avgRating = 0;
    if (reviewCount > 0) {
      double totalRating = 0;
      for (var doc in reviewsSnapshot.docs) {
        totalRating += (doc.data()['rating'] ?? 0).toDouble();
      }
      avgRating = totalRating / reviewCount;
    }
    
    // Berberin users koleksiyonundaki belgesini güncelle
    await _db.collection('users').doc(barberId).update({
      'reviewCount': reviewCount,
      'avgRating': avgRating,
    });
  }

  // Yorum ekleme metodu - rating güncellemesi ile
  Future<void> addReview({
    required String barberId,
    required String customerId,
    required String customerName,
    String? customerProfileImageUrl,
    required double rating,
    required String comment,
  }) async {
    final ref = _db.collection('reviews').doc();
    await ref.set({
      'id': ref.id,
      'barberId': barberId,
      'customerId': customerId,
      'customerName': customerName,
      'customerProfileImageUrl': customerProfileImageUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Berberin rating ve reviewCount değerlerini güncelle
    await updateBarberRating(barberId);
    
    await _sendNotification(
      barberId: barberId,
      type: 'new_review',
      title: 'Yeni Yorum',
      body: '$customerName yorum bıraktı: "$comment"',
      relatedId: ref.id,
    );
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

  Future<void> toggleLike({
    required String barberId,
    required String imageUrl,
    required String currentUserId,
    required bool isLiked,
    required List<GalleryItem> currentGallery,
    required String? customerName,
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

    if (!isLiked && customerName != null) {
      await _sendNotification(
        barberId: barberId,
        type: 'gallery_like',
        title: 'Yeni Beğeni',
        body: '$customerName galerinizden bir fotoğrafı beğendi.',
        relatedId: imageUrl,
      );
    }
  }

  Future<void> _sendNotification({
    required String barberId,
    required String type,
    required String title,
    required String body,
    required String relatedId,
  }) async {
    await _db.collection('notifications').add({
      'userId': barberId,
      'type': type,
      'title': title,
      'body': body,
      'relatedId': relatedId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

// ==================== ANA EKRAN ====================

class BarberProfileViewScreen extends StatefulWidget {
  final String barberId;

  const BarberProfileViewScreen({super.key, required this.barberId});

  @override
  State<BarberProfileViewScreen> createState() =>
      _BarberProfileViewScreenState();
}

class _BarberProfileViewScreenState extends State<BarberProfileViewScreen>
    with SingleTickerProviderStateMixin {
  final _firebaseService = _FirebaseService();
  late TabController _tabController;

  String _shopName = '';
  String _barberName = '';
  String _address = '';
  String _about = '';
  String? _profileImageUrl;
  double _rating = 0.0;
  int _reviewCount = 0;

  Map<String, bool> _dayStatus = {};
  String _openTime = '09:00';
  String _closeTime = '20:00';

  List<BarberService> _services = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStaticData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStaticData() async {
    await Future.wait([
      _loadProfile(),
      _loadServices(),
      _loadWorkingHours(),
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
      // users koleksiyonundan avgRating ve reviewCount değerlerini al
      _rating = (data['avgRating'] ?? 0.0).toDouble();
      _reviewCount = data['reviewCount'] ?? 0;
    });
  }

  Future<void> _loadServices() async {
    final services = await _firebaseService.getBarberServices(widget.barberId);
    setState(() {
      _services = services;
    });
  }

  Future<void> _loadWorkingHours() async {
    final wh = await _firebaseService.getWorkingHours(widget.barberId);
    if (wh == null) return;
    setState(() {
      _dayStatus = Map<String, bool>.from(wh['dayStatus'] ?? {});
      _openTime = wh['openTime'] ?? '09:00';
      _closeTime = wh['closeTime'] ?? '20:00';
    });
  }

  void _navigateToAppointment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAppointmentScreen(
          barberId: widget.barberId,
          barberName: _shopName,
        ),
      ),
    );
  }

  void _navigateToChat() {
    final uid = _firebaseService.currentUserId;
    if (uid == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerChatScreen(
          customerId: uid,
          barberId: widget.barberId,
          barberName: _shopName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Berber Profili',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(child: _buildProfileHeader()),
                SliverToBoxAdapter(child: _buildActionButtons()),
                SliverToBoxAdapter(child: _buildAboutSection()),
                SliverToBoxAdapter(child: _buildServicesSection()),
                SliverToBoxAdapter(child: _buildWorkingHoursSection()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: const [
                        Tab(text: '🖼️ Galeri'),
                        Tab(text: '💬 Yorumlar'),
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
                    isOwner: false,
                  ),
                  _ReviewsTab(
                    barberId: widget.barberId,
                    firebaseService: _firebaseService,
                  ),
                ],
              ),
            ),
    );
  }

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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.2),
              shape: BoxShape.circle,
              image: _profileImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(_profileImageUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            child: _profileImageUrl == null
                ? const Icon(Icons.store,
                    size: 50, color: Color(0xFFD4AF37))
                : null,
          ),
          const SizedBox(height: 14),
          Text(_shopName,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(_barberName,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
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
                style:
                    const TextStyle(color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.location_on, color: Colors.grey, size: 14),
            const SizedBox(width: 6),
            Flexible(
                child: Text(_address,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center)),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToAppointment,
            icon: const Icon(Icons.calendar_month),
            label: const Text('Randevu Al'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _navigateToChat,
            icon: const Icon(Icons.chat),
            label: const Text('Mesaj At'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1C),
              foregroundColor: const Color(0xFFD4AF37),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline, color: Color(0xFFD4AF37), size: 20),
          SizedBox(width: 8),
          Text('Hakkımızda',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Text(_about.isEmpty ? 'Henüz açıklama eklenmemiş.' : _about,
            style: const TextStyle(
                color: Colors.grey, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  Widget _buildServicesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('✂️ Hizmetler ve Fiyatlar',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_services.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: Text('Henüz hizmet eklenmemiş.',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final s = _services[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.content_cut,
                        color: Color(0xFFD4AF37), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(s.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          if (s.description.isNotEmpty)
                            Text(s.description,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${s.price.toStringAsFixed(0)} ₺',
                          style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.bold)),
                      Text('${s.durationMinutes} dk',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildWorkingHoursSection() {
    final days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('⏰ Çalışma Saatleri',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.access_time,
              color: Color(0xFFD4AF37), size: 18),
          const SizedBox(width: 8),
          Text('$_openTime - $_closeTime',
              style:
                  const TextStyle(color: Colors.white, fontSize: 15)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            final dayKey = (i + 1).toString();
            final isOpen = _dayStatus[dayKey] ?? false;
            return Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
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
                      color: isOpen
                          ? const Color(0xFFD4AF37)
                          : Colors.red,
                      fontSize: 12)),
            );
          }),
        ),
      ]),
    );
  }
}

// ==================== GALERİ TAB ====================

class _GalleryTab extends StatelessWidget {
  final String barberId;
  final _FirebaseService firebaseService;
  final bool isOwner;

  const _GalleryTab({
    required this.barberId,
    required this.firebaseService,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid = firebaseService.currentUserId;
    return StreamBuilder<List<GalleryItem>>(
      stream: firebaseService.galleryStream(barberId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFD4AF37)));
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12)),
              child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Henüz galeri fotoğrafı yok.',
                        style: TextStyle(color: Colors.grey)),
                  ]),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isLiked =
                currentUid != null && item.likes.contains(currentUid);
            return _GalleryCard(
              item: item,
              isLiked: isLiked,
              currentUid: currentUid,
              isOwner: isOwner,
              onTap: () => _showFullScreen(context, items, index,
                  barberId, firebaseService, currentUid),
              onLike: currentUid == null
                  ? null
                  : () async {
                      await firebaseService.toggleLike(
                        barberId: barberId,
                        imageUrl: item.url,
                        currentUserId: currentUid,
                        isLiked: isLiked,
                        currentGallery: items,
                        customerName: null,
                      );
                    },
              onLikersView: () =>
                  _showLikers(context, item.likes),
            );
          },
        );
      },
    );
  }

  void _showFullScreen(BuildContext context, List<GalleryItem> items,
      int index, String barberId, _FirebaseService fs, String? uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GalleryFullScreen(
          items: items,
          initialIndex: index,
          barberId: barberId,
          firebaseService: fs,
          currentUid: uid,
          isOwner: isOwner,
        ),
      ),
    );
  }

  void _showLikers(BuildContext context, List<String> likerIds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _LikersSheet(likerIds: likerIds),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  final bool isLiked;
  final String? currentUid;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback onLikersView;

  const _GalleryCard({
    required this.item,
    required this.isLiked,
    required this.currentUid,
    required this.isOwner,
    required this.onTap,
    required this.onLike,
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
        child: Column(children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                item.url,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.grey, size: 40)),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFFD4AF37), strokeWidth: 2));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              if (item.caption.isNotEmpty)
                Text(item.caption,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Row(children: [
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
                  child: Text('${item.likes.length}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ==================== GALERİ FULLSCREEN ====================

class _GalleryFullScreen extends StatefulWidget {
  final List<GalleryItem> items;
  final int initialIndex;
  final String barberId;
  final _FirebaseService firebaseService;
  final String? currentUid;
  final bool isOwner;

  const _GalleryFullScreen({
    required this.items,
    required this.initialIndex,
    required this.barberId,
    required this.firebaseService,
    required this.currentUid,
    required this.isOwner,
  });

  @override
  State<_GalleryFullScreen> createState() => _GalleryFullScreenState();
}

class _GalleryFullScreenState extends State<_GalleryFullScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<GalleryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentIndex];
    final isLiked = widget.currentUid != null &&
        item.likes.contains(widget.currentUid);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('${_currentIndex + 1} / ${_items.length}',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _items.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => InteractiveViewer(
              child: Image.network(_items[i].url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.grey, size: 60))),
            ),
          ),
        ),
        Container(
          color: const Color(0xFF1C1C1C),
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            if (item.caption.isNotEmpty)
              Text(item.caption,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: widget.currentUid == null
                    ? null
                    : () async {
                        await widget.firebaseService.toggleLike(
                          barberId: widget.barberId,
                          imageUrl: item.url,
                          currentUserId: widget.currentUid!,
                          isLiked: isLiked,
                          currentGallery: _items,
                          customerName: null,
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
                onTap: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF1C1C1C),
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20))),
                  builder: (_) =>
                      _LikersSheet(likerIds: item.likes),
                ),
                child: Text('${item.likes.length} beğeni',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 14)),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ==================== YORUMLAR TAB ====================

class _ReviewsTab extends StatefulWidget {
  final String barberId;
  final _FirebaseService firebaseService;

  const _ReviewsTab(
      {required this.barberId, required this.firebaseService});

  @override
  State<_ReviewsTab> createState() => _ReviewsTabState();
}

class _ReviewsTabState extends State<_ReviewsTab> {
  double _newRating = 5.0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _showForm = false;
  
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('barberId', isEqualTo: widget.barberId)
          .get();
      
      _reviews = snapshot.docs
          .map((d) => Review.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('HATA: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitReview() async {
    final uid = widget.firebaseService.currentUserId;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Yorum yapabilmek için giriş yapın.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Lütfen bir yorum yazın.'),
            backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      final customerName = userData['nameSurname'] ?? userData['name'] ?? 'Misafir';
      final customerPhoto = userData['profileImageUrl'];

      // Yorum ekle (rating otomatik güncellenir)
      await widget.firebaseService.addReview(
        barberId: widget.barberId,
        customerId: uid,
        customerName: customerName,
        customerProfileImageUrl: customerPhoto,
        rating: _newRating,
        comment: _commentController.text.trim(),
      );
      
      _commentController.clear();
      setState(() {
        _showForm = false;
        _newRating = 5.0;
        _isSubmitting = false;
      });
      
      await _loadReviews();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Yorumunuz eklendi!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37))
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadReviews,
      color: const Color(0xFFD4AF37),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!_showForm)
            ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              icon: const Icon(Icons.rate_review),
              label: const Text('Yorum Yaz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            )
          else
            _buildReviewForm(),
          const SizedBox(height: 20),
          
          if (_reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(12)),
              child: const Center(
                  child: Text('Henüz yorum yapılmamış.',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            ..._reviews.map((r) => _ReviewCard(
                  review: r,
                  onTapCustomer: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerProfileScreen(
                            customerId: r.customerId),
                      ),
                    );
                  },
                )),
        ],
      ),
    );
  }

  Widget _buildReviewForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Yorum Yaz',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        const Text('Puanınız',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (i) {
            final star = i + 1;
            return GestureDetector(
              onTap: () => setState(() => _newRating = star.toDouble()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  _newRating >= star ? Icons.star : Icons.star_border,
                  color: const Color(0xFFD4AF37),
                  size: 32,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _commentController,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Deneyiminizi paylaşın...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF2A2A2A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton(
            onPressed: () => setState(() => _showForm = false),
            child: const Text('İptal',
                style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReview,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('Gönder'),
          ),
        ]),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback onTapCustomer;

  const _ReviewCard(
      {required this.review, required this.onTapCustomer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          GestureDetector(
            onTap: onTapCustomer,
            child: CircleAvatar(
              radius: 20,
              backgroundColor:
                  const Color(0xFFD4AF37).withOpacity(0.2),
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
                          fontWeight: FontWeight.bold))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                GestureDetector(
                  onTap: onTapCustomer,
                  child: Text(review.customerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
                Text(_formatDate(review.createdAt),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11)),
              ])),
          Row(children: [
            const Icon(Icons.star,
                color: Color(0xFFD4AF37), size: 14),
            const SizedBox(width: 3),
            Text(review.rating.toStringAsFixed(1),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
        const SizedBox(height: 10),
        Text(review.comment,
            style: const TextStyle(
                color: Colors.white70, fontSize: 13, height: 1.5)),
      ]),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ==================== BEĞENENLERİ GÖSTER ====================

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
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
        ),
        if (likerIds.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Henüz beğeni yok.',
                style: TextStyle(color: Colors.grey)),
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
                  child: Icon(Icons.person, color: Colors.grey)),
              title:
                  Text('...', style: TextStyle(color: Colors.white)));
        }
        final data = snap.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['nameSurname'] ?? data['name'] ?? 'Kullanıcı';
        final photo = data['profileImageUrl'];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                const Color(0xFFD4AF37).withOpacity(0.2),
            backgroundImage:
                photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(name,
              style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    CustomerProfileScreen(customerId: uid)),
          ),
        );
      },
    );
  }
}