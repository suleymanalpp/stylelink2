import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';
import '../customer_main_navigation.dart';
import '../business_main_navigation.dart';
import '../services/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool isLoading = false;

  void login() async {
    if (emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final user = await _authService.signInUser(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (user == null) {
        throw 'Oturum açılamadı';
      }

      final userDoc = await _firestoreService.getUserById(user.uid);
      if (!mounted) return;
      setState(() => isLoading = false);

      if (userDoc.exists) {
        final role = userDoc.data()?['role'] ?? 'customer';
        if (role == 'barber') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const BusinessMainNavigation()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CustomerMainNavigation()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı bilgisi bulunamadı'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.content_cut, size: 70, color: Colors.white),
                const SizedBox(height: 20),
                const Text('StyleLink', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Berber Randevu Uygulaması', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Şifre',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : login,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('Giriş Yap', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                  child: const Text('Hesabın yok mu? Kayıt ol', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
