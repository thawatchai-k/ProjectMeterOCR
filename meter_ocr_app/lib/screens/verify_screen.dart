import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import '../models/meter_model.dart';
import '../services/api_service.dart';

class VerifyScreen extends StatefulWidget {
  final XFile? image;
  final String initialSerial;
  final String initialReading;

  const VerifyScreen({
    super.key,
    required this.image,
    required this.initialSerial,
    required this.initialReading,
  });

  @override
  State<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<VerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _serialController;
  late TextEditingController _readingController;

  MeterModel? _matchedMeter;
  String _statusMessage = "";
  bool _isLoading = false;
  List<MeterModel> _allMeters = [];

  @override
  void initState() {
    super.initState();
    _serialController = TextEditingController(text: widget.initialSerial);
    _readingController = TextEditingController(text: widget.initialReading);
    
    _loadMetersAndCheck();
  }
  
  // โหลดข้อมูลมิเตอร์ทั้งหมดเพื่อมาเทียบ (หรือจะทำ API search ก็ได้ แต่นี่โหลดหมดง่ายกว่าสำหรับ Demo)
  Future<void> _loadMetersAndCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    try {
      final jsonString = await ApiService.getMeters(token);
      final List<dynamic> data = jsonDecode(jsonString);
      setState(() {
        _allMeters = data.map((e) => MeterModel.fromJson(e)).toList();
      });
      
      _checkSerial(_serialController.text);
      
    } catch (e) {
      print("Error loading meters: $e");
    }
  }

  void _checkSerial(String sn) {
    // ล้างค่าเก่า
    setState(() {
      _matchedMeter = null;
      _statusMessage = "ไม่พบข้อมูลมิเตอร์ในระบบ (จะบันทึกไม่ได้)";
    });

    if (sn.isEmpty) {
        setState(() => _statusMessage = "กรุณาระบุ S/N");
        return;
    }

    try {
      // ค้นหาในรายการที่โหลดมา
      // ทำ clean text ก่อนเปรียบเทียบ (ลบ space/dash)
      final cleanSnInput = sn.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      
      final found = _allMeters.firstWhere((m) {
        final cleanSnDb = m.serialNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        return cleanSnDb == cleanSnInput || m.serialNumber == sn; // เทียบทั้งแบบ clean และ exact
      });
      
      setState(() {
        _matchedMeter = found;
        _statusMessage = "พบข้อมูล: อาคาร ${found.building} ชั้น ${found.floor}";
      });
    } catch (e) {
      // ไม่เจอ
      setState(() => _statusMessage = "ไม่พบ S/N นี้ในระบบ");
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_matchedMeter == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ต้องมี S/N ที่ตรงกับในระบบเท่านั้นถึงจะบันทึกได้")),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      
      // ใช้ serialNumber จากตัวแปรที่เรา match เจอใน DB (เพื่อความแม่นยำ)
      final canonicalSn = _matchedMeter!.serialNumber;
      
      await ApiService.saveReading(canonicalSn, _readingController.text, null, token!);
      
      if (!mounted) return;

      // แสดงผลสำเร็จแบบสวยงาม
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              SizedBox(height: 16),
              Text("บันทึกสำเร็จ"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("มิเตอร์: $canonicalSn"),
              Text("อาคาร: ${_matchedMeter!.building} ชั้น: ${_matchedMeter!.floor}"),
              Text("หน่วยที่อ่านได้: ${_readingController.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // ปิด dialog
                Navigator.pop(context); // กลับหน้าหลัก
              },
              child: const Text("ตกลง"),
            )
          ],
        ),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ตรวจสอบและบันทึก")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Preview (Small Header)
              if (widget.image != null)
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? Image.network(widget.image!.path, fit: BoxFit.contain)
                        : Image.file(File(widget.image!.path), fit: BoxFit.contain),
                  ),
                ),
                
              const SizedBox(height: 24),
              
              const Text("ตรวจสอบความถูกต้อง", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              // S/N Input
              TextFormField(
                controller: _serialController,
                decoration: InputDecoration(
                  labelText: "หมายเลขมิเตอร์ (S/N)",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _checkSerial(_serialController.text),
                  ),
                ),
                onChanged: (val) {
                   // อาจจะ auto-search เมื่อพิมพ์?
                   // _checkSerial(val);
                },
                onFieldSubmitted: _checkSerial,
              ),
              
              // Status Message
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Icon(
                      _matchedMeter != null ? Icons.check_circle : Icons.warning,
                      color: _matchedMeter != null ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage, 
                        style: TextStyle(
                          color: _matchedMeter != null ? Colors.green[700] : Colors.orange[800],
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              
              // Reading Input
              TextFormField(
                controller: _readingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "เลขหน่วย (Reading)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? "ระบุค่าที่อ่านได้" : null,
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _save,
                icon: const Icon(Icons.save),
                label: const Text("ยืนยันและบันทึก"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _matchedMeter != null ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
