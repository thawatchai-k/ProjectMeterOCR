import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meter_model.dart';
import '../models/meter_reading_model.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class MeterDetailScreen extends StatefulWidget {
  final MeterModel meter;

  const MeterDetailScreen({super.key, required this.meter});

  @override
  State<MeterDetailScreen> createState() => _MeterDetailScreenState();
}

class _MeterDetailScreenState extends State<MeterDetailScreen> {
  List<MeterReadingModel> _readings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReadings();
  }

  Future<void> _fetchReadings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) return;

    try {
      final jsonString = await ApiService.getMeterReadings(widget.meter.id!, token);
      final List<dynamic> data = jsonDecode(jsonString);
      setState(() {
        _readings = data.map((e) => MeterReadingModel.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      print("Error fetching readings: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ประวัติ S/N: ${widget.meter.serialNumber}"),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meter Info Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("อาคาร: ${widget.meter.building}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("ชั้น: ${widget.meter.floor}", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("ประวัติการบันทึกหน่วยไฟ", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchReadings,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _readings.isEmpty
                  ? const Center(child: Text("ยังไม่มีข้อมูลการบันทึก"))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _readings.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final reading = _readings[index];
                        final dateStr = reading.createdAt.split('T')[0];
                        final timeStr = reading.createdAt.split('T')[1].substring(0, 5);
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            backgroundColor: Colors.green,
                            child: Icon(Icons.flash_on, color: Colors.white),
                          ),
                          title: Text("${reading.reading} kWh", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          subtitle: Text("บันทึกเมื่อ: $dateStr เวลา $timeStr น."),
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
