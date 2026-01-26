class MeterModel {
  final int? id;
  final String serialNumber;
  final String building;
  final String floor;
  final String? createdAt;

  MeterModel({
    this.id,
    required this.serialNumber,
    required this.building,
    required this.floor,
    this.createdAt,
  });

  factory MeterModel.fromJson(Map<String, dynamic> json) {
    return MeterModel(
      id: json['id'],
      serialNumber: json['serial_number'] ?? '',
      building: json['building'] ?? '',
      floor: json['floor'] ?? '',
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'serial_number': serialNumber,
      'building': building,
      'floor': floor,
    };
  }
}
