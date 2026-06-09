import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseTestService {
  // Test verisini gönderecek fonksiyon
  static Future<void> gonderTestVerisi() async {
    try {
      await FirebaseFirestore.instance.collection('test_baglantisi').add({
        'durum': 'Ayrı dosyadan gönderim başarılı!',
        'tarih': DateTime.now().toString(),
        'mesaj': 'Berber uygulaması backend köprüsü kuruldu.',
      });
      print("🚀 [TEST] Veri başka bir dosyadan Firebase'e başarıyla uçtu!");
    } catch (e) {
      print("❌ [TEST HATASI] Ayrı dosyadan gönderim başarısız: $e");
    }
  }
}