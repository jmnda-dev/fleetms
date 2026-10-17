import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../api_client.dart';
import 'database.dart';

class OutboxSyncService {
  OutboxSyncService(this._db, this._apiClient) {
    _listenToConnectivity();
  }

  final AppDatabase _db;
  final ApiClient _apiClient;
  bool _isSyncing = false;

  void _listenToConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncOutbox();
      }
    });
  }

  Future<void> syncOutbox() async {
    // No point flushing before sign-in — authed requests would 401, and we'd risk
    // discarding queued writes. We flush again on auth (see app.dart) and on
    // connectivity regain.
    if (_isSyncing || !_apiClient.hasSession) return;
    _isSyncing = true;
    try {
      final entries = await (_db.select(_db.outboxEntries)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

      for (final entry in entries) {
        try {
          final payload = jsonDecode(entry.payload);
          switch (entry.method) {
            case 'POST':
              await _apiClient.post(entry.endpoint, payload);
              break;
            case 'PATCH':
              await _apiClient.patch(entry.endpoint, payload);
              break;
            case 'DELETE':
              await _apiClient.delete(entry.endpoint);
              break;
          }
          await _db.delete(_db.outboxEntries).delete(entry);
        } on ApiException catch (e) {
          // The ApiClient wraps every failure in ApiException (not DioException),
          // so this is the type to handle. Discard entries that can never succeed
          // on retry — bad request / not-found-route / conflict / unprocessable
          // (e.g. a malformed or stale-endpoint entry from an older build). Keep
          // auth, rate-limit and server errors queued to retry, so an expired
          // session or transient hiccup never drops a captured write.
          //
          // Crucially we DON'T abort the loop on a kept entry: a single stuck
          // write must never block the newer ones behind it (head-of-line
          // blocking). Each entry is retried independently on the next trigger.
          final status = e.statusCode;
          if (status != null && [400, 404, 409, 422].contains(status)) {
            debugPrint('Outbox entry ${entry.id} dropped ($status): ${e.message}');
            await _db.delete(_db.outboxEntries).delete(entry);
          } else {
            debugPrint('Outbox entry ${entry.id} kept ($status); will retry later.');
          }
        }
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
}

final outboxSyncServiceProvider = Provider<OutboxSyncService>((ref) {
  return OutboxSyncService(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
  );
});
