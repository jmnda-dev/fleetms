// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OutboxEntriesTable extends OutboxEntries
    with TableInfo<$OutboxEntriesTable, OutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _endpointMeta =
      const VerificationMeta('endpoint');
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
      'endpoint', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  @override
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
      'method', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, endpoint, method, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_entries';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('endpoint')) {
      context.handle(_endpointMeta,
          endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta));
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta,
          method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    } else if (isInserting) {
      context.missing(_methodMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      endpoint: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}endpoint'])!,
      method: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}method'])!,
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutboxEntriesTable createAlias(String alias) {
    return $OutboxEntriesTable(attachedDatabase, alias);
  }
}

class OutboxEntry extends DataClass implements Insertable<OutboxEntry> {
  final int id;
  final String endpoint;
  final String method;
  final String payload;
  final DateTime createdAt;
  const OutboxEntry(
      {required this.id,
      required this.endpoint,
      required this.method,
      required this.payload,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['endpoint'] = Variable<String>(endpoint);
    map['method'] = Variable<String>(method);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return OutboxEntriesCompanion(
      id: Value(id),
      endpoint: Value(endpoint),
      method: Value(method),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEntry(
      id: serializer.fromJson<int>(json['id']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      method: serializer.fromJson<String>(json['method']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'endpoint': serializer.toJson<String>(endpoint),
      'method': serializer.toJson<String>(method),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxEntry copyWith(
          {int? id,
          String? endpoint,
          String? method,
          String? payload,
          DateTime? createdAt}) =>
      OutboxEntry(
        id: id ?? this.id,
        endpoint: endpoint ?? this.endpoint,
        method: method ?? this.method,
        payload: payload ?? this.payload,
        createdAt: createdAt ?? this.createdAt,
      );
  OutboxEntry copyWithCompanion(OutboxEntriesCompanion data) {
    return OutboxEntry(
      id: data.id.present ? data.id.value : this.id,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      method: data.method.present ? data.method.value : this.method,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntry(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, endpoint, method, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEntry &&
          other.id == this.id &&
          other.endpoint == this.endpoint &&
          other.method == this.method &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class OutboxEntriesCompanion extends UpdateCompanion<OutboxEntry> {
  final Value<int> id;
  final Value<String> endpoint;
  final Value<String> method;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  const OutboxEntriesCompanion({
    this.id = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.method = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OutboxEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String endpoint,
    required String method,
    required String payload,
    this.createdAt = const Value.absent(),
  })  : endpoint = Value(endpoint),
        method = Value(method),
        payload = Value(payload);
  static Insertable<OutboxEntry> custom({
    Expression<int>? id,
    Expression<String>? endpoint,
    Expression<String>? method,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (endpoint != null) 'endpoint': endpoint,
      if (method != null) 'method': method,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OutboxEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? endpoint,
      Value<String>? method,
      Value<String>? payload,
      Value<DateTime>? createdAt}) {
    return OutboxEntriesCompanion(
      id: id ?? this.id,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEntriesCompanion(')
          ..write('id: $id, ')
          ..write('endpoint: $endpoint, ')
          ..write('method: $method, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CachedVehiclesTable extends CachedVehicles
    with TableInfo<$CachedVehiclesTable, CachedVehicle> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVehiclesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_vehicles';
  @override
  VerificationContext validateIntegrity(Insertable<CachedVehicle> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedVehicle map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVehicle(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedVehiclesTable createAlias(String alias) {
    return $CachedVehiclesTable(attachedDatabase, alias);
  }
}

class CachedVehicle extends DataClass implements Insertable<CachedVehicle> {
  final String id;
  final String data;
  const CachedVehicle({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedVehiclesCompanion toCompanion(bool nullToAbsent) {
    return CachedVehiclesCompanion(
      id: Value(id),
      data: Value(data),
    );
  }

  factory CachedVehicle.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVehicle(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedVehicle copyWith({String? id, String? data}) => CachedVehicle(
        id: id ?? this.id,
        data: data ?? this.data,
      );
  CachedVehicle copyWithCompanion(CachedVehiclesCompanion data) {
    return CachedVehicle(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVehicle(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVehicle &&
          other.id == this.id &&
          other.data == this.data);
}

class CachedVehiclesCompanion extends UpdateCompanion<CachedVehicle> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const CachedVehiclesCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVehiclesCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        data = Value(data);
  static Insertable<CachedVehicle> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVehiclesCompanion copyWith(
      {Value<String>? id, Value<String>? data, Value<int>? rowid}) {
    return CachedVehiclesCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVehiclesCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedInspectionFormsTable extends CachedInspectionForms
    with TableInfo<$CachedInspectionFormsTable, CachedInspectionForm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedInspectionFormsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_inspection_forms';
  @override
  VerificationContext validateIntegrity(
      Insertable<CachedInspectionForm> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedInspectionForm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedInspectionForm(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedInspectionFormsTable createAlias(String alias) {
    return $CachedInspectionFormsTable(attachedDatabase, alias);
  }
}

class CachedInspectionForm extends DataClass
    implements Insertable<CachedInspectionForm> {
  final String id;
  final String data;
  const CachedInspectionForm({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedInspectionFormsCompanion toCompanion(bool nullToAbsent) {
    return CachedInspectionFormsCompanion(
      id: Value(id),
      data: Value(data),
    );
  }

  factory CachedInspectionForm.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedInspectionForm(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedInspectionForm copyWith({String? id, String? data}) =>
      CachedInspectionForm(
        id: id ?? this.id,
        data: data ?? this.data,
      );
  CachedInspectionForm copyWithCompanion(CachedInspectionFormsCompanion data) {
    return CachedInspectionForm(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedInspectionForm(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedInspectionForm &&
          other.id == this.id &&
          other.data == this.data);
}

class CachedInspectionFormsCompanion
    extends UpdateCompanion<CachedInspectionForm> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const CachedInspectionFormsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedInspectionFormsCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        data = Value(data);
  static Insertable<CachedInspectionForm> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedInspectionFormsCompanion copyWith(
      {Value<String>? id, Value<String>? data, Value<int>? rowid}) {
    return CachedInspectionFormsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedInspectionFormsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedInspectionFormVersionsTable extends CachedInspectionFormVersions
    with
        TableInfo<$CachedInspectionFormVersionsTable,
            CachedInspectionFormVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedInspectionFormVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
      'data', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, data];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_inspection_form_versions';
  @override
  VerificationContext validateIntegrity(
      Insertable<CachedInspectionFormVersion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
          _dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedInspectionFormVersion map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedInspectionFormVersion(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      data: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data'])!,
    );
  }

  @override
  $CachedInspectionFormVersionsTable createAlias(String alias) {
    return $CachedInspectionFormVersionsTable(attachedDatabase, alias);
  }
}

class CachedInspectionFormVersion extends DataClass
    implements Insertable<CachedInspectionFormVersion> {
  final String id;
  final String data;
  const CachedInspectionFormVersion({required this.id, required this.data});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['data'] = Variable<String>(data);
    return map;
  }

  CachedInspectionFormVersionsCompanion toCompanion(bool nullToAbsent) {
    return CachedInspectionFormVersionsCompanion(
      id: Value(id),
      data: Value(data),
    );
  }

  factory CachedInspectionFormVersion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedInspectionFormVersion(
      id: serializer.fromJson<String>(json['id']),
      data: serializer.fromJson<String>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'data': serializer.toJson<String>(data),
    };
  }

  CachedInspectionFormVersion copyWith({String? id, String? data}) =>
      CachedInspectionFormVersion(
        id: id ?? this.id,
        data: data ?? this.data,
      );
  CachedInspectionFormVersion copyWithCompanion(
      CachedInspectionFormVersionsCompanion data) {
    return CachedInspectionFormVersion(
      id: data.id.present ? data.id.value : this.id,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedInspectionFormVersion(')
          ..write('id: $id, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, data);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedInspectionFormVersion &&
          other.id == this.id &&
          other.data == this.data);
}

class CachedInspectionFormVersionsCompanion
    extends UpdateCompanion<CachedInspectionFormVersion> {
  final Value<String> id;
  final Value<String> data;
  final Value<int> rowid;
  const CachedInspectionFormVersionsCompanion({
    this.id = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedInspectionFormVersionsCompanion.insert({
    required String id,
    required String data,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        data = Value(data);
  static Insertable<CachedInspectionFormVersion> custom({
    Expression<String>? id,
    Expression<String>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedInspectionFormVersionsCompanion copyWith(
      {Value<String>? id, Value<String>? data, Value<int>? rowid}) {
    return CachedInspectionFormVersionsCompanion(
      id: id ?? this.id,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedInspectionFormVersionsCompanion(')
          ..write('id: $id, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxEntriesTable outboxEntries = $OutboxEntriesTable(this);
  late final $CachedVehiclesTable cachedVehicles = $CachedVehiclesTable(this);
  late final $CachedInspectionFormsTable cachedInspectionForms =
      $CachedInspectionFormsTable(this);
  late final $CachedInspectionFormVersionsTable cachedInspectionFormVersions =
      $CachedInspectionFormVersionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        outboxEntries,
        cachedVehicles,
        cachedInspectionForms,
        cachedInspectionFormVersions
      ];
}

typedef $$OutboxEntriesTableCreateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<int> id,
  required String endpoint,
  required String method,
  required String payload,
  Value<DateTime> createdAt,
});
typedef $$OutboxEntriesTableUpdateCompanionBuilder = OutboxEntriesCompanion
    Function({
  Value<int> id,
  Value<String> endpoint,
  Value<String> method,
  Value<String> payload,
  Value<DateTime> createdAt,
});

class $$OutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endpoint => $composableBuilder(
      column: $table.endpoint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method => $composableBuilder(
      column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEntriesTable> {
  $$OutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()> {
  $$OutboxEntriesTableTableManager(_$AppDatabase db, $OutboxEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> endpoint = const Value.absent(),
            Value<String> method = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OutboxEntriesCompanion(
            id: id,
            endpoint: endpoint,
            method: method,
            payload: payload,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String endpoint,
            required String method,
            required String payload,
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              OutboxEntriesCompanion.insert(
            id: id,
            endpoint: endpoint,
            method: method,
            payload: payload,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$OutboxEntriesTable, OutboxEntry>(table),
                    BaseReferences<_$AppDatabase, $OutboxEntriesTable,
                        OutboxEntry>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutboxEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutboxEntriesTable,
    OutboxEntry,
    $$OutboxEntriesTableFilterComposer,
    $$OutboxEntriesTableOrderingComposer,
    $$OutboxEntriesTableAnnotationComposer,
    $$OutboxEntriesTableCreateCompanionBuilder,
    $$OutboxEntriesTableUpdateCompanionBuilder,
    (
      OutboxEntry,
      BaseReferences<_$AppDatabase, $OutboxEntriesTable, OutboxEntry>
    ),
    OutboxEntry,
    PrefetchHooks Function()>;
typedef $$CachedVehiclesTableCreateCompanionBuilder = CachedVehiclesCompanion
    Function({
  required String id,
  required String data,
  Value<int> rowid,
});
typedef $$CachedVehiclesTableUpdateCompanionBuilder = CachedVehiclesCompanion
    Function({
  Value<String> id,
  Value<String> data,
  Value<int> rowid,
});

class $$CachedVehiclesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedVehiclesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedVehiclesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVehiclesTable> {
  $$CachedVehiclesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedVehiclesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedVehiclesTable,
    CachedVehicle,
    $$CachedVehiclesTableFilterComposer,
    $$CachedVehiclesTableOrderingComposer,
    $$CachedVehiclesTableAnnotationComposer,
    $$CachedVehiclesTableCreateCompanionBuilder,
    $$CachedVehiclesTableUpdateCompanionBuilder,
    (
      CachedVehicle,
      BaseReferences<_$AppDatabase, $CachedVehiclesTable, CachedVehicle>
    ),
    CachedVehicle,
    PrefetchHooks Function()> {
  $$CachedVehiclesTableTableManager(
      _$AppDatabase db, $CachedVehiclesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVehiclesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVehiclesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVehiclesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedVehiclesCompanion(
            id: id,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String data,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedVehiclesCompanion.insert(
            id: id,
            data: data,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedVehiclesTable, CachedVehicle>(table),
                    BaseReferences<_$AppDatabase, $CachedVehiclesTable,
                        CachedVehicle>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedVehiclesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CachedVehiclesTable,
    CachedVehicle,
    $$CachedVehiclesTableFilterComposer,
    $$CachedVehiclesTableOrderingComposer,
    $$CachedVehiclesTableAnnotationComposer,
    $$CachedVehiclesTableCreateCompanionBuilder,
    $$CachedVehiclesTableUpdateCompanionBuilder,
    (
      CachedVehicle,
      BaseReferences<_$AppDatabase, $CachedVehiclesTable, CachedVehicle>
    ),
    CachedVehicle,
    PrefetchHooks Function()>;
typedef $$CachedInspectionFormsTableCreateCompanionBuilder
    = CachedInspectionFormsCompanion Function({
  required String id,
  required String data,
  Value<int> rowid,
});
typedef $$CachedInspectionFormsTableUpdateCompanionBuilder
    = CachedInspectionFormsCompanion Function({
  Value<String> id,
  Value<String> data,
  Value<int> rowid,
});

class $$CachedInspectionFormsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormsTable> {
  $$CachedInspectionFormsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedInspectionFormsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormsTable> {
  $$CachedInspectionFormsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedInspectionFormsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormsTable> {
  $$CachedInspectionFormsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedInspectionFormsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedInspectionFormsTable,
    CachedInspectionForm,
    $$CachedInspectionFormsTableFilterComposer,
    $$CachedInspectionFormsTableOrderingComposer,
    $$CachedInspectionFormsTableAnnotationComposer,
    $$CachedInspectionFormsTableCreateCompanionBuilder,
    $$CachedInspectionFormsTableUpdateCompanionBuilder,
    (
      CachedInspectionForm,
      BaseReferences<_$AppDatabase, $CachedInspectionFormsTable,
          CachedInspectionForm>
    ),
    CachedInspectionForm,
    PrefetchHooks Function()> {
  $$CachedInspectionFormsTableTableManager(
      _$AppDatabase db, $CachedInspectionFormsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedInspectionFormsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedInspectionFormsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedInspectionFormsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedInspectionFormsCompanion(
            id: id,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String data,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedInspectionFormsCompanion.insert(
            id: id,
            data: data,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedInspectionFormsTable,
                        CachedInspectionForm>(table),
                    BaseReferences<_$AppDatabase, $CachedInspectionFormsTable,
                        CachedInspectionForm>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedInspectionFormsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CachedInspectionFormsTable,
        CachedInspectionForm,
        $$CachedInspectionFormsTableFilterComposer,
        $$CachedInspectionFormsTableOrderingComposer,
        $$CachedInspectionFormsTableAnnotationComposer,
        $$CachedInspectionFormsTableCreateCompanionBuilder,
        $$CachedInspectionFormsTableUpdateCompanionBuilder,
        (
          CachedInspectionForm,
          BaseReferences<_$AppDatabase, $CachedInspectionFormsTable,
              CachedInspectionForm>
        ),
        CachedInspectionForm,
        PrefetchHooks Function()>;
typedef $$CachedInspectionFormVersionsTableCreateCompanionBuilder
    = CachedInspectionFormVersionsCompanion Function({
  required String id,
  required String data,
  Value<int> rowid,
});
typedef $$CachedInspectionFormVersionsTableUpdateCompanionBuilder
    = CachedInspectionFormVersionsCompanion Function({
  Value<String> id,
  Value<String> data,
  Value<int> rowid,
});

class $$CachedInspectionFormVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormVersionsTable> {
  $$CachedInspectionFormVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnFilters(column));
}

class $$CachedInspectionFormVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormVersionsTable> {
  $$CachedInspectionFormVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data => $composableBuilder(
      column: $table.data, builder: (column) => ColumnOrderings(column));
}

class $$CachedInspectionFormVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedInspectionFormVersionsTable> {
  $$CachedInspectionFormVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);
}

class $$CachedInspectionFormVersionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CachedInspectionFormVersionsTable,
    CachedInspectionFormVersion,
    $$CachedInspectionFormVersionsTableFilterComposer,
    $$CachedInspectionFormVersionsTableOrderingComposer,
    $$CachedInspectionFormVersionsTableAnnotationComposer,
    $$CachedInspectionFormVersionsTableCreateCompanionBuilder,
    $$CachedInspectionFormVersionsTableUpdateCompanionBuilder,
    (
      CachedInspectionFormVersion,
      BaseReferences<_$AppDatabase, $CachedInspectionFormVersionsTable,
          CachedInspectionFormVersion>
    ),
    CachedInspectionFormVersion,
    PrefetchHooks Function()> {
  $$CachedInspectionFormVersionsTableTableManager(
      _$AppDatabase db, $CachedInspectionFormVersionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedInspectionFormVersionsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedInspectionFormVersionsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedInspectionFormVersionsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> data = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedInspectionFormVersionsCompanion(
            id: id,
            data: data,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String data,
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedInspectionFormVersionsCompanion.insert(
            id: id,
            data: data,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$CachedInspectionFormVersionsTable,
                        CachedInspectionFormVersion>(table),
                    BaseReferences<
                        _$AppDatabase,
                        $CachedInspectionFormVersionsTable,
                        CachedInspectionFormVersion>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedInspectionFormVersionsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $CachedInspectionFormVersionsTable,
        CachedInspectionFormVersion,
        $$CachedInspectionFormVersionsTableFilterComposer,
        $$CachedInspectionFormVersionsTableOrderingComposer,
        $$CachedInspectionFormVersionsTableAnnotationComposer,
        $$CachedInspectionFormVersionsTableCreateCompanionBuilder,
        $$CachedInspectionFormVersionsTableUpdateCompanionBuilder,
        (
          CachedInspectionFormVersion,
          BaseReferences<_$AppDatabase, $CachedInspectionFormVersionsTable,
              CachedInspectionFormVersion>
        ),
        CachedInspectionFormVersion,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxEntriesTableTableManager get outboxEntries =>
      $$OutboxEntriesTableTableManager(_db, _db.outboxEntries);
  $$CachedVehiclesTableTableManager get cachedVehicles =>
      $$CachedVehiclesTableTableManager(_db, _db.cachedVehicles);
  $$CachedInspectionFormsTableTableManager get cachedInspectionForms =>
      $$CachedInspectionFormsTableTableManager(_db, _db.cachedInspectionForms);
  $$CachedInspectionFormVersionsTableTableManager
      get cachedInspectionFormVersions =>
          $$CachedInspectionFormVersionsTableTableManager(
              _db, _db.cachedInspectionFormVersions);
}
