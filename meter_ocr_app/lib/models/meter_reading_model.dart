class MeterReadingModel {
  final int id;
  final int meterId;
  final String? serialNumber;
  final String reading;
  final String? imagePath;
  final String createdAt;

  MeterReadingModel({
    required this.id,
    required this.meterId,
    this.serialNumber,
    required this.reading,
    this.imagePath,
    required this.createdAt,
  });

  factory MeterReadingModel.fromJson(Map<String, dynamic> json) {
    return MeterReadingModel(
      id: json['id'],
      meterId: json['meter_id'],
      serialNumber: json['serial_number'],
      reading: json['reading'] ?? '',
      imagePath: json['image_path'],
      createdAt: json['created_at'] ?? '',
    );
  }
}
