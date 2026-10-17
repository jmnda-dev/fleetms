import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_api.dart';
import '../../core/offline/database.dart';
import 'models/inspection.dart';
import 'models/inspection_form_models.dart';

class InspectionsRepository {
  InspectionsRepository(this._client, this._db);

  final ApiClient _client;
  final AppDatabase _db;

  Future<List<Inspection>> list() async {
    final body =
        await _client.getMany('/inspections?include=vehicle,inspection_form');
    return JsonApi.many(body)
        .map((res) =>
            Inspection.fromJsonApi(JsonApi.attributes(res, body: body)))
        .toList();
  }

  Future<List<Inspection>> listArchived() async {
    final body = await _client
        .getMany('/inspections/archived?include=vehicle,inspection_form');
    return JsonApi.many(body)
        .map((res) =>
            Inspection.fromJsonApi(JsonApi.attributes(res, body: body)))
        .toList();
  }

  Future<Inspection> getById(String id) async {
    final body = await _client
        .getOne('/inspections/$id?include=vehicle,inspection_form');
    return Inspection.fromJsonApi(
        JsonApi.attributes(JsonApi.one(body), body: body));
  }

  Future<void> archive(String id) async {
    await _client.delete('/inspections/$id');
  }

  Future<void> restore(String id) async {
    await _client.patch('/inspections/$id/restore', {});
  }

  Future<Inspection> create(Map<String, dynamic> attributes) async {
    try {
      final body = await _client.post(
          '/inspections', JsonApi.body('inspection', attributes));
      return Inspection.fromJsonApi(JsonApi.attributes(JsonApi.one(body)));
    } catch (e) {
      final payload = jsonEncode(JsonApi.body('inspection', attributes));
      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              endpoint: '/inspections',
              method: 'POST',
              payload: payload,
            ),
          );
      final tempAttrs = Map<String, dynamic>.from(attributes);
      tempAttrs['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      return Inspection.fromJsonApi(tempAttrs);
    }
  }

  Future<void> syncForms() async {
    try {
      // 1. Fetch active inspection forms
      final formsBody =
          await _client.getMany('/inspection-forms?include=versions');
      final forms = JsonApi.many(formsBody);
      final included = formsBody['included'] as List<dynamic>? ?? [];

      await _db.transaction(() async {
        await _db.delete(_db.cachedInspectionForms).go();
        await _db.delete(_db.cachedInspectionFormVersions).go();

        for (final res in forms) {
          final attrs = JsonApi.attributes(res);
          await _db.into(_db.cachedInspectionForms).insert(
                CachedInspectionForm(
                    id: res['id'] as String, data: jsonEncode(attrs)),
              );
        }

        // Cache the versions included in the response
        for (final inc in included) {
          if (inc['type'] == 'inspection-form-version') {
            final attrs = JsonApi.attributes(inc as Map<String, dynamic>);
            // Add relationships into attrs to make them easily accessible
            final formIdData =
                inc['relationships']?['inspection_form']?['data'];
            if (formIdData != null) {
              attrs['inspection_form_id'] = formIdData['id'];
            }
            await _db.into(_db.cachedInspectionFormVersions).insert(
                  CachedInspectionFormVersion(
                      id: inc['id'] as String, data: jsonEncode(attrs)),
                );
          }
        }
      });
    } catch (_) {
      // Ignore network errors when syncing forms in the background.
    }
  }

  Future<List<InspectionForm>> getCachedForms() async {
    final cached = await _db.select(_db.cachedInspectionForms).get();
    return cached
        .map((c) => InspectionForm.fromJsonApi(
            jsonDecode(c.data) as Map<String, dynamic>, c.id))
        .toList();
  }

  Future<InspectionFormVersion?> getLatestCachedVersion(String formId) async {
    final cachedVersions =
        await _db.select(_db.cachedInspectionFormVersions).get();
    InspectionFormVersion? latestVersion;
    for (final c in cachedVersions) {
      final attrs = jsonDecode(c.data) as Map<String, dynamic>;
      if (attrs['inspection_form_id'] == formId) {
        final version = InspectionFormVersion.fromJsonApi(attrs, c.id);
        if (latestVersion == null ||
            version.versionNumber > latestVersion.versionNumber) {
          latestVersion = version;
        }
      }
    }
    return latestVersion;
  }
}

final inspectionsRepositoryProvider = Provider<InspectionsRepository>(
  (ref) => InspectionsRepository(
      ref.watch(apiClientProvider), ref.watch(databaseProvider)),
);
