import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerUser({
    required String email,
    required String password,
    required String nameSurname,
    required String phone,
    required bool isBarber,
    String? storeName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': nameSurname,
          'email': email,
          'phone': phone,
          'role': isBarber ? 'barber' : 'customer',
          'shopName': isBarber ? (storeName ?? '') : '',
          'rating': 0.0,
          'reviewCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw 'Bu e-posta adresi zaten kullanımda. Lütfen başka bir e-posta deneyin.';
      } else if (e.code == 'weak-password') {
        throw 'Girdiğiniz şifre çok zayıf.';
      } else if (e.code == 'invalid-email') {
        throw 'Geçersiz bir e-posta adresi girdiniz.';
      }
      throw 'Kayıt esnasında bir hata oluştu: ${e.message}';
    } catch (e) {
      throw 'Beklenmedik bir hata oluştu.';
    }
  }

  Future<User?> signInUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        throw 'E-posta veya şifre yanlış.';
      }
      throw 'Giriş yapılamadı: ${e.message}';
    } catch (e) {
      throw 'Beklenmedik bir hata oluştu.';
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
