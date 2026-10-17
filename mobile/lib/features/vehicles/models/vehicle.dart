import '../../../core/json_api.dart';

/// A vehicle, as returned by `GET /api/v1/vehicles`. The reference model — a
/// plain class with a `fromJsonApi` reading the flattened attributes (see
/// `JsonApi.attributes`). The API sends more fields than the list needs; the
/// detail screen uses the extras.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    this.status,
    this.licensePlate,
    this.mileage,
    this.year,
    this.vin,
    this.color,
    this.type,
    this.bodyStyle,
    this.modelCode,
  });

  final String id;
  final String name;
  final String? status;
  final String? licensePlate;
  final num? mileage;
  final int? year;
  final String? vin;
  final String? color;
  final String? type;
  final String? bodyStyle;
  final String? modelCode;

  factory Vehicle.fromJsonApi(Map<String, dynamic> attrs) => Vehicle(
        id: attrs['id'] as String,
        name: (attrs['name'] ?? '') as String,
        status: attrs['status'] as String?,
        licensePlate: attrs['license_plate'] as String?,
        mileage: JsonApi.asNum(attrs['mileage']),
        year: JsonApi.asNum(attrs['year'])?.toInt(),
        vin: attrs['vin'] as String?,
        color: attrs['color'] as String?,
        type: attrs['type'] as String?,
        bodyStyle: attrs['body_style'] as String?,
        modelCode: attrs['model_code'] as String?,
      );
}
