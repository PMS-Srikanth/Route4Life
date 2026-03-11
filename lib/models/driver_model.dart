class DriverModel {
  final String id;
  final String name;
  final String vehicleNumber;
  final String phone;
  final String token;

  DriverModel({
    required this.id,
    required this.name,
    required this.vehicleNumber,
    required this.phone,
    required this.token,
  });

  factory DriverModel.fromJson(Map<String, dynamic> json) {
    return DriverModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      vehicleNumber: json['vehicleNumber'] ?? '',
      phone: json['phone'] ?? '',
      token: json['token'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'vehicleNumber': vehicleNumber,
        'phone': phone,
        'token': token,
      };
}
