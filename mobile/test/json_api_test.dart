import 'package:flutter_test/flutter_test.dart';
import 'package:fleetms_mobile/core/json_api.dart';
import 'package:fleetms_mobile/features/vehicles/models/vehicle.dart';
import 'package:fleetms_mobile/features/auth/models/organization.dart';

void main() {
  group('JsonApi', () {
    test('many() reads a collection envelope', () {
      final body = {
        'data': [
          {
            'type': 'vehicle',
            'id': '1',
            'attributes': {'name': 'Truck'}
          },
          {
            'type': 'vehicle',
            'id': '2',
            'attributes': {'name': 'Van'}
          },
        ],
      };

      expect(JsonApi.many(body).length, 2);
      expect(JsonApi.many({'data': null}), isEmpty);
    });

    test('attributes() flattens a resource and merges its id', () {
      final resource = {
        'type': 'vehicle',
        'id': 'abc',
        'attributes': {'name': 'Truck', 'mileage': 1200},
      };

      final attrs = JsonApi.attributes(resource);
      expect(attrs['id'], 'abc');
      expect(attrs['name'], 'Truck');
      expect(attrs['mileage'], 1200);
    });

    test('asNum() coerces JSON:API string decimals to num', () {
      // Ash serializes decimals as strings to preserve precision.
      expect(JsonApi.asNum('1200.50'), 1200.5);
      expect(JsonApi.asNum(42), 42);
      expect(JsonApi.asNum(null), isNull);
      expect(JsonApi.asNum('not a number'), isNull);
    });

    test('body() wraps attributes into a write envelope', () {
      final body = JsonApi.body('vehicle', {'name': 'Truck'}, id: 'abc');
      expect(body, {
        'data': {
          'type': 'vehicle',
          'id': 'abc',
          'attributes': {'name': 'Truck'},
        },
      });
    });
  });

  test('Vehicle.fromJsonApi maps flattened attributes', () {
    final v = Vehicle.fromJsonApi({
      'id': 'v1',
      'name': 'Truck',
      'status': 'Active',
      'license_plate': 'ABZ 123',
      // The API sends decimals as strings — this used to throw on cast.
      'mileage': '4200.00',
    });

    expect(v.id, 'v1');
    expect(v.name, 'Truck');
    expect(v.status, 'Active');
    expect(v.licensePlate, 'ABZ 123');
    expect(v.mileage, 4200);
  });

  test('Organization.fromJson tolerates missing optional fields', () {
    final org = Organization.fromJson({'id': 'o1', 'public_id': 'org_123'});
    expect(org.id, 'o1');
    expect(org.publicId, 'org_123');
    expect(org.name, '');
    expect(org.owner, false);
  });
}
