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
  String _role = "";

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchMeters();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString("role") ?? "";
    });
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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("จัดการมิเตอร์"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            // ✨ Registration Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      "ลงทะเบียนมิเตอร์ใหม่",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 24),
                    _buildStyledTextField(
                      controller: _serialController,
                      label: "หมายเลขมิเตอร์ (S/N)",
                      icon: Icons.qr_code_rounded,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStyledTextField(
                            controller: _buildingController,
                            label: "อาคาร",
                            icon: Icons.business_rounded,
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStyledTextField(
                            controller: _floorController,
                            label: "ชั้น",
                            icon: Icons.layers_rounded,
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Icon(Icons.add_rounded),
                      label: const Text("บันทึกข้อมูล"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
            Row(
              children: [
                Icon(Icons.list_alt_rounded, size: 20, color: theme.primaryColor),
                const SizedBox(width: 12),
                const Text(
                  "รายการมิเตอร์ที่ลงทะเบียนแล้ว",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 📊 Meters List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _meters.length,
              itemBuilder: (context, index) {
                final meter = _meters[index];
                final dateStr = meter.createdAt?.split('T')[0] ?? "-";
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.electric_meter_rounded, color: theme.primaryColor, size: 24),
                      ),
                      title: Text("S/N: ${meter.serialNumber}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        "อาคาร: ${meter.building} ชั้น: ${meter.floor} | $dateStr",
                        style: const TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                      trailing: _role == 'admin' 
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteMeter(meter.id!),
                          )
                        : const Icon(Icons.chevron_right_rounded, color: Colors.white10),
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

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
          prefixIcon: Icon(icon, color: theme.primaryColor.withOpacity(0.7), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: (v) => v!.isEmpty ? "!" : null,
      ),
    );
  }
}
