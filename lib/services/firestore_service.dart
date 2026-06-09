import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/all_models.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamBarbers() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'barber')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAppointmentsForCustomer(String customerId) {
    return _firestore
        .collection('appointments')
        .where('customerId', isEqualTo: customerId)
        .orderBy('dateTime', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAppointmentsForBarber(String barberId) {
    return _firestore
        .collection('appointments')
        .where('barberId', isEqualTo: barberId)
        .orderBy('dateTime', descending: false)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserById(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<void> createAppointment(Appointment appointment) {
    return _firestore.collection('appointments').doc(appointment.id).set(appointment.toMap());
  }

  Future<void> cancelAppointment(String appointmentId) {
    return _firestore.collection('appointments').doc(appointmentId).update({'status': 'canceled'});
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamServicesForBarber(String barberId) {
    return _firestore
        .collection('services')
        .where('barberId', isEqualTo: barberId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String chatId) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .orderBy('sentAt', descending: false)
        .snapshots();
  }

  Future<void> sendMessage(MessageModel message) {
    return _firestore.collection('messages').doc().set(message.toMap());
  }
}
