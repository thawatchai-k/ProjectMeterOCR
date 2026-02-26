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
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("ประวัติการสแกน"),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<OcrResultModel>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text("เกิดข้อผิดพลาด: ${snapshot.error}", textAlign: TextAlign.center),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_rounded, size: 64, color: theme.primaryColor.withOpacity(0.2)),
                    const SizedBox(height: 16),
                    const Text("ยังไม่มีประวัติการสแกน"),
                  ],
                ),
              );
            }

            final items = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final imageUrl = "${ApiConfig.baseUrl}${item.imageUrl}";
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left Image Section
                            SizedBox(
                              width: 100,
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: theme.cardColor,
                                  child: const Icon(Icons.broken_image_rounded, color: Colors.white24),
                                ),
                              ),
                            ),
                            // Right Content Section
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.flash_on_rounded, size: 16, color: theme.colorScheme.secondary),
                                        const SizedBox(width: 8),
                                        Text(
                                          "ค่าไฟ: ${item.reading ?? 'N/A'}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.qr_code_rounded, size: 16, color: Colors.white54),
                                        const SizedBox(width: 8),
                                        Text(
                                          "S/N: ${item.serial ?? 'N/A'}",
                                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      item.createdAt.split('T')[0],
                                      style: TextStyle(fontSize: 11, color: theme.primaryColor.withOpacity(0.5)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: Icon(Icons.chevron_right_rounded, color: Colors.white24),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
