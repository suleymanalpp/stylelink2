import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../customer_main_navigation.dart';
import '../business_main_navigation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storeNameController = TextEditingController();
  bool _isBarber = false;
  bool _isLoading = false;

  void _kayitOl() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await _authService.registerUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        nameSurname: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        isBarber: _isBarber,
        storeName: _isBarber ? _storeNameController.text.trim() : null,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => _isBarber ? const BusinessMainNavigation() : const CustomerMainNavigation()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: const Text('Hesap Oluştur', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Aramıza Katılın', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ad Soyad',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (value) => value!.isEmpty ? 'Lütfen adınızı ve soyadınızı girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (value) => value!.contains('@') ? null : 'Geçerli bir e-posta girin',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefon Numarası',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF1C1C1C),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (value) => value!.length < 10 ? 'Geçerli bir telefon numarası girin' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
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
                  validator: (value) => value!.length < 6 ? 'Şifre en az 6 karakter olmalıdır' : null,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Berber Olarak Kaydolmak İstiyorum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Salonunuzu yönetmek ve randevu almak için açın', style: TextStyle(color: Colors.grey)),
                  value: _isBarber,
                  activeColor: const Color(0xFFD4AF37),
                  onChanged: (value) => setState(() => _isBarber = value),
                ),
                if (_isBarber) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _storeNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Dükkan / Salon İsmi',
                      labelStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.storefront_outlined, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1C1C1C),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    validator: (value) {
                      if (_isBarber && (value == null || value.isEmpty)) {
                        return 'Lütfen dükkanınızın ismini girin';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _kayitOl,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text(_isBarber ? 'Berber Olarak Kaydol' : 'Müşteri Olarak Kaydol', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
