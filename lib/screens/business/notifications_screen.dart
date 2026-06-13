import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODEL ====================

class AppNotification {
  final String id;
  final String userId;
  final String type; // 'new_appointment' | 'new_review' | 'gallery_like'
  final String title;
  final String body;
  final String relatedId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      userId: map['userId'] ?? '',
      type: map['type'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      relatedId: map['relatedId'] ?? '',
      isRead: map['isRead'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

// ==================== SERVİS ====================

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<AppNotification>> notificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AppNotification.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }
}

// ==================== EKRAN ====================

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final String? _currentUserId =
      FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: _buildAppBar(context, []),
        body: const Center(
            child: Text('Oturum açık değil.',
                style: TextStyle(color: Colors.grey))),
      );
    }

    return StreamBuilder<List<AppNotification>>(
      stream: _service.notificationsStream(_currentUserId!),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount =
            notifications.where((n) => !n.isRead).length;

        return Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          appBar: _buildAppBar(context, notifications),
          body: Builder(builder: (context) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFD4AF37)));
            }

            if (notifications.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () => _handleTap(context, n),
                  onDismiss: () =>
                      _service.deleteNotification(n.id),
                );
              },
            );
          }),
          // Okunmamış rozeti
          floatingActionButton: unreadCount > 0
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _service.markAllAsRead(_currentUserId!),
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.done_all),
                  label: Text('Tümünü Okundu İşaretle ($unreadCount)'),
                )
              : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, List<AppNotification> notifications) {
    final unread =
        notifications.where((n) => !n.isRead).length;
    return AppBar(
      title: Row(children: [
        const Text('Bildirimler',
            style: TextStyle(color: Colors.white)),
        if (unread > 0) ...[
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$unread',
                style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
      backgroundColor: const Color(0xFF0F0F0F),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (notifications.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF1C1C1C),
            onSelected: (value) {
              if (value == 'mark_all') {
                _service.markAllAsRead(_currentUserId!);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'mark_all',
                child: Row(children: [
                  Icon(Icons.done_all,
                      color: Color(0xFFD4AF37), size: 18),
                  SizedBox(width: 10),
                  Text('Tümünü Okundu İşaretle',
                      style: TextStyle(color: Colors.white)),
                ]),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
                width: 2),
          ),
          child: const Icon(Icons.notifications_none,
              size: 40, color: Color(0xFFD4AF37)),
        ),
        const SizedBox(height: 20),
        const Text('Yeni bildirim yok.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        const Text(
            'Randevu, yorum veya beğeni\ngeldiğinde burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ]),
    );
  }

  void _handleTap(BuildContext context, AppNotification n) {
    // Okundu işaretle
    if (!n.isRead) {
      _service.markAsRead(n.id);
    }

    // İlgili sayfaya yönlendir
    switch (n.type) {
      case 'new_appointment':
        // Randevular sayfasına git
        // Navigator.push(context, MaterialPageRoute(builder: (_) =>
        //     AppointmentsScreen()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Randevular sayfasına yönlendiriliyorsunuz...'),
            backgroundColor: Color(0xFF1C1C1C)));
        break;
      case 'new_review':
        // Profil ekranındaki yorumlar sekmesine git
        // Navigator.push(context, MaterialPageRoute(builder: (_) =>
        //     ProfileScreen()));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Yorumlar sayfasına yönlendiriliyorsunuz...'),
            backgroundColor: Color(0xFF1C1C1C)));
        break;
      case 'gallery_like':
        // Profil ekranındaki galeri sekmesine git
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Galeri sayfasına yönlendiriliyorsunuz...'),
            backgroundColor: Color(0xFF1C1C1C)));
        break;
    }
  }
}

// ==================== BİLDİRİM KARTI ====================

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.8),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 5),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.isRead
                ? const Color(0xFF1C1C1C)
                : const Color(0xFF242410),
            borderRadius: BorderRadius.circular(12),
            border: notification.isRead
                ? null
                : Border.all(
                    color:
                        const Color(0xFFD4AF37).withOpacity(0.35),
                    width: 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // İkon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconBg(notification.type),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData(notification.type),
                  color: _iconColor(notification.type), size: 22),
            ),
            const SizedBox(width: 14),
            // İçerik
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Row(children: [
                Expanded(
                  child: Text(notification.title,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold)),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(notification.body,
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text(_formatTime(notification.createdAt),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 11)),
            ])),
          ]),
        ),
      ),
    );
  }

  IconData _iconData(String type) {
    switch (type) {
      case 'new_appointment':
        return Icons.calendar_today;
      case 'new_review':
        return Icons.star;
      case 'gallery_like':
        return Icons.favorite;
      default:
        return Icons.notifications;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'new_appointment':
        return const Color(0xFFD4AF37);
      case 'new_review':
        return const Color(0xFFD4AF37);
      case 'gallery_like':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'new_appointment':
        return const Color(0xFFD4AF37).withOpacity(0.15);
      case 'new_review':
        return const Color(0xFFD4AF37).withOpacity(0.15);
      case 'gallery_like':
        return Colors.red.withOpacity(0.15);
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dt.day}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

// ==================== BİLDİRİM ROZET WIDGET'I ====================
// Ana navigation bar'da kullanmak için:
//
// StreamBuilder<QuerySnapshot>(
//   stream: FirebaseFirestore.instance
//       .collection('notifications')
//       .where('userId', isEqualTo: currentUserId)
//       .where('isRead', isEqualTo: false)
//       .snapshots(),
//   builder: (context, snapshot) {
//     final count = snapshot.data?.docs.length ?? 0;
//     return Badge(
//       isLabelVisible: count > 0,
//       label: Text('$count'),
//       child: Icon(Icons.notifications),
//     );
//   },
// )