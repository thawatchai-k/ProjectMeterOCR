import 'package:flutter/material.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const MeterOCRApp());
}

class MeterOCRApp extends StatelessWidget {
  const MeterOCRApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meter OCR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
    );
  }
}
