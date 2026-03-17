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
      serialNumber: json['serial_number']?.toString() ?? '',
      building: json['building']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
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
