import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_chat_screen.dart';

class CustomerChatList extends StatelessWidget {
  const CustomerChatList({super.key});

  String get _customerId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // BUG TAKIP FONKSIYONU
  void _logBug(String type, String message, {dynamic data, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final bugIcon = type == 'ERROR' ? '❌' : type == 'WARNING' ? '⚠️' : type == 'SUCCESS' ? '✅' : '🔍';
    
    print('\n═══════════════════════════════════════════════════════════════');
    print('🐛 BUG TRACKER [$timestamp]');
    print('📌 TYPE: $type $bugIcon');
    print('📝 MESSAGE: $message');
    if (data != null) {
      print('📊 DATA: $data');
    }
    if (stackTrace != null) {
      print('📚 STACK TRACE: $stackTrace');
    }
    print('═══════════════════════════════════════════════════════════════\n');
  }

  Stream<QuerySnapshot> _chatStream() {
    _logBug('INFO', 'Chat Stream Oluşturuluyor', data: {
      'customerId': _customerId,
      'isLoggedIn': FirebaseAuth.instance.currentUser != null,
      'userId': FirebaseAuth.instance.currentUser?.uid
    });

    if (_customerId.isEmpty) {
      _logBug('ERROR', 'Customer ID BOŞ! Kullanıcı giriş yapmamış olabilir', data: {
        'currentUser': FirebaseAuth.instance.currentUser,
      });
    }

    return FirebaseFirestore.instance
        .collection('chats')
        .where('customerId', isEqualTo: _customerId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          _logBug('ERROR', 'Firestore Stream Hatası', data: {
            'error': error.toString(),
            'errorType': error.runtimeType.toString(),
            'customerId': _customerId,
          }, stackTrace: StackTrace.current);
          
          if (error.toString().contains('index') || error.toString().contains('requires an index')) {
            _logBug('ERROR', 'INDEX HATASI - Firebase Console\'da index oluşturulmalı', data: {
              'collection': 'chats',
              'field1': 'customerId (Ascending)',
              'field2': 'lastMessageTime (Descending)',
            });
            
            final RegExp urlRegex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
            final matches = urlRegex.allMatches(error.toString());
            
            if (matches.isNotEmpty) {
              _logBug('INFO', 'Index Oluşturma Linki', data: {'link': matches.first.group(0)});
            }
          }
        });
  }

  // Berber bilgilerini çek - fullName ve profileImageUrl kullanıyor
  Future<Map<String, Map<String, dynamic>>> _getMultipleBarberInfo(List<String> barberIds) async {
    _logBug('INFO', 'Berber Bilgileri Çekiliyor', data: {
      'barberCount': barberIds.length,
      'barberIds': barberIds,
    });
    
    if (barberIds.isEmpty) {
      _logBug('WARNING', 'Berber ID listesi boş, veri çekilemiyor');
      return {};
    }

    try {
      final uniqueIds = barberIds.toSet().toList();
      _logBug('INFO', 'Unique Berber ID\'leri', data: {
        'originalCount': barberIds.length,
        'uniqueCount': uniqueIds.length,
        'uniqueIds': uniqueIds
      });
      
      final Map<String, Map<String, dynamic>> result = {};

      for (int i = 0; i < uniqueIds.length; i += 10) {
        final end = (i + 10 < uniqueIds.length) ? i + 10 : uniqueIds.length;
        final batchIds = uniqueIds.sublist(i, end);

        _logBug('INFO', 'Batch ${i ~/ 10 + 1} çekiliyor', data: {
          'batchIds': batchIds,
          'batchSize': batchIds.length
        });

        // Önce barbers koleksiyonunda dene
        var barbersSnapshot = await FirebaseFirestore.instance
            .collection('barbers')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        
        _logBug('INFO', 'Barbers koleksiyonunda arama sonucu', data: {
          'foundCount': barbersSnapshot.docs.length,
          'collection': 'barbers'
        });
        
        // Eğer barbers'ta bulamazsa, users koleksiyonunda dene
        if (barbersSnapshot.docs.isEmpty) {
          _logBug('INFO', 'Barbers koleksiyonunda bulunamadı, users koleksiyonunda aranıyor...');
          barbersSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
          
          _logBug('INFO', 'Users koleksiyonunda arama sonucu', data: {
            'foundCount': barbersSnapshot.docs.length,
            'collection': 'users'
          });
        }

        for (var doc in barbersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          
          _logBug('SUCCESS', 'Berber dokümanı bulundu', data: {
            'barberId': doc.id,
            'availableFields': data.keys.toList(),
            'collection': doc.reference.parent.id
          });
          
          // fullName ve profileImageUrl kullanılıyor
          final name = data['fullName'] ??           // fullName dene
                       data['salonName'] ??          // salonName dene
                       data['name'] ??               // name dene
                       data['businessName'] ??       // businessName dene
                       'Berber';
          
          final photoUrl = data['profileImageUrl'] ??    // profileImageUrl dene
                           data['logoUrl'] ??            // logoUrl dene
                           data['photoUrl'] ??           // photoUrl dene
                           '';

          result[doc.id] = {
            'name': name,
            'photoUrl': photoUrl,
          };

          _logBug('SUCCESS', 'Berber önbelleğe alındı', data: {
            'barberId': doc.id,
            'name': name,
            'hasPhoto': photoUrl.isNotEmpty,
          });
        }

        // Bulunamayan berberler için
        for (var id in batchIds) {
          if (!result.containsKey(id)) {
            _logBug('WARNING', 'Berber bulunamadı', data: {
              'barberId': id,
              'triedCollections': ['barbers', 'users']
            });
            result[id] = {
              'name': 'Berber',
              'photoUrl': '',
            };
          }
        }
      }

      _logBug('SUCCESS', 'Berber bilgileri çekme tamamlandı', data: {
        'totalCached': result.length,
      });
      return result;
    } catch (e, stackTrace) {
      _logBug('ERROR', 'Berber bilgileri çekilirken hata', data: {
        'error': e.toString(),
      }, stackTrace: stackTrace);
      
      // Hata durumunda fallback değerler
      final fallback = <String, Map<String, dynamic>>{};
      for (var id in barberIds) {
        fallback[id] = {
          'name': 'Berber',
          'photoUrl': '',
        };
      }
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    _logBug('INFO', 'CustomerChatList ekranı açılıyor', data: {
      'customerId': _customerId,
      'isCustomerIdEmpty': _customerId.isEmpty,
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Mesajlar', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            _logBug('INFO', 'Geri butonuna tıklandı');
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatStream(),
        builder: (context, snapshot) {
          _logBug('INFO', 'StreamBuilder durumu', data: {
            'connectionState': snapshot.connectionState.toString(),
            'hasData': snapshot.hasData,
            'hasError': snapshot.hasError,
            'docsCount': snapshot.hasData ? snapshot.data!.docs.length : 0
          });
          
          if (snapshot.hasError) {
            _logBug('ERROR', 'StreamBuilder hatası', data: {
              'error': snapshot.error.toString(),
            });
            
            String errorMessage = 'Bir hata oluştu';
            bool isIndexError = snapshot.error.toString().contains('index');
            
            if (isIndexError) {
              errorMessage = 'Veritabanı index oluşturulması gerekiyor.';
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
                ],
              ),
            );
          }
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            _logBug('INFO', 'Veri bekleniyor - Loading ekranı');
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData) {
            _logBug('ERROR', 'snapshot.hasData false - Veri yok');
            return const Center(
              child: Text(
                'Veri alınamadı',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          
          if (snapshot.data!.docs.isEmpty) {
            _logBug('WARNING', 'Hiç chat dokümanı bulunamadı', data: {
              'customerId': _customerId,
            });
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'Henüz mesaj yok',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          
          final allDocs = snapshot.data!.docs;
          _logBug('SUCCESS', 'Chat dokümanları alındı', data: {
            'totalDocs': allDocs.length,
          });
          
          // Tüm dokümanları detaylı logla
          for (int i = 0; i < allDocs.length; i++) {
            final doc = allDocs[i];
            final data = doc.data() as Map<String, dynamic>;
            _logBug('INFO', 'Doküman $i detayı', data: {
              'docId': doc.id,
              'barberId': data['barberId'],
              'lastMessage': data['lastMessage'],
            });
          }
          
          // Unique chat'leri filtrele
          final Map<String, QueryDocumentSnapshot> uniqueChats = {};
          
          for (final doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final barberId = data['barberId']?.toString() ?? '';
            
            if (barberId.isEmpty) {
              _logBug('WARNING', 'Barber ID boş', data: {'docId': doc.id});
              continue;
            }
            
            if (!uniqueChats.containsKey(barberId)) {
              uniqueChats[barberId] = doc;
              _logBug('INFO', 'Unique chat eklendi', data: {'barberId': barberId});
            }
          }
          
          final chats = uniqueChats.values.toList();
          _logBug('SUCCESS', 'Unique chat filtreleme tamamlandı', data: {
            'originalCount': allDocs.length,
            'uniqueCount': chats.length,
          });
          
          if (chats.isEmpty) {
            _logBug('ERROR', 'Filtreleme sonrası hiç chat kalmadı');
            return const Center(
              child: Text(
                'Geçerli sohbet bulunamadı',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          
          // Berber ID'lerini topla
          final List<String> barberIds = [];
          for (var chat in chats) {
            final data = chat.data() as Map<String, dynamic>;
            final barberId = data['barberId']?.toString() ?? '';
            if (barberId.isNotEmpty && barberId != 'null') {
              barberIds.add(barberId);
            }
          }
          
          _logBug('INFO', 'Berber ID listesi', data: {
            'barberIds': barberIds,
          });
          
          if (barberIds.isEmpty) {
            _logBug('ERROR', 'Hiç geçerli barber ID bulunamadı');
            return const Center(
              child: Text(
                'Berber bilgisi bulunamadı',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          
          // FutureBuilder ile berber bilgilerini çek
          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _getMultipleBarberInfo(barberIds),
            builder: (context, barberInfoSnapshot) {
              if (barberInfoSnapshot.connectionState == ConnectionState.waiting) {
                _logBug('INFO', 'Berber bilgileri bekleniyor...');
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Berber bilgileri yükleniyor...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              
              if (barberInfoSnapshot.hasError) {
                _logBug('ERROR', 'Berber bilgileri çekme hatası', data: {
                  'error': barberInfoSnapshot.error.toString()
                });
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Berber bilgileri yüklenirken hata oluştu',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          (context as Element).reassemble();
                        },
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                );
              }
              
              final barberInfoMap = barberInfoSnapshot.data ?? {};
              _logBug('SUCCESS', 'Berber bilgileri alındı', data: {
                'mapSize': barberInfoMap.length,
              });
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final doc = chats[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final lastMessage = data['lastMessage'] ?? 'Mesaj yok';
                  final barberId = data['barberId']?.toString() ?? '';
                  final timestamp = data['lastMessageTime'] as Timestamp?;
                  final unreadCount = data['unreadCountCustomer'] ?? data['unreadCount'] ?? 0;
                  
                  final barberInfo = barberInfoMap[barberId];
                  final barberName = barberInfo?['name'] as String? ?? 'Berber';
                  final photoUrl = barberInfo?['photoUrl'] as String? ?? '';
                  
                  return GestureDetector(
                    onTap: () {
                      _logBug('INFO', 'Chat açılıyor', data: {
                        'barberId': barberId,
                        'barberName': barberName,
                      });
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerChatScreen(
                            barberId: barberId,
                            customerId: _customerId,
                            barberName: barberName,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildProfileAvatar(photoUrl, barberName, barberId),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  barberName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  lastMessage,
                                  style: TextStyle(
                                    color: unreadCount > 0 ? Colors.white : Colors.grey,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timestamp != null ? _formatTime(timestamp) : '',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE31C5F),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
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

  // 🎯 DÜZELTİLDİ - onBackgroundImageError hatası giderildi
  Widget _buildProfileAvatar(String photoUrl, String barberName, String barberId) {
    if (photoUrl.isNotEmpty) {
      _logBug('SUCCESS', 'NetworkImage kullanılıyor', data: {
        'barberName': barberName,
      });
      
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[800],
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (error, stackTrace) {
          // 🎯 SADECE HATA LOG'U - Widget döndürme yok
          _logBug('ERROR', 'NetworkImage hatası', data: {
            'error': error.toString(),
            'barberName': barberName,
            'barberId': barberId
          }, stackTrace: stackTrace);
        },
        child: null,
      );
    } else {
      _logBug('INFO', 'Photo URL yok - baş harfli avatar', data: {
        'barberName': barberName,
      });
      
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.blueGrey[800],
        child: Text(
          _getInitials(barberName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty || name == 'Berber') return 'B';
    
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
      return 'Dün';
    } else if (date.year == now.year) {
      return "${date.day}/${date.month}";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}