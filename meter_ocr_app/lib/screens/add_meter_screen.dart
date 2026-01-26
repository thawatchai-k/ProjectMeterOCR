import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meter_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class AddMeterScreen extends StatefulWidget {
  const AddMeterScreen({super.key});

  @override
  State<AddMeterScreen> createState() => _AddMeterScreenState();
}

class _AddMeterScreenState extends State<AddMeterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _serialController = TextEditingController();
  final _buildingController = TextEditingController();
  final _floorController = TextEditingController();

  bool _isLoading = false;
  List<MeterModel> _meters = [];

  @override
  void initState() {
    super.initState();
    _fetchMeters();
  }

  Future<void> _fetchMeters() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    try {
      final jsonString = await ApiService.getMeters(token);
      final List<dynamic> data = jsonDecode(jsonString);
      setState(() {
        _meters = data.map((e) => MeterModel.fromJson(e)).toList();
      });
    } catch (e) {
      print("Error fetching meters: $e");
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("กรุณาเข้าสู่ระบบใหม่")));
      setState(() => _isLoading = false);
      return;
    }

    final newMeter = MeterModel(
      serialNumber: _serialController.text,
      building: _buildingController.text,
      floor: _floorController.text,
    );

    try {
      await ApiService.addMeter(newMeter, token);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("บันทึกมิเตอร์สำเร็จ")));
      
      // Clear form
      _serialController.clear();
      _buildingController.clear();
      _floorController.clear();
      
      // Refresh list
      _fetchMeters();

    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMeter(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ยืนยันการลบ"),
        content: const Text("คุณต้องการลบมิเตอร์นี้ใช่หรือไม่?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("ยกเลิก")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("ลบ", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    try {
      await ApiService.deleteMeter(id, token);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ลบสำเร็จ")));
      _fetchMeters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ลบไม่สำเร็จ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("เพิ่มมิเตอร์"),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Form Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text("ลงทะเบียนมิเตอร์ใหม่", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serialController,
                        decoration: const InputDecoration(labelText: "หมายเลขมิเตอร์ (S/N)", border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? "กรุณากรอก S/N" : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _buildingController,
                              decoration: const InputDecoration(labelText: "อาคาร", border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? "ระบุอาคาร" : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _floorController,
                              decoration: const InputDecoration(labelText: "ชั้น", border: OutlineInputBorder()),
                              validator: (v) => v!.isEmpty ? "ระบุชั้น" : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _submit,
                          icon: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
                          label: const Text("บันทึก"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue, 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12)
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("รายการมิเตอร์ที่ลงทะเบียนแล้ว", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            
            // List Section
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _meters.length,
              itemBuilder: (context, index) {
                final meter = _meters[index];
                final dateStr = meter.createdAt?.split('T')[0] ?? "-";
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.wb_incandescent_outlined)),
                    title: Text("S/N: ${meter.serialNumber}"),
                    subtitle: Text("อาคาร: ${meter.building} ชั้น: ${meter.floor}\nเพิ่มเมื่อ: $dateStr"),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteMeter(meter.id!),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
