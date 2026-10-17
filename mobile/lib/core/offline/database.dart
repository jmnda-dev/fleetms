import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

part 'database.g.dart';

class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get endpoint => text()();
  TextColumn get method => text()(); // POST, PATCH, DELETE
  TextColumn get payload => text()(); // JSON string
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CachedVehicles extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()(); // JSON string of attributes
  @override
  Set<Column> get primaryKey => {id};
}

class CachedInspectionForms extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()(); // JSON string of attributes
  @override
  Set<Column> get primaryKey => {id};
}

class CachedInspectionFormVersions extends Table {
  TextColumn get id => text()();
  TextColumn get data => text()(); // JSON string of attributes
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [OutboxEntries, CachedVehicles, CachedInspectionForms, CachedInspectionFormVersions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(cachedInspectionForms);
            await m.createTable(cachedInspectionFormVersions);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'fleetms_offline.sqlite'));
    
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    
    return NativeDatabase.createInBackground(file);
  });
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
