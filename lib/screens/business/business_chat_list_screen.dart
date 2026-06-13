import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'business_chat_screen.dart'; // 🔴 Bu import'u eklemeyi unutmayın

class BusinessChatListScreen extends StatelessWidget {
  final String barberId;

  const BusinessChatListScreen({
    super.key,
    required this.barberId,
  });

  Stream<QuerySnapshot> _chatStream() {
    debugPrint("📡 STREAM CREATED for barberId: $barberId");
    
    return FirebaseFirestore.instance
        .collection('chats')
        .where('barberId', isEqualTo: barberId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint("❌ FIRESTORE STREAM ERROR: $error");
          
          if (error.toString().contains('index') || error.toString().contains('requires an index')) {
            debugPrint("🔴 ========== INDEX ERROR DETECTED ==========");
            debugPrint("Bu hata için Firebase Console'da bir index oluşturmalısınız.");
            
            final RegExp urlRegex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
            final matches = urlRegex.allMatches(error.toString());
            
            if (matches.isNotEmpty) {
              debugPrint("🔗 INDEX OLUŞTURMA LİNKİ: ${matches.first.group(0)}");
              debugPrint("Bu linke tıklayarak otomatik index oluşturabilirsiniz.");
            } else {
              debugPrint("📝 MANUEL INDEX OLUŞTURMA:");
              debugPrint("   Collection: chats");
              debugPrint("   Alan 1: barberId (Ascending)");
              debugPrint("   Alan 2: lastMessageTime (Descending)");
            }
            
            debugPrint("🕐 Index oluşturulduktan sonra 2-5 dakika bekleyin.");
            debugPrint("===========================================");
          }
          
          debugPrintStack(stackTrace: StackTrace.current);
        });
  }

  // Toplu kullanıcı bilgilerini çeken metod
  Future<Map<String, Map<String, dynamic>>> _getMultipleCustomerInfo(List<String> customerIds) async {
    if (customerIds.isEmpty) return {};
    
    debugPrint("🔍 Batch fetching info for ${customerIds.length} customers");
    
    try {
      // Benzersiz ID'leri al
      final uniqueIds = customerIds.toSet().toList();
      
      // Firestore'da 'whereIn' sorgusu maximum 10 değer alabilir
      // Bu yüzden 10'ar 10'ar bölerek sorgu yapıyoruz
      final Map<String, Map<String, dynamic>> result = {};
      
      for (int i = 0; i < uniqueIds.length; i += 10) {
        final end = (i + 10 < uniqueIds.length) ? i + 10 : uniqueIds.length;
        final batchIds = uniqueIds.sublist(i, end);
        
        debugPrint("📦 Batch ${i ~/ 10 + 1}: fetching ${batchIds.length} users");
        
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        
        for (var doc in usersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['name'] ?? data['fullName'] ?? data['displayName'] ?? data['nameSurname'] ?? 'Müşteri';
          final photoUrl = data['profileImageUrl'] ?? '';
          
          result[doc.id] = {
            'name': name,
            'photoUrl': photoUrl,
          };
          
          debugPrint("✅ Cached user: ${doc.id} -> $name");
        }
        
        // Olmayan kullanıcılar için varsayılan değerler
        for (var id in batchIds) {
          if (!result.containsKey(id)) {
            debugPrint("⚠️ User not found: $id, using default values");
            result[id] = {
              'name': 'Müşteri',
              'photoUrl': '',
            };
          }
        }
      }
      
      debugPrint("✅ Batch fetch complete. Total users cached: ${result.length}");
      return result;
      
    } catch (e, stackTrace) {
      debugPrint("❌ ERROR in batch fetch: $e");
      debugPrint("Stack trace: $stackTrace");
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("🚀 SCREEN OPENED");
    debugPrint("BARBER ID: $barberId");

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text(
          'Mesajlarım',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatStream(),
        builder: (context, snapshot) {
          debugPrint("📊 STREAM STATE: ${snapshot.connectionState}");

          if (snapshot.hasError) {
            debugPrint("❌ WIDGET ERROR: ${snapshot.error}");
            
            String errorMessage = 'Bir hata oluştu';
            bool isIndexError = snapshot.error.toString().contains('index');
            
            if (isIndexError) {
              errorMessage = 'Veritabanı index oluşturulması gerekiyor.\nLütfen geliştiriciyle iletişime geçin.';
              debugPrint("🔴 Index hatası - Firebase Console'dan index oluşturun");
            }
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isIndexError ? Icons.build : Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  if (isIndexError) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hata kodu: MISSING_INDEX',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint("⏳ Loading chats...");
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            debugPrint("📭 No chats found for barberId: $barberId");
            return const Center(
              child: Text(
                'Henüz mesaj yok',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          debugPrint("📦 RAW DOCS COUNT: ${allDocs.length}");
          for (var doc in allDocs) {
            debugPrint("RAW DOC[${doc.id}]: ${doc.data()}");
          }

          // Aynı customerId'ye sahip chatlerden sadece en son mesajı olanı al
          final Map<String, QueryDocumentSnapshot> uniqueChats = {};

          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final customerId = data['customerId'] ?? '';

            if (!uniqueChats.containsKey(customerId)) {
              uniqueChats[customerId] = doc;
              debugPrint("➕ Added unique chat for customerId: $customerId (doc: ${doc.id})");
            } else {
              debugPrint("⏭️ Skipped duplicate customerId: $customerId (doc: ${doc.id})");
            }
          }

          final chats = uniqueChats.values.toList();

          debugPrint("💬 UNIQUE CHAT COUNT: ${chats.length}");

          // Tüm müşteri ID'lerini topla ve String tipine dönüştür
          final List<String> customerIds = chats.map((chat) {
            final data = chat.data() as Map<String, dynamic>;
            final id = data['customerId'] ?? '';
            return id.toString();
          }).where((id) => id.isNotEmpty).toList();

          debugPrint("👥 Customer IDs to fetch: $customerIds");

          // FutureBuilder ile toplu veri çekme
          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _getMultipleCustomerInfo(customerIds),
            builder: (context, userInfoSnapshot) {
              if (userInfoSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (userInfoSnapshot.hasError) {
                debugPrint("❌ Batch fetch error: ${userInfoSnapshot.error}");
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Kullanıcı bilgileri yüklenirken hata oluştu',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hata: ${userInfoSnapshot.error}',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final userInfoMap = userInfoSnapshot.data ?? {};
              debugPrint("✅ User info map size: ${userInfoMap.length}");

              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final data = chats[index].data() as Map<String, dynamic>;

                  final lastMessage = data['lastMessage'] ?? '';
                  final customerId = data['customerId'] ?? '';
                  final timestamp = data['lastMessageTime'] as Timestamp?;
                  final unreadCount = data['unreadCount'] ?? 0;

                  debugPrint("CHAT[$index] -> customerId: $customerId, lastMessage: $lastMessage, time: $timestamp");

                  // Cache'den kullanıcı bilgilerini al
                  final customerInfo = userInfoMap[customerId] ?? {
                    'name': 'Müşteri',
                    'photoUrl': '',
                  };
                  
                  final customerName = customerInfo['name'] as String;
                  final photoUrl = customerInfo['photoUrl'] as String;

                  debugPrint("🎨 Building UI for $customerName - PhotoUrl: ${photoUrl.isNotEmpty ? 'HAS PHOTO' : 'NO PHOTO'}");

                  return Card(
                    color: const Color(0xFF1A1A1A),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: _buildProfileAvatar(photoUrl, customerName, customerId),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              customerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        lastMessage,
                        style: TextStyle(
                          color: unreadCount > 0 ? Colors.white : Colors.grey,
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: timestamp != null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTime(timestamp),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                if (unreadCount > 0) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            )
                          : null,
                      // 🔴 TIKLAMA İŞLEVİ EKLENDİ
                      onTap: () {
                        debugPrint("📱 CHAT OPENED for customerId: $customerId");
                        debugPrint("   Customer Name: $customerName");
                        
                        // BusinessChatScreen'e yönlendir
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusinessChatScreen(
                              barberId: barberId,
                              customerId: customerId,
                              customerName: customerName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // Profil fotoğrafı veya baş harfli avatar gösteren metod
  Widget _buildProfileAvatar(String photoUrl, String customerName, String customerId) {
    debugPrint("🖼️ Building avatar for: $customerName (ID: $customerId)");
    if (photoUrl.isNotEmpty) {
      debugPrint("   ✅ profileImageUrl var, uzunluk: ${photoUrl.length}");
      debugPrint("   📸 URL: ${photoUrl.substring(0, photoUrl.length > 80 ? 80 : photoUrl.length)}...");
      
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[800],
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (error, stackTrace) {
          debugPrint("❌❌❌ NETWORK IMAGE ERROR ❌❌❌");
          debugPrint("   Hata: $error");
          debugPrint("   Fotoğraf URL: $photoUrl");
          debugPrint("   Müşteri: $customerName (ID: $customerId)");
        },
        child: null,
      );
    } else {
      debugPrint("   ❌ profileImageUrl BOŞ, baş harfli avatar kullanılıyor");
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.blueGrey[800],
        child: Text(
          _getInitials(customerName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  // İsimden baş harfleri al
  String _getInitials(String name) {
    if (name.isEmpty) return 'M';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // Zaman formatı
  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    // Bugün ise sadece saat göster
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    // Dün ise "Dün" yaz
    else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'Dün';
    }
    // Bu yıl içinde ise gün/ay göster
    else if (date.year == now.year) {
      return "${date.day}/${date.month}";
    }
    // Eski tarihler için yıl göster
    else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}