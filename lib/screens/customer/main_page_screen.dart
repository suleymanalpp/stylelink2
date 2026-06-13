import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/all_widgets.dart';
import '../customer/barber_profile_view_screen.dart';
import '../customer/search_barber_screen.dart';


class MainPageScreen extends StatefulWidget {
  const MainPageScreen({super.key});

  @override
  State<MainPageScreen> createState() => _MainPageScreenState();
}

class _MainPageScreenState extends State<MainPageScreen> {
  final BarberSearchService _searchService = BarberSearchService();
  List<BarberModel> _topBarbers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopBarbers();
  }

  Future<void> _loadTopBarbers() async {
    setState(() => _isLoading = true);
    final barbers = await _searchService.getAllBarbers();
    final sorted = _searchService.sortByRating(barbers);
    setState(() {
      _topBarbers = sorted;
      _isLoading = false;
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
        title: const Text('Hoşgeldiniz', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Öne Çıkan Berberler'),
            const SizedBox(height: 12),
            const Text(
              'Favori berberinizi seçin ve randevunuzu hemen oluşturun.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _topBarbers.isEmpty
                      ? const Center(
                          child: Text(
                            'Berber bulunamadı.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _topBarbers.length,
                          itemBuilder: (context, index) {
                            final barber = _topBarbers[index];
                            return _buildBarberCard(barber);
                          },
                        ),
            ),
          ],
        ),
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