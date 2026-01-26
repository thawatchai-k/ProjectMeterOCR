class ApiConfig {
  // ใช้ localhost สำหรับ Chrome, ใช้ 10.0.2.2 สำหรับ Android Emulator
  static const String baseUrl = 'http://localhost:5000';

  static const String login = '$baseUrl/api/login';
  static const String ocr = '$baseUrl/api/ocr';
  static const String history = '$baseUrl/api/history';
  static const String meters = '$baseUrl/api/meters';
  static const String readings = '$baseUrl/api/readings';
}
