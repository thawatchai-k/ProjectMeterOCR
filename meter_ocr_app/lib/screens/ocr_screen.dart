import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import 'history_screen.dart';
import 'add_meter_screen.dart';
import 'verify_screen.dart';
import 'meter_list_screen.dart';
import 'admin_user_screen.dart';
import 'login_screen.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  XFile? _image;
  String _ocrText = "";
  String _serial = "";
  String _reading = "";
  bool _loading = false;
  bool _saving = false;
  String _role = "";

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString("role") ?? "";
    });
  }

  // 📸 ถ่ายรูปจากกล้อง
  Future<void> pickFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _ocrText = "";
        _serial = "";
        _reading = "";
      });
    }
  }

  // 🖼️ เลือกรูปจากอัลบัม
  Future<void> pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile;
        _ocrText = "";
        _serial = "";
        _reading = "";
      });
    }
  }

  // 💾 บันทึกรูปลงอัลบัม
  Future<void> saveToGallery() async {
    if (_image == null) return;

    setState(() => _saving = true);

    try {
      // สำหรับ Web ไม่สามารถบันทึกลง gallery ได้โดยตรง
      if (kIsWeb) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Web ไม่รองรับการบันทึกลง gallery")),
        );
      } else {
        // สำหรับ mobile ต้องติดตั้ง image_gallery_saver package
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("รูปถูกบันทึกแล้ว")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("บันทึกล้มเหลว: $e")),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  // 🔐 ดึง JWT token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("token");
  }

  // 🧠 ส่งรูปไป OCR
  Future<void> doOcr() async {
    print("🟢 DEBUG: doOcr called!");
    print("🟢 DEBUG: _image = $_image");
    
    if (_image == null) {
      print("🟢 DEBUG: _image is null, returning...");
      return;
    }

    setState(() => _loading = true);
    print("🟢 DEBUG: _loading set to true");

    final token = await _getToken();
    if (token == null) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณา Login ใหม่")),
      );
      return;
    }

    try {
      final response = await ApiService.uploadImage(_image!, token);

      final data = jsonDecode(response);

      setState(() {
        _ocrText = data["text"] ?? "";
        _serial = data["serial"] ?? "";
        _reading = data["reading"] ?? "";
        
        if (_reading.isEmpty && _serial.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("อ่านค่าไม่สำเร็จ (ไม่พบตัวเลข)")),
          );
        } else {
             // ไปหน้า Verify ทันทีเมื่อได้ผลลัพธ์
             if (!mounted) return;
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (context) => VerifyScreen(
                   image: _image,
                   initialSerial: _serial,
                   initialReading: _reading,
                 ),
               ),
             );
        }
        
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("OCR ล้มเหลว: $e")),
      );
    }
  }

  // 🖥️ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OCR มิเตอร์ไฟฟ้า"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // ลบข้อมูลทั้งหมด (token, role)
              
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // แสดงรูปที่เลือก
            if (_image != null)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(_image!.path, height: 250, fit: BoxFit.contain)
                      : Image.file(File(_image!.path), height: 250, fit: BoxFit.contain),
                ),
              )
            else
              Container(
                height: 250,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image, size: 64, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("ยังไม่มีรูปภาพ", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // ปุ่มเลือกรูป (เฉพาะเจ้าหน้าที่กายภาพ)
            if (_role == 'physical_officer' || _role == 'admin')
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text("เพิ่มรูปถ่าย"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: pickFromCamera,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("ถ่ายรูปมิเตอร์"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),

            if (_role == 'physical_officer' || _role == 'admin')
              const SizedBox(height: 12),
            
            // ปุ่มเพิ่มมิเตอร์ (Admin และ Physical Officer)
            if (_role == 'admin' || _role == 'physical_officer')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddMeterScreen()),
                    );
                  },
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text("ลงทะเบียนมิเตอร์ใหม่"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

            if (_role == 'admin' || _role == 'physical_officer')
              const SizedBox(height: 12),

            // ปุ่มดูรายชื่อมิเตอร์ (ใหม่)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MeterListScreen()),
                  );
                },
                icon: const Icon(Icons.list_alt),
                label: const Text("ดูรายชื่อมิเตอร์ทั้งหมด"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ปุ่มจัดการผู้ใช้ (เฉพาะ Admin)
            if (_role == 'admin')
              SizedBox(
                width: double.infinity,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AdminUserScreen()),
                      );
                    },
                    icon: const Icon(Icons.admin_panel_settings),
                    label: const Text("จัดการผู้ใช้ในระบบ"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            
            if (_role == 'admin')
              const SizedBox(height: 12),
            
            const SizedBox(height: 16),

            // ปุ่มบันทึกและส่ง OCR (แสดงเมื่อมีรูป)
            if (_image != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : saveToGallery,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt),
                      label: const Text("บันทึกลงอัลบัม"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : doOcr,
                      icon: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text("ส่งไป OCR"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // แสดงผล OCR (Raw Text) - ซ่อนตามที่ user ขอ (ให้ดูที่ Backend Log แทน)
            /*
            if (_ocrText.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                "ผลลัพธ์ OCR (Raw Text):",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                padding: const EdgeInsets.all(8),
                color: Colors.grey[100],
                child: SelectableText(_ocrText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
            */

            // แสดงผลที่แยกออกมา (Reading & Serial)
            if (_reading.isNotEmpty || _serial.isNotEmpty) ...[
              const Divider(thickness: 2),
              const Center(child: Text("✅ ข้อมูลที่อ่านได้", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green))),
              const SizedBox(height: 12),
              
              if (_reading.isNotEmpty) 
                Card(
                  color: Colors.green[50],
                  child: ListTile(
                    leading: const Icon(Icons.flash_on, color: Colors.green, size: 32),
                    title: const Text("ค่าไฟ (Reading)", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_reading, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
                
               if (_serial.isNotEmpty)
                Card(
                  color: Colors.blue[50],
                  child: ListTile(
                    leading: const Icon(Icons.confirmation_number, color: Colors.blue, size: 32),
                    title: const Text("หมายเลขมิเตอร์ (S/N)", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(_serial, style: const TextStyle(fontSize: 18, color: Colors.black87)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
