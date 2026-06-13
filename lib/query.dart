import 'package:cloud_firestore/cloud_firestore.dart';

class QueryService {
  static Future<void> runQuery() async {
    try {
      final query = FirebaseFirestore.instance
          .collection('users')
          .where('age', isGreaterThan: 18)
          .orderBy('age');

      final snapshot = await query.get();

      print("===== QUERY RESULT =====");

      for (var doc in snapshot.docs) {
        print('Doc ID: ${doc.id}');
        print(doc.data());
      }

      print("===== END =====");
    } catch (e) {
      print("QUERY ERROR: $e");
    }
  }
}