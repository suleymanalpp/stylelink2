import 'package:cloud_firestore/cloud_firestore.dart';

enum UserType { customer, barber }
enum AppointmentStatus { pending, approved, canceled }

class CustomerModel {
  final String uid;
  final String name;
  final String email;
  final String phone;

  CustomerModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory CustomerModel.fromMap(String uid, Map<String, dynamic> map) {
    return CustomerModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'customer',
    };
  }
}

class BarberModel {
  final String uid;
  final String name;
  final String shopName;
  final String email;
  final String phone;
  final double rating;
  final int reviewCount;

  BarberModel({
    required this.uid,
    required this.name,
    required this.shopName,
    required this.email,
    required this.phone,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  factory BarberModel.fromMap(String uid, Map<String, dynamic> map) {
    return BarberModel(
      uid: uid,
      name: map['name'] ?? '',
      shopName: map['shopName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'shopName': shopName,
      'email': email,
      'phone': phone,
      'role': 'barber',
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}

class Appointment {
  final String id;
  final String barberId;
  final String customerId;
  final String serviceId;
  final String serviceName;
  final double price;
  final DateTime dateTime;
  final String status;

  Appointment({
    required this.id,
    required this.barberId,
    required this.customerId,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.dateTime,
    this.status = 'pending',
  });

  factory Appointment.fromMap(String id, Map<String, dynamic> map) {
    final dateField = map['dateTime'];
    DateTime parsedDate;
    if (dateField is Timestamp) {
      parsedDate = dateField.toDate();
    } else if (dateField is String) {
      parsedDate = DateTime.tryParse(dateField) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }
    return Appointment(
      id: id,
      barberId: map['barberId'] ?? '',
      customerId: map['customerId'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      dateTime: parsedDate,
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barberId': barberId,
      'customerId': customerId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'price': price,
      'dateTime': Timestamp.fromDate(dateTime),
      'status': status,
    };
  }
}

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

class MessageModel {
  final String chatId;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime sentAt;

  MessageModel({
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.sentAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final timestamp = map['sentAt'];
    return MessageModel(
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      sentAt: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }
}
