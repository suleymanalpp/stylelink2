import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'barber_profile_view_screen.dart';


// ==================== MODELLER ====================

// BERBER MODELİ
class BarberModel {
  final String id;
  final String name;
  final String shopName;
  final String phone;
  final double rating;
  final int reviewCount;
  final String? profileImageUrl;
  final String address;

  BarberModel({
    required this.id,
    required this.name,
    required this.shopName,
    required this.phone,
    required this.rating,
    required this.reviewCount,
    this.profileImageUrl,
    required this.address,
  });

  factory BarberModel.fromMap(String id, Map<String, dynamic> map) {
    return BarberModel(
      id: id,
      name: map['nameSurname'] ?? 'Berber',
      shopName: map['shopName'] ?? 'Dükkan Adı Yok',
      phone: map['phone'] ?? '',
      rating: (map['avgRating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      profileImageUrl: map['profileImageUrl'],
      address: map['address'] ?? 'Adres belirtilmemiş',
    );
  }
}

// ==================== FIREBASE SERVİSLERİ ====================

class BarberSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Tüm berberleri getir
  Future<List<BarberModel>> getAllBarbers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'barber')
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return BarberModel.fromMap(doc.id, data);
    }).toList();
  }

  // Berber arama (isim veya dükkan adına göre)
  Future<List<BarberModel>> searchBarbers(String query) async {
    final allBarbers = await getAllBarbers();
    
    if (query.isEmpty) {
      return allBarbers;
    }
    
    return allBarbers.where((barber) {
      return barber.shopName.toLowerCase().contains(query.toLowerCase()) ||
             barber.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Puan ve yorum sayısına göre sırala
  List<BarberModel> sortByRating(List<BarberModel> barbers) {
    final sorted = List<BarberModel>.from(barbers);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  // Yorum sayısına göre sırala
  List<BarberModel> sortByReviewCount(List<BarberModel> barbers) {
    final sorted = List<BarberModel>.from(barbers);
    sorted.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
    return sorted;
  }

  // Popülerlik (randevu sayısı) - basit versiyon
  Future<List<BarberModel>> sortByPopularity(List<BarberModel> barbers) async {
    final appointmentCounts = <String, int>{};
    
    for (var barber in barbers) {
      final snapshot = await _firestore
          .collection('appointments')
          .where('barberId', isEqualTo: barber.id)
          .get();
      appointmentCounts[barber.id] = snapshot.docs.length;
    }
    
    final sorted = List<BarberModel>.from(barbers);
    sorted.sort((a, b) => (appointmentCounts[b.id] ?? 0).compareTo(appointmentCounts[a.id] ?? 0));
    return sorted;
  }
}

// ==================== ANA EKRAN ====================

class SearchBarberScreen extends StatefulWidget {
  const SearchBarberScreen({super.key});

  @override
  State<SearchBarberScreen> createState() => _SearchBarberScreenState();
}

class _SearchBarberScreenState extends State<SearchBarberScreen> {
  late BarberSearchService _searchService;
  List<BarberModel> _barbers = [];
  List<BarberModel> _filteredBarbers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'rating'; // rating, reviewCount, popularity
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchService = BarberSearchService();
    _loadBarbers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBarbers() async {
  setState(() => _isLoading = true);
  final barbers = await _searchService.getAllBarbers();
  setState(() {
    _barbers = barbers;
    // Başlangıçta avgRating'e göre sırala
    _filteredBarbers = _searchService.sortByRating(barbers);
    _isLoading = false;
  });
}

  void _searchBarbers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredBarbers = _barbers.where((barber) {
        return barber.shopName.toLowerCase().contains(query.toLowerCase()) ||
               barber.name.toLowerCase().contains(query.toLowerCase());
      }).toList();
      _applySorting();
    });
  }

  void _applySorting() {
    setState(() {
      if (_sortBy == 'rating') {
        _filteredBarbers = _searchService.sortByRating(_filteredBarbers);
      } else if (_sortBy == 'reviewCount') {
        _filteredBarbers = _searchService.sortByReviewCount(_filteredBarbers);
      } else if (_sortBy == 'popularity') {
        _searchService.sortByPopularity(_filteredBarbers).then((sorted) {
          if (mounted) {
            setState(() {
              _filteredBarbers = sorted;
            });
          }
        });
        return;
      }
    });
  }

  void _changeSortBy(String value) {
    setState(() {
      _sortBy = value;
      _applySorting();
    });
  }

  void _navigateToBarberProfile(String barberId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarberProfileViewScreen(barberId: barberId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Berber Ara', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _searchBarbers,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Berber veya dükkan adı ara...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Puana Göre', 'rating'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Yorum Sayısına Göre', 'reviewCount'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Popülerlik', 'popularity'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredBarbers.isEmpty
              ? const Center(
                  child: Text(
                    'Berber bulunamadı.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredBarbers.length,
                  itemBuilder: (context, index) {
                    final barber = _filteredBarbers[index];
                    return _buildBarberCard(barber);
                  },
                ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _sortBy == value,
      onSelected: (selected) {
        if (selected) {
          _changeSortBy(value);
        }
      },
      backgroundColor: const Color(0xFF1C1C1C),
      selectedColor: const Color(0xFFD4AF37),
      labelStyle: TextStyle(
        color: _sortBy == value ? Colors.black : Colors.white,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildBarberCard(BarberModel barber) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _navigateToBarberProfile(barber.id),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                  image: barber.profileImageUrl != null
                      ? DecorationImage(image: NetworkImage(barber.profileImageUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: barber.profileImageUrl == null
                    ? const Icon(Icons.store, color: Color(0xFFD4AF37), size: 30)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barber.shopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      barber.name,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFD4AF37), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          barber.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${barber.reviewCount} yorum)',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
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
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}