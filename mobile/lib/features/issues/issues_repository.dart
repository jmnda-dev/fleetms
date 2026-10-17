import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/json_api.dart';
import '../../core/offline/database.dart';
import 'models/issue.dart';

class IssuesRepository {
  IssuesRepository(this._client, this._db);

  final ApiClient _client;
  final AppDatabase _db;

  Future<List<Issue>> list() async {
    final body = await _client.getMany('/issues');
    return JsonApi.many(body).map((res) => Issue.fromJsonApi(JsonApi.attributes(res))).toList();
  }

  Future<Issue> create(Map<String, dynamic> attributes) async {
    try {
      final body = await _client.post('/issues', JsonApi.body('issue', attributes));
      return Issue.fromJsonApi(JsonApi.attributes(JsonApi.one(body)));
    } catch (e) {
      final payload = jsonEncode(JsonApi.body('issue', attributes));
      await _db.into(_db.outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          endpoint: '/issues',
          method: 'POST',
          payload: payload,
        ),
      );
      final tempAttrs = Map<String, dynamic>.from(attributes);
      tempAttrs['id'] = 'temp_${DateTime.now().millisecondsSinceEpoch}'; 
      return Issue.fromJsonApi(tempAttrs);
    }
  }
}

final issuesRepositoryProvider = Provider<IssuesRepository>(
  (ref) => IssuesRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)),
);
