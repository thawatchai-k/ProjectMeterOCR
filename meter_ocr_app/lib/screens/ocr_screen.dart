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
      final response = await ApiService.uploadImage(
        _image!, 
        token,
      );

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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("METER OCR PRO"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withBlue(40),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // 📸 Image Preview with Glow Effect
              Stack(
                children: [
                  // Preview Image
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 280,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: theme.primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: _image != null
                            ? (kIsWeb
                                ? Image.network(_image!.path, fit: BoxFit.contain)
                                : Image.file(File(_image!.path), fit: BoxFit.contain))
                            : Container(
                                color: theme.cardColor,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_enhance_rounded,
                                        size: 64, color: theme.primaryColor.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    Text(
                                      "พร้อมสำหรับการสแกน",
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                  
                  // Scanner Overlay (Guide only, no ROIs)
                  if (_image == null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: ScannerOverlayPainter(
                            borderColor: theme.primaryColor,
                            overlayColor: Colors.black.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

              // 🛠️ Action Buttons
              if (_role == 'physical_officer' || _role == 'admin') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text("คลังภาพ"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white10,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickFromCamera,
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: const Text("ถ่ายรูป"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 🧠 OCR Action Button
              if (_image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : doOcr,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: Text(_loading ? "กำลังประมวลผล..." : "เริ่มอ่านค่า OCR"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

              const Divider(height: 48, color: Colors.white10),

              // 📊 Features Grid/List
              if (_role == 'admin' || _role == 'physical_officer')
                _buildModernActionTile(
                  context,
                  icon: Icons.add_location_alt_rounded,
                  title: "ลงทะเบียนมิเตอร์ใหม่",
                  color: Colors.orangeAccent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddMeterScreen()),
                  ),
                ),

              const SizedBox(height: 12),

              _buildModernActionTile(
                context,
                icon: Icons.list_alt_rounded,
                title: "ดูรายชื่อมิเตอร์ทั้งหมด",
                color: Colors.tealAccent,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MeterListScreen()),
                ),
              ),

              const SizedBox(height: 32),

              // 📊 Result Panel (If available)
              if (_reading.isNotEmpty || _serial.isNotEmpty) ...[
                 Text(
                  "ผลตรวจสอบเบื้องต้น",
                  style: theme.textTheme.headlineMedium?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 16),
                _buildResultCard(
                  title: "ค่าไฟ (Reading)",
                  value: _reading,
                  icon: Icons.flash_on_rounded,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _buildResultCard(
                  title: "หมายเลขมิเตอร์ (S/N)",
                  value: _serial,
                  icon: Icons.qr_code_rounded,
                  color: theme.primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: _role == 'admin'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminUserScreen()),
              ),
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text("จัดการผู้ใช้"),
              backgroundColor: theme.primaryColor,
            )
          : null,
    );
  }

  Widget _buildModernActionTile(BuildContext context,
      {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 🎨 Painter สำหรับสร้างกรอบนำสายตา (Scanner Overlay)
class ScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final Color overlayColor;

  ScannerOverlayPainter({
    required this.borderColor,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    
    // พิกัดกรอบเป้าหมาย (กลางจอ - เพื่อความสวยงามนำสายตาเท่านั้น)
    final double boxWidth = size.width * 0.8;
    final double boxHeight = 120;
    final Rect targetRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: boxWidth,
      height: boxHeight,
    );

    // 1. วาดพื้นหลังกึ่งโปร่งใส (เจาะรูตรงกลาง)
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    
    canvas.drawPath(backgroundPath, paint);

    // 2. วาดเส้นขอบเรืองแสง
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(12)),
      borderPaint,
    );

    // 3. วาดเส้นนำสายตาที่มุม
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    double len = 20;
    // Top-Left
    canvas.drawLine(targetRect.topLeft, targetRect.topLeft + Offset(len, 0), cornerPaint);
    canvas.drawLine(targetRect.topLeft, targetRect.topLeft + Offset(0, len), cornerPaint);
    // Top-Right
    canvas.drawLine(targetRect.topRight, targetRect.topRight + Offset(-len, 0), cornerPaint);
    canvas.drawLine(targetRect.topRight, targetRect.topRight + Offset(0, len), cornerPaint);
    // Bottom-Left
    canvas.drawLine(targetRect.bottomLeft, targetRect.bottomLeft + Offset(len, 0), cornerPaint);
    canvas.drawLine(targetRect.bottomLeft, targetRect.bottomLeft + Offset(0, -len), cornerPaint);
    // Bottom-Right
    canvas.drawLine(targetRect.bottomRight, targetRect.bottomRight + Offset(-len, 0), cornerPaint);
    canvas.drawLine(targetRect.bottomRight, targetRect.bottomRight + Offset(0, -len), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
