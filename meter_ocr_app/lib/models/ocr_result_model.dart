class OcrResultModel {
  final int id;
  final String imageUrl;
  final String text;
  final String? serial;
  final String? reading;
  final String createdAt;

  OcrResultModel({
    required this.id,
    required this.imageUrl,
    required this.text,
    this.serial,
    this.reading,
    required this.createdAt,
  });

  factory OcrResultModel.fromJson(Map<String, dynamic> json) {
    return OcrResultModel(
      id: json['id'],
      imageUrl: json['image_url'] ?? '',
      text: json['text'] ?? '',
      serial: json['serial'],
      reading: json['reading'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
