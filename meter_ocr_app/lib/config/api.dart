class ApiConfig {
  // เลือกใช้ baseUrl ให้ถูกกับอุปกรณ์ที่รัน:
  // static const String baseUrl = 'http://localhost:5000';      // สำหรับรันบน Chrome
  // static const String baseUrl = 'http://10.0.2.2:5000';       // สำหรับรันบน Android Emulator
  // static const String baseUrl = 'http://localhost:5000';       // สำหรับ ADB reverse (USB ไม่ต้องเน็ต)
  static const String baseUrl = 'http://127.0.0.1:5000';        // ใช้ 127.0.0.1 แทน localhost (แก้ปัญหา DNS)

  static const String login = '$baseUrl/api/login';
  static const String ocr = '$baseUrl/api/ocr';
  static const String history = '$baseUrl/api/history';
  static const String meters = '$baseUrl/api/meters';
  static const String readings = '$baseUrl/api/readings';
}
