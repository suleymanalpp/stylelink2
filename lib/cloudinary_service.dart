import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'du6swar0j';
  static const String uploadPreset = 'ml_default';

  final ImagePicker _picker = ImagePicker();

  /// Galeriden veya kameradan resim seçer ve Cloudinary'e yükler
  Future<String?> pickAndUploadImage({required ImageSource source}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image == null) return null;

      return await uploadImage(image);
    } catch (e) {
      throw Exception("Resim seçme hatası: $e");
    }
  }

  /// Cloudinary'e direkt upload işlemi
  Future<String?> uploadImage(XFile imageFile) async {
    try {
      // 1. Byte'a çevir
      final Uint8List bytes = await imageFile.readAsBytes();

      // 2. API endpoint
      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      // 3. Request oluştur
      final request = http.MultipartRequest('POST', uri);

      // 4. Upload preset (UNSIGNED olmalı)
      request.fields['upload_preset'] = uploadPreset;

      // 5. File ekle
      final file = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(file);

      // 6. Gönder
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return data['secure_url']; // ✅ Cloudinary image URL
      } else {
        final error = data['error']['message'];
        throw Exception(error);
      }
    } catch (e) {
      throw Exception("Upload hatası: $e");
    }
  }
}