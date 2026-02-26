import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api.dart';
import 'ocr_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      setState(() => loading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];

        // 🔐 บันทึก JWT token และ Role
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", token);
        await prefs.setString("role", data['user']['role']);

        // 👉 ไปหน้า OCR
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OcrScreen()),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด (${response.statusCode})')),
        );
      }
    } catch (e) {
      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withBlue(60),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🚀 Logo / Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.primaryColor.withOpacity(0.2), width: 2),
                    ),
                    child: Icon(
                      Icons.electric_meter_rounded,
                      size: 80,
                      color: theme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "METER OCR PRO",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "เข้าสู่ระบบเพื่อเริ่มใช้งาน",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 48),

                  // 📝 Input Fields
                  _buildStyledTextField(
                    controller: usernameController,
                    label: "ชื่อผู้ใช้",
                    icon: Icons.person_outline_rounded,
                    theme: theme,
                  ),
                  const SizedBox(height: 20),
                  _buildStyledTextField(
                    controller: passwordController,
                    label: "รหัสผ่าน",
                    icon: Icons.lock_outline_rounded,
                    theme: theme,
                    isPassword: true,
                  ),
                  const SizedBox(height: 40),

                  // 🔘 Login Button
                  loading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: login,
                          child: const Text("เข้าสู่ระบบ"),
                        ),
                  
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      "ลืมรหัสผ่าน?",
                      style: TextStyle(color: theme.primaryColor.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: theme.primaryColor.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
