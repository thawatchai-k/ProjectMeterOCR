import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../config/api.dart';
import '../models/meter_model.dart';

class ApiService {
  static Future<String> uploadImage(
      XFile image, String token) async {

    print("🔴 DEBUG: Starting OCR upload...");
    print("🔴 DEBUG: URL = ${ApiConfig.ocr}");
    print("🔴 DEBUG: Token = $token");

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.ocr),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Read bytes for Web compatibility
    final bytes = await image.readAsBytes();
    print("🔴 DEBUG: Image bytes = ${bytes.length}");
    
    request.files.add(
      http.MultipartFile.fromBytes(
        'image', 
        bytes,
        filename: image.name
      ),
    );

    print("🔴 DEBUG: Sending request...");
    final response = await request.send();
    print("🔴 DEBUG: Response status = ${response.statusCode}");
    
    final body = await response.stream.bytesToString();
    print("🔴 DEBUG: Response body = $body");

    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception('OCR failed: $body');
    }
  }


  static Future<String> getHistory(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.history),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load history');
    }
  }


  static Future<bool> addMeter(MeterModel meter, String token) async {
    final response = await http.post(
      Uri.parse(ApiConfig.meters),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(meter.toJson()),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to add meter: ${response.body}');
    }
  }

  static Future<String> getMeters(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.meters),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception('Failed to load meters');
    }
  }

  static Future<bool> deleteMeter(int id, String token) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.meters}/$id'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to delete meter');
    }
  }

  static Future<bool> saveReading(String serial, String reading, String? imagePath, String token) async {
    final response = await http.post(
      Uri.parse(ApiConfig.readings),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "serial_number": serial,
        "reading": reading,
        "image_path": imagePath,
      }),
    );

    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to save reading: ${response.body}');
    }
  }
}
