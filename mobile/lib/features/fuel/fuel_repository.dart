import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_api.dart';
import '../../core/offline/database.dart';
import 'models/fuel_log.dart';

class FuelRepository {
  FuelRepository(this._client, this._db);

  final ApiClient _client;
  final AppDatabase _db;

  Future<List<FuelLog>> list() async {
    final body = await _client.getMany('/fuel-entries');
    return JsonApi.many(body)
        .map((res) => FuelLog.fromJsonApi(JsonApi.attributes(res)))
        .toList();
  }

  Future<FuelLog> create(Map<String, dynamic> attributes) async {
    try {
      final body = await _client.post(
          '/fuel-entries', JsonApi.body('fuel-entry', attributes));
      return FuelLog.fromJsonApi(JsonApi.attributes(JsonApi.one(body)));
    } catch (e) {
      final payload = jsonEncode(JsonApi.body('fuel-entry', attributes));
      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              endpoint: '/fuel-entries',
              method: 'POST',
              payload: payload,
            ),
          );
      final tempAttrs = Map<String, dynamic>.from(attributes);
      tempAttrs['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      return FuelLog.fromJsonApi(tempAttrs);
    }
  }
}

final fuelRepositoryProvider = Provider<FuelRepository>(
  (ref) =>
      FuelRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)),
);
