import 'package:cloud_firestore/cloud_firestore.dart';

class AddData {
  static Future<void> addService() async {
    await FirebaseFirestore.instance.collection('services').add({
      'name': 'Saç Kesimi',
      'description': 'Profesyonel saç kesim',
      'price': 400,
      'durationMinutes': 40,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> addCustomService({
    required String name,
    required String description,
    required int price,
    required int durationMinutes,
  }) async {
    await FirebaseFirestore.instance.collection('services').add({
      'name': name,
      'description': description,
      'price': price,
      'durationMinutes': durationMinutes,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}