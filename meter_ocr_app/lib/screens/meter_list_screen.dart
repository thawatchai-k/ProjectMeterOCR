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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("รายชื่อมิเตอร์"),
      ),
      body: Column(
        children: [
          // 🔍 Premium Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "ค้นหาด้วยหมายเลข S/N...",
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor.withOpacity(0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: _filterMeters,
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchMeters,
              color: theme.primaryColor,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredMeters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.white10),
                          const SizedBox(height: 16),
                          const Text("ไม่พบข้อมูลมิเตอร์", style: TextStyle(color: Colors.white38)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: _filteredMeters.length,
                      itemBuilder: (context, index) {
                        final meter = _filteredMeters[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              if (meter.id == null) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => MeterDetailScreen(meter: meter),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.electric_meter_rounded, color: theme.primaryColor, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "S/N: ${meter.serialNumber}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "อาคาร: ${meter.building} ชั้น: ${meter.floor}",
                                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.white10),
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
