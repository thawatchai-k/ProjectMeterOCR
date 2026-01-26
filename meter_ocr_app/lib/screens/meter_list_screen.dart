import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meter_model.dart';
import '../services/api_service.dart';
import 'meter_detail_screen.dart';
import 'login_screen.dart';

class MeterListScreen extends StatefulWidget {
  const MeterListScreen({super.key});

  @override
  State<MeterListScreen> createState() => _MeterListScreenState();
}

class _MeterListScreenState extends State<MeterListScreen> {
  List<MeterModel> _meters = [];
  List<MeterModel> _filteredMeters = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMeters();
  }

  Future<void> _fetchMeters() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    try {
      final jsonString = await ApiService.getMeters(token);
      final List<dynamic> data = jsonDecode(jsonString);
      setState(() {
        _meters = data.map((e) => MeterModel.fromJson(e)).toList();
        _filteredMeters = _meters;
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching meters: $e");
      setState(() => _isLoading = false);
    }
  }

  void _filterMeters(String query) {
    setState(() {
      _filteredMeters = _meters
          .where((m) => m.serialNumber.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("รายชื่อมิเตอร์ทั้งหมด"),
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
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "ค้นหาด้วย S/N...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterMeters,
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMeters,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredMeters.isEmpty
                  ? const Center(child: Text("ไม่พบข้อมูลมิเตอร์"))
                  : ListView.builder(
                      itemCount: _filteredMeters.length,
                      itemBuilder: (context, index) {
                        final meter = _filteredMeters[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: InkWell(
                            onTap: () {
                              debugPrint("🔵 DEBUG: User tapped on S/N: ${meter.serialNumber}, ID: ${meter.id}");
                              
                              if (meter.id == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("ข้อผิดพลาด: ไม่พบ ID ของมิเตอร์")),
                                );
                                return;
                              }

                              // แสดง SnackBar เพื่อยืนยันว่าปุ่มถูกกดแล้ว
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("กำลังโหลดประวัติของ S/N: ${meter.serialNumber}"),
                                  duration: const Duration(seconds: 1),
                                ),
                              );

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MeterDetailScreen(meter: meter),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  const CircleAvatar(child: Icon(Icons.wb_incandescent)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "S/N: ${meter.serialNumber}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        Text("อาคาร: ${meter.building} ชั้น: ${meter.floor}"),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
