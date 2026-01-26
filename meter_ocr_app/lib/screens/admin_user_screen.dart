import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api.dart';
import 'login_screen.dart';

class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key});

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends State<AdminUserScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/admin/users"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _users = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching users: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.baseUrl}/api/admin/users/$id"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _fetchUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ลบผู้ใช้สำเร็จ")),
        );
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ลบไม่สำเร็จ: ${err['error']}")),
        );
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
    }
  }

  void _showAddUserDialog() {
    final userController = TextEditingController();
    final passController = TextEditingController();
    String selectedRole = "physical_officer";

    showDialog(
      context: context,
      builder: (context) {
        bool isDialogLoading = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("เพิ่มผู้ใช้งานใหม่"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: userController, decoration: const InputDecoration(labelText: "ชื่อผู้ใช้ (Username)")),
                TextField(controller: passController, decoration: const InputDecoration(labelText: "รหัสผ่าน"), obscureText: true),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: "physical_officer", child: Text("เจ้าหน้าที่กายภาพ")),
                    DropdownMenuItem(value: "supply_officer", child: Text("เจ้าหน้าที่ฝ่ายพัสดุ")),
                    DropdownMenuItem(value: "executive", child: Text("ผู้บริหารคณะ")),
                    DropdownMenuItem(value: "admin", child: Text("ผู้ดูแลระบบ (Admin)")),
                  ],
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                  decoration: const InputDecoration(labelText: "ระดับสิทธิ์"),
                ),
                if (isDialogLoading)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading ? null : () => Navigator.pop(context), 
                child: const Text("ยกเลิก")
              ),
              ElevatedButton(
                onPressed: isDialogLoading ? null : () async {
                  if (userController.text.isEmpty || passController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("กรุณากรอกข้อมูลให้ครบทุกช่อง")),
                    );
                    return;
                  }

                  setDialogState(() => isDialogLoading = true);

                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString("token");

                    final response = await http.post(
                      Uri.parse("${ApiConfig.baseUrl}/api/admin/create-user"),
                      headers: {
                        "Authorization": "Bearer $token",
                        "Content-Type": "application/json"
                      },
                      body: jsonEncode({
                        "username": userController.text.trim(),
                        "password": passController.text.trim(),
                        "role": selectedRole,
                      }),
                    ).timeout(const Duration(seconds: 10));

                    if (response.statusCode == 201) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      _fetchUsers();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("สร้างผู้ใช้สำเร็จ")),
                      );
                    } else {
                      final body = jsonDecode(response.body);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("สร้างไม่สำเร็จ: ${body['error'] ?? response.body}")),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("เกิดข้อผิดพลาดในการเชื่อมต่อ: $e")),
                    );
                  } finally {
                    if (mounted) {
                      setDialogState(() => isDialogLoading = false);
                    }
                  }
                },
                child: const Text("บันทึก"),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin': return 'ผู้ดูแลระบบ';
      case 'physical_officer': return 'เจ้าหน้าที่กายภาพ';
      case 'supply_officer': return 'เจ้าหน้าที่พัสดุ';
      case 'executive': return 'ผู้บริหาร';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการรายชื่อผู้ใช้งาน"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddUserDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final u = _users[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(u['username']),
                  subtitle: Text(_getRoleLabel(u['role'])),
                  trailing: u['role'] == 'admin' 
                    ? null 
                    : IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteUser(u['id']),
                      ),
                );
              },
            ),
    );
  }
}
