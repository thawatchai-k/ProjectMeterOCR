import 'package:flutter/material.dart';
import 'package:meter_ocr_app/services/api_service.dart';
import 'package:meter_ocr_app/models/ocr_result_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/api.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<OcrResultModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<OcrResultModel>> _fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    if (token == null) {
      throw Exception("No token");
    }

    try {
      final jsonString = await ApiService.getHistory(token);
      final List<dynamic> data = jsonDecode(jsonString);
      return data.map((e) => OcrResultModel.fromJson(e)).toList();
    } catch (e) {
      print("Error fetching history: $e");
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ประวัติการสแกน"),
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
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<OcrResultModel>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("เกิดข้อผิดพลาด: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("ไม่มีประวัติ"));
            }

            final items = snapshot.data!;
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                final imageUrl = "${ApiConfig.baseUrl}${item.imageUrl}";
                
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(width: 80, height: 80, color: Colors.grey, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                    title: Text("Reading: ${item.reading ?? 'N/A'}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("S/N: ${item.serial ?? 'N/A'}"),
                        const SizedBox(height: 4),
                        Text(item.createdAt.split('T')[0], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
