import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==================== MODELLER ====================

// MESAJ MODELİ
class BusinessChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  BusinessChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  factory BusinessChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return BusinessChatMessage(
      id: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: map['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }
}

// ==================== FIREBASE SERVİSLERİ ====================

class BusinessChatFirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Chat ID oluştur (iki kullanıcı arasında benzersiz)
  String getChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return ids.join('_');
  }

  // Mesajları dinle
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Mesaj gönder
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = BusinessChatMessage(
      id: messageId,
      senderId: senderId,
      receiverId: receiverId,
      content: content,
      timestamp: DateTime.now(),
      isRead: false,
    );
    
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set(message.toMap());
    
    // Son mesaj bilgilerini güncelle
    await _firestore.collection('chats').doc(chatId).set({
      'lastMessage': content,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'participants': [senderId, receiverId],
      'barberId': senderId,  // Berber gönderdiği için barberId = senderId
      'customerId': receiverId,
    }, SetOptions(merge: true));
  }

  // Okunmamış mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();
    
    for (var doc in unreadMessages.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  // Mevcut kullanıcı ID'sini getir
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }
}

// ==================== ANA EKRAN ====================

class BusinessChatScreen extends StatefulWidget {
  final String barberId;
  final String customerId;
  final String customerName;

  const BusinessChatScreen({
    super.key,
    required this.barberId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<BusinessChatScreen> createState() => _BusinessChatScreenState();
}

class _BusinessChatScreenState extends State<BusinessChatScreen> {
  late BusinessChatFirebaseService _chatService;
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  String _chatId = '';
  bool _isSending = false;
  String? _customerProfileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatService = BusinessChatFirebaseService();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _chatId = _chatService.getChatId(widget.barberId, widget.customerId);
    _loadCustomerInfo();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerInfo() async {
    setState(() => _isLoading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _customerProfileImageUrl = data['profileImageUrl'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Müşteri bilgisi yüklenirken hata: $e');
    }
  }

  void _markMessagesAsRead() {
    _chatService.markMessagesAsRead(_chatId, widget.barberId);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    setState(() => _isSending = true);
    _messageController.clear();
    
    await _chatService.sendMessage(
      chatId: _chatId,
      senderId: widget.barberId,
      receiverId: widget.customerId,
      content: content,
    );
    
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
              backgroundImage: _customerProfileImageUrl != null
                  ? NetworkImage(_customerProfileImageUrl!)
                  : null,
              child: _customerProfileImageUrl == null && !_isLoading
                  ? Text(
                      widget.customerName.isNotEmpty
                          ? widget.customerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Müşteri',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Hata: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  );
                }
                
                final messages = snapshot.data!.docs;
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Henüz mesaj yok.\nİlk mesajı siz gönderin!',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = BusinessChatMessage.fromMap(
                      messages[index].id,
                      messages[index].data() as Map<String, dynamic>,
                    );
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BusinessChatMessage message) {
    final isMe = message.senderId == widget.barberId;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFD4AF37) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.black : Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.black54 : Colors.grey,
                    fontSize: 10,
                  ),
                ),
                if (isMe && message.isRead) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all,
                    size: 12,
                    color: Colors.black54,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Mesajınızı yazın...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37),
            child: IconButton(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}