import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_api.dart';
import '../../core/offline/database.dart';
import 'models/vehicle.dart';

/// Talks to the vehicles endpoints and returns models. This is the seam where an
/// offline cache/outbox plugs in.
class VehiclesRepository {
  VehiclesRepository(this._client, this._db);

  final ApiClient _client;
  final AppDatabase _db;

  Future<List<Vehicle>> list() async {
    try {
      final body = await _client.getMany('/vehicles');
      final resources = JsonApi.many(body);
      
      // Update cache
      await _db.transaction(() async {
        await _db.delete(_db.cachedVehicles).go();
        for (final res in resources) {
          final attrs = JsonApi.attributes(res);
          await _db.into(_db.cachedVehicles).insert(
            CachedVehicle(id: res['id'], data: jsonEncode(attrs)),
          );
        }
      });
      
      return resources.map((res) => Vehicle.fromJsonApi(JsonApi.attributes(res))).toList();
    } catch (e) {
      // Offline fallback
      final cached = await _db.select(_db.cachedVehicles).get();
      if (cached.isNotEmpty) {
        return cached.map((c) => Vehicle.fromJsonApi(jsonDecode(c.data))).toList();
      }
      rethrow;
    }
  }

  Future<Vehicle> get(String id) async {
    try {
      final body = await _client.getOne('/vehicles/$id');
      final attrs = JsonApi.attributes(JsonApi.one(body));
      await _db.into(_db.cachedVehicles).insertOnConflictUpdate(
        CachedVehicle(id: id, data: jsonEncode(attrs)),
      );
      return Vehicle.fromJsonApi(attrs);
    } catch (e) {
      final cached = await (_db.select(_db.cachedVehicles)..where((t) => t.id.equals(id))).getSingleOrNull();
      if (cached != null) {
        return Vehicle.fromJsonApi(jsonDecode(cached.data));
      }
      rethrow;
    }
  }

  Future<Vehicle> create(Map<String, dynamic> attributes) async {
    try {
      final body = await _client.post('/vehicles', JsonApi.body('vehicle', attributes));
      final attrs = JsonApi.attributes(JsonApi.one(body));
      // update cache
      await _db.into(_db.cachedVehicles).insertOnConflictUpdate(
        CachedVehicle(id: JsonApi.one(body)['id'], data: jsonEncode(attrs)),
      );
      return Vehicle.fromJsonApi(attrs);
    } catch (e) {
      // Offline Outbox
      final payload = jsonEncode(JsonApi.body('vehicle', attributes));
      await _db.into(_db.outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          endpoint: '/vehicles',
          method: 'POST',
          payload: payload,
        ),
      );
      return Vehicle.fromJsonApi(attributes); 
    }
  }
}

final vehiclesRepositoryProvider = Provider<VehiclesRepository>(
  (ref) => VehiclesRepository(
    ref.watch(apiClientProvider),
    ref.watch(databaseProvider),
  ),
);
