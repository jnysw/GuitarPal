// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PracticeSourcesTable extends PracticeSources
    with TableInfo<$PracticeSourcesTable, PracticeSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalUrlMeta = const VerificationMeta(
    'originalUrl',
  );
  @override
  late final GeneratedColumn<String> originalUrl = GeneratedColumn<String>(
    'original_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _canonicalUrlMeta = const VerificationMeta(
    'canonicalUrl',
  );
  @override
  late final GeneratedColumn<String> canonicalUrl = GeneratedColumn<String>(
    'canonical_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbnailUrlMeta = const VerificationMeta(
    'thumbnailUrl',
  );
  @override
  late final GeneratedColumn<String> thumbnailUrl = GeneratedColumn<String>(
    'thumbnail_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMillisecondsMeta =
      const VerificationMeta('durationMilliseconds');
  @override
  late final GeneratedColumn<int> durationMilliseconds = GeneratedColumn<int>(
    'duration_milliseconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    kind,
    originalUrl,
    canonicalUrl,
    externalId,
    title,
    thumbnailUrl,
    durationMilliseconds,
    note,
    syncStatus,
    completedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('original_url')) {
      context.handle(
        _originalUrlMeta,
        originalUrl.isAcceptableOrUnknown(
          data['original_url']!,
          _originalUrlMeta,
        ),
      );
    }
    if (data.containsKey('canonical_url')) {
      context.handle(
        _canonicalUrlMeta,
        canonicalUrl.isAcceptableOrUnknown(
          data['canonical_url']!,
          _canonicalUrlMeta,
        ),
      );
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('thumbnail_url')) {
      context.handle(
        _thumbnailUrlMeta,
        thumbnailUrl.isAcceptableOrUnknown(
          data['thumbnail_url']!,
          _thumbnailUrlMeta,
        ),
      );
    }
    if (data.containsKey('duration_milliseconds')) {
      context.handle(
        _durationMillisecondsMeta,
        durationMilliseconds.isAcceptableOrUnknown(
          data['duration_milliseconds']!,
          _durationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      originalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_url'],
      ),
      canonicalUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_url'],
      ),
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      thumbnailUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_url'],
      ),
      durationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_milliseconds'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PracticeSourcesTable createAlias(String alias) {
    return $PracticeSourcesTable(attachedDatabase, alias);
  }
}

class PracticeSource extends DataClass implements Insertable<PracticeSource> {
  final String id;
  final String platform;
  final String kind;
  final String? originalUrl;
  final String? canonicalUrl;
  final String? externalId;
  final String title;
  final String? thumbnailUrl;
  final int? durationMilliseconds;
  final String? note;
  final String syncStatus;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PracticeSource({
    required this.id,
    required this.platform,
    required this.kind,
    this.originalUrl,
    this.canonicalUrl,
    this.externalId,
    required this.title,
    this.thumbnailUrl,
    this.durationMilliseconds,
    this.note,
    required this.syncStatus,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['platform'] = Variable<String>(platform);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || originalUrl != null) {
      map['original_url'] = Variable<String>(originalUrl);
    }
    if (!nullToAbsent || canonicalUrl != null) {
      map['canonical_url'] = Variable<String>(canonicalUrl);
    }
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || thumbnailUrl != null) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl);
    }
    if (!nullToAbsent || durationMilliseconds != null) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PracticeSourcesCompanion toCompanion(bool nullToAbsent) {
    return PracticeSourcesCompanion(
      id: Value(id),
      platform: Value(platform),
      kind: Value(kind),
      originalUrl: originalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(originalUrl),
      canonicalUrl: canonicalUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(canonicalUrl),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      title: Value(title),
      thumbnailUrl: thumbnailUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailUrl),
      durationMilliseconds: durationMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMilliseconds),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      syncStatus: Value(syncStatus),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticeSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSource(
      id: serializer.fromJson<String>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      kind: serializer.fromJson<String>(json['kind']),
      originalUrl: serializer.fromJson<String?>(json['originalUrl']),
      canonicalUrl: serializer.fromJson<String?>(json['canonicalUrl']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      title: serializer.fromJson<String>(json['title']),
      thumbnailUrl: serializer.fromJson<String?>(json['thumbnailUrl']),
      durationMilliseconds: serializer.fromJson<int?>(
        json['durationMilliseconds'],
      ),
      note: serializer.fromJson<String?>(json['note']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platform': serializer.toJson<String>(platform),
      'kind': serializer.toJson<String>(kind),
      'originalUrl': serializer.toJson<String?>(originalUrl),
      'canonicalUrl': serializer.toJson<String?>(canonicalUrl),
      'externalId': serializer.toJson<String?>(externalId),
      'title': serializer.toJson<String>(title),
      'thumbnailUrl': serializer.toJson<String?>(thumbnailUrl),
      'durationMilliseconds': serializer.toJson<int?>(durationMilliseconds),
      'note': serializer.toJson<String?>(note),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PracticeSource copyWith({
    String? id,
    String? platform,
    String? kind,
    Value<String?> originalUrl = const Value.absent(),
    Value<String?> canonicalUrl = const Value.absent(),
    Value<String?> externalId = const Value.absent(),
    String? title,
    Value<String?> thumbnailUrl = const Value.absent(),
    Value<int?> durationMilliseconds = const Value.absent(),
    Value<String?> note = const Value.absent(),
    String? syncStatus,
    Value<DateTime?> completedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PracticeSource(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    kind: kind ?? this.kind,
    originalUrl: originalUrl.present ? originalUrl.value : this.originalUrl,
    canonicalUrl: canonicalUrl.present ? canonicalUrl.value : this.canonicalUrl,
    externalId: externalId.present ? externalId.value : this.externalId,
    title: title ?? this.title,
    thumbnailUrl: thumbnailUrl.present ? thumbnailUrl.value : this.thumbnailUrl,
    durationMilliseconds: durationMilliseconds.present
        ? durationMilliseconds.value
        : this.durationMilliseconds,
    note: note.present ? note.value : this.note,
    syncStatus: syncStatus ?? this.syncStatus,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PracticeSource copyWithCompanion(PracticeSourcesCompanion data) {
    return PracticeSource(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      kind: data.kind.present ? data.kind.value : this.kind,
      originalUrl: data.originalUrl.present
          ? data.originalUrl.value
          : this.originalUrl,
      canonicalUrl: data.canonicalUrl.present
          ? data.canonicalUrl.value
          : this.canonicalUrl,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      title: data.title.present ? data.title.value : this.title,
      thumbnailUrl: data.thumbnailUrl.present
          ? data.thumbnailUrl.value
          : this.thumbnailUrl,
      durationMilliseconds: data.durationMilliseconds.present
          ? data.durationMilliseconds.value
          : this.durationMilliseconds,
      note: data.note.present ? data.note.value : this.note,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSource(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('kind: $kind, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('note: $note, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    kind,
    originalUrl,
    canonicalUrl,
    externalId,
    title,
    thumbnailUrl,
    durationMilliseconds,
    note,
    syncStatus,
    completedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSource &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.kind == this.kind &&
          other.originalUrl == this.originalUrl &&
          other.canonicalUrl == this.canonicalUrl &&
          other.externalId == this.externalId &&
          other.title == this.title &&
          other.thumbnailUrl == this.thumbnailUrl &&
          other.durationMilliseconds == this.durationMilliseconds &&
          other.note == this.note &&
          other.syncStatus == this.syncStatus &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PracticeSourcesCompanion extends UpdateCompanion<PracticeSource> {
  final Value<String> id;
  final Value<String> platform;
  final Value<String> kind;
  final Value<String?> originalUrl;
  final Value<String?> canonicalUrl;
  final Value<String?> externalId;
  final Value<String> title;
  final Value<String?> thumbnailUrl;
  final Value<int?> durationMilliseconds;
  final Value<String?> note;
  final Value<String> syncStatus;
  final Value<DateTime?> completedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PracticeSourcesCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.kind = const Value.absent(),
    this.originalUrl = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.externalId = const Value.absent(),
    this.title = const Value.absent(),
    this.thumbnailUrl = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.note = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSourcesCompanion.insert({
    required String id,
    required String platform,
    required String kind,
    this.originalUrl = const Value.absent(),
    this.canonicalUrl = const Value.absent(),
    this.externalId = const Value.absent(),
    required String title,
    this.thumbnailUrl = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.note = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.completedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       platform = Value(platform),
       kind = Value(kind),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PracticeSource> custom({
    Expression<String>? id,
    Expression<String>? platform,
    Expression<String>? kind,
    Expression<String>? originalUrl,
    Expression<String>? canonicalUrl,
    Expression<String>? externalId,
    Expression<String>? title,
    Expression<String>? thumbnailUrl,
    Expression<int>? durationMilliseconds,
    Expression<String>? note,
    Expression<String>? syncStatus,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (kind != null) 'kind': kind,
      if (originalUrl != null) 'original_url': originalUrl,
      if (canonicalUrl != null) 'canonical_url': canonicalUrl,
      if (externalId != null) 'external_id': externalId,
      if (title != null) 'title': title,
      if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
      if (durationMilliseconds != null)
        'duration_milliseconds': durationMilliseconds,
      if (note != null) 'note': note,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? platform,
    Value<String>? kind,
    Value<String?>? originalUrl,
    Value<String?>? canonicalUrl,
    Value<String?>? externalId,
    Value<String>? title,
    Value<String?>? thumbnailUrl,
    Value<int?>? durationMilliseconds,
    Value<String?>? note,
    Value<String>? syncStatus,
    Value<DateTime?>? completedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PracticeSourcesCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      kind: kind ?? this.kind,
      originalUrl: originalUrl ?? this.originalUrl,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      externalId: externalId ?? this.externalId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      note: note ?? this.note,
      syncStatus: syncStatus ?? this.syncStatus,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (originalUrl.present) {
      map['original_url'] = Variable<String>(originalUrl.value);
    }
    if (canonicalUrl.present) {
      map['canonical_url'] = Variable<String>(canonicalUrl.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (thumbnailUrl.present) {
      map['thumbnail_url'] = Variable<String>(thumbnailUrl.value);
    }
    if (durationMilliseconds.present) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSourcesCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('kind: $kind, ')
          ..write('originalUrl: $originalUrl, ')
          ..write('canonicalUrl: $canonicalUrl, ')
          ..write('externalId: $externalId, ')
          ..write('title: $title, ')
          ..write('thumbnailUrl: $thumbnailUrl, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('note: $note, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeSegmentsTable extends PracticeSegments
    with TableInfo<$PracticeSegmentsTable, PracticeSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMillisecondsMeta = const VerificationMeta(
    'startMilliseconds',
  );
  @override
  late final GeneratedColumn<int> startMilliseconds = GeneratedColumn<int>(
    'start_milliseconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMillisecondsMeta = const VerificationMeta(
    'endMilliseconds',
  );
  @override
  late final GeneratedColumn<int> endMilliseconds = GeneratedColumn<int>(
    'end_milliseconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preferredSpeedMeta = const VerificationMeta(
    'preferredSpeed',
  );
  @override
  late final GeneratedColumn<double> preferredSpeed = GeneratedColumn<double>(
    'preferred_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    title,
    startMilliseconds,
    endMilliseconds,
    note,
    preferredSpeed,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('start_milliseconds')) {
      context.handle(
        _startMillisecondsMeta,
        startMilliseconds.isAcceptableOrUnknown(
          data['start_milliseconds']!,
          _startMillisecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startMillisecondsMeta);
    }
    if (data.containsKey('end_milliseconds')) {
      context.handle(
        _endMillisecondsMeta,
        endMilliseconds.isAcceptableOrUnknown(
          data['end_milliseconds']!,
          _endMillisecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_endMillisecondsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('preferred_speed')) {
      context.handle(
        _preferredSpeedMeta,
        preferredSpeed.isAcceptableOrUnknown(
          data['preferred_speed']!,
          _preferredSpeedMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      startMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_milliseconds'],
      )!,
      endMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_milliseconds'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      preferredSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}preferred_speed'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PracticeSegmentsTable createAlias(String alias) {
    return $PracticeSegmentsTable(attachedDatabase, alias);
  }
}

class PracticeSegment extends DataClass implements Insertable<PracticeSegment> {
  final String id;
  final String sourceId;
  final String title;
  final int startMilliseconds;
  final int endMilliseconds;
  final String? note;
  final double preferredSpeed;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PracticeSegment({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.startMilliseconds,
    required this.endMilliseconds,
    this.note,
    required this.preferredSpeed,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    map['title'] = Variable<String>(title);
    map['start_milliseconds'] = Variable<int>(startMilliseconds);
    map['end_milliseconds'] = Variable<int>(endMilliseconds);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['preferred_speed'] = Variable<double>(preferredSpeed);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PracticeSegmentsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSegmentsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      title: Value(title),
      startMilliseconds: Value(startMilliseconds),
      endMilliseconds: Value(endMilliseconds),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      preferredSpeed: Value(preferredSpeed),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticeSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSegment(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      title: serializer.fromJson<String>(json['title']),
      startMilliseconds: serializer.fromJson<int>(json['startMilliseconds']),
      endMilliseconds: serializer.fromJson<int>(json['endMilliseconds']),
      note: serializer.fromJson<String?>(json['note']),
      preferredSpeed: serializer.fromJson<double>(json['preferredSpeed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'title': serializer.toJson<String>(title),
      'startMilliseconds': serializer.toJson<int>(startMilliseconds),
      'endMilliseconds': serializer.toJson<int>(endMilliseconds),
      'note': serializer.toJson<String?>(note),
      'preferredSpeed': serializer.toJson<double>(preferredSpeed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PracticeSegment copyWith({
    String? id,
    String? sourceId,
    String? title,
    int? startMilliseconds,
    int? endMilliseconds,
    Value<String?> note = const Value.absent(),
    double? preferredSpeed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PracticeSegment(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    title: title ?? this.title,
    startMilliseconds: startMilliseconds ?? this.startMilliseconds,
    endMilliseconds: endMilliseconds ?? this.endMilliseconds,
    note: note.present ? note.value : this.note,
    preferredSpeed: preferredSpeed ?? this.preferredSpeed,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PracticeSegment copyWithCompanion(PracticeSegmentsCompanion data) {
    return PracticeSegment(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      title: data.title.present ? data.title.value : this.title,
      startMilliseconds: data.startMilliseconds.present
          ? data.startMilliseconds.value
          : this.startMilliseconds,
      endMilliseconds: data.endMilliseconds.present
          ? data.endMilliseconds.value
          : this.endMilliseconds,
      note: data.note.present ? data.note.value : this.note,
      preferredSpeed: data.preferredSpeed.present
          ? data.preferredSpeed.value
          : this.preferredSpeed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSegment(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('startMilliseconds: $startMilliseconds, ')
          ..write('endMilliseconds: $endMilliseconds, ')
          ..write('note: $note, ')
          ..write('preferredSpeed: $preferredSpeed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    title,
    startMilliseconds,
    endMilliseconds,
    note,
    preferredSpeed,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSegment &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.title == this.title &&
          other.startMilliseconds == this.startMilliseconds &&
          other.endMilliseconds == this.endMilliseconds &&
          other.note == this.note &&
          other.preferredSpeed == this.preferredSpeed &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PracticeSegmentsCompanion extends UpdateCompanion<PracticeSegment> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String> title;
  final Value<int> startMilliseconds;
  final Value<int> endMilliseconds;
  final Value<String?> note;
  final Value<double> preferredSpeed;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PracticeSegmentsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.title = const Value.absent(),
    this.startMilliseconds = const Value.absent(),
    this.endMilliseconds = const Value.absent(),
    this.note = const Value.absent(),
    this.preferredSpeed = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSegmentsCompanion.insert({
    required String id,
    required String sourceId,
    required String title,
    required int startMilliseconds,
    required int endMilliseconds,
    this.note = const Value.absent(),
    this.preferredSpeed = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       title = Value(title),
       startMilliseconds = Value(startMilliseconds),
       endMilliseconds = Value(endMilliseconds),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PracticeSegment> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? title,
    Expression<int>? startMilliseconds,
    Expression<int>? endMilliseconds,
    Expression<String>? note,
    Expression<double>? preferredSpeed,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (title != null) 'title': title,
      if (startMilliseconds != null) 'start_milliseconds': startMilliseconds,
      if (endMilliseconds != null) 'end_milliseconds': endMilliseconds,
      if (note != null) 'note': note,
      if (preferredSpeed != null) 'preferred_speed': preferredSpeed,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String>? title,
    Value<int>? startMilliseconds,
    Value<int>? endMilliseconds,
    Value<String?>? note,
    Value<double>? preferredSpeed,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PracticeSegmentsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      startMilliseconds: startMilliseconds ?? this.startMilliseconds,
      endMilliseconds: endMilliseconds ?? this.endMilliseconds,
      note: note ?? this.note,
      preferredSpeed: preferredSpeed ?? this.preferredSpeed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (startMilliseconds.present) {
      map['start_milliseconds'] = Variable<int>(startMilliseconds.value);
    }
    if (endMilliseconds.present) {
      map['end_milliseconds'] = Variable<int>(endMilliseconds.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (preferredSpeed.present) {
      map['preferred_speed'] = Variable<double>(preferredSpeed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('title: $title, ')
          ..write('startMilliseconds: $startMilliseconds, ')
          ..write('endMilliseconds: $endMilliseconds, ')
          ..write('note: $note, ')
          ..write('preferredSpeed: $preferredSpeed, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticePlansTable extends PracticePlans
    with TableInfo<$PracticePlansTable, PracticePlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticePlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_sources (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_segments (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<String> goalType = GeneratedColumn<String>(
    'goal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetLoopsMeta = const VerificationMeta(
    'targetLoops',
  );
  @override
  late final GeneratedColumn<int> targetLoops = GeneratedColumn<int>(
    'target_loops',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetDurationMillisecondsMeta =
      const VerificationMeta('targetDurationMilliseconds');
  @override
  late final GeneratedColumn<int> targetDurationMilliseconds =
      GeneratedColumn<int>(
        'target_duration_milliseconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _startDayMeta = const VerificationMeta(
    'startDay',
  );
  @override
  late final GeneratedColumn<int> startDay = GeneratedColumn<int>(
    'start_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDayMeta = const VerificationMeta('endDay');
  @override
  late final GeneratedColumn<int> endDay = GeneratedColumn<int>(
    'end_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repeatWeekdayMaskMeta = const VerificationMeta(
    'repeatWeekdayMask',
  );
  @override
  late final GeneratedColumn<int> repeatWeekdayMask = GeneratedColumn<int>(
    'repeat_weekday_mask',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reminderMinutesSinceMidnightMeta =
      const VerificationMeta('reminderMinutesSinceMidnight');
  @override
  late final GeneratedColumn<int> reminderMinutesSinceMidnight =
      GeneratedColumn<int>(
        'reminder_minutes_since_midnight',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sourceId,
    segmentId,
    goalType,
    targetLoops,
    targetDurationMilliseconds,
    startDay,
    endDay,
    repeatWeekdayMask,
    reminderMinutesSinceMidnight,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticePlan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_goalTypeMeta);
    }
    if (data.containsKey('target_loops')) {
      context.handle(
        _targetLoopsMeta,
        targetLoops.isAcceptableOrUnknown(
          data['target_loops']!,
          _targetLoopsMeta,
        ),
      );
    }
    if (data.containsKey('target_duration_milliseconds')) {
      context.handle(
        _targetDurationMillisecondsMeta,
        targetDurationMilliseconds.isAcceptableOrUnknown(
          data['target_duration_milliseconds']!,
          _targetDurationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('start_day')) {
      context.handle(
        _startDayMeta,
        startDay.isAcceptableOrUnknown(data['start_day']!, _startDayMeta),
      );
    } else if (isInserting) {
      context.missing(_startDayMeta);
    }
    if (data.containsKey('end_day')) {
      context.handle(
        _endDayMeta,
        endDay.isAcceptableOrUnknown(data['end_day']!, _endDayMeta),
      );
    } else if (isInserting) {
      context.missing(_endDayMeta);
    }
    if (data.containsKey('repeat_weekday_mask')) {
      context.handle(
        _repeatWeekdayMaskMeta,
        repeatWeekdayMask.isAcceptableOrUnknown(
          data['repeat_weekday_mask']!,
          _repeatWeekdayMaskMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repeatWeekdayMaskMeta);
    }
    if (data.containsKey('reminder_minutes_since_midnight')) {
      context.handle(
        _reminderMinutesSinceMidnightMeta,
        reminderMinutesSinceMidnight.isAcceptableOrUnknown(
          data['reminder_minutes_since_midnight']!,
          _reminderMinutesSinceMidnightMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticePlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticePlan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      goalType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_type'],
      )!,
      targetLoops: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_loops'],
      ),
      targetDurationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_duration_milliseconds'],
      ),
      startDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_day'],
      )!,
      endDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_day'],
      )!,
      repeatWeekdayMask: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_weekday_mask'],
      )!,
      reminderMinutesSinceMidnight: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_minutes_since_midnight'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PracticePlansTable createAlias(String alias) {
    return $PracticePlansTable(attachedDatabase, alias);
  }
}

class PracticePlan extends DataClass implements Insertable<PracticePlan> {
  final String id;
  final String name;
  final String sourceId;
  final String? segmentId;
  final String goalType;
  final int? targetLoops;
  final int? targetDurationMilliseconds;
  final int startDay;
  final int endDay;
  final int repeatWeekdayMask;
  final int? reminderMinutesSinceMidnight;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PracticePlan({
    required this.id,
    required this.name,
    required this.sourceId,
    this.segmentId,
    required this.goalType,
    this.targetLoops,
    this.targetDurationMilliseconds,
    required this.startDay,
    required this.endDay,
    required this.repeatWeekdayMask,
    this.reminderMinutesSinceMidnight,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    map['goal_type'] = Variable<String>(goalType);
    if (!nullToAbsent || targetLoops != null) {
      map['target_loops'] = Variable<int>(targetLoops);
    }
    if (!nullToAbsent || targetDurationMilliseconds != null) {
      map['target_duration_milliseconds'] = Variable<int>(
        targetDurationMilliseconds,
      );
    }
    map['start_day'] = Variable<int>(startDay);
    map['end_day'] = Variable<int>(endDay);
    map['repeat_weekday_mask'] = Variable<int>(repeatWeekdayMask);
    if (!nullToAbsent || reminderMinutesSinceMidnight != null) {
      map['reminder_minutes_since_midnight'] = Variable<int>(
        reminderMinutesSinceMidnight,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PracticePlansCompanion toCompanion(bool nullToAbsent) {
    return PracticePlansCompanion(
      id: Value(id),
      name: Value(name),
      sourceId: Value(sourceId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      goalType: Value(goalType),
      targetLoops: targetLoops == null && nullToAbsent
          ? const Value.absent()
          : Value(targetLoops),
      targetDurationMilliseconds:
          targetDurationMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDurationMilliseconds),
      startDay: Value(startDay),
      endDay: Value(endDay),
      repeatWeekdayMask: Value(repeatWeekdayMask),
      reminderMinutesSinceMidnight:
          reminderMinutesSinceMidnight == null && nullToAbsent
          ? const Value.absent()
          : Value(reminderMinutesSinceMidnight),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticePlan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticePlan(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      goalType: serializer.fromJson<String>(json['goalType']),
      targetLoops: serializer.fromJson<int?>(json['targetLoops']),
      targetDurationMilliseconds: serializer.fromJson<int?>(
        json['targetDurationMilliseconds'],
      ),
      startDay: serializer.fromJson<int>(json['startDay']),
      endDay: serializer.fromJson<int>(json['endDay']),
      repeatWeekdayMask: serializer.fromJson<int>(json['repeatWeekdayMask']),
      reminderMinutesSinceMidnight: serializer.fromJson<int?>(
        json['reminderMinutesSinceMidnight'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sourceId': serializer.toJson<String>(sourceId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'goalType': serializer.toJson<String>(goalType),
      'targetLoops': serializer.toJson<int?>(targetLoops),
      'targetDurationMilliseconds': serializer.toJson<int?>(
        targetDurationMilliseconds,
      ),
      'startDay': serializer.toJson<int>(startDay),
      'endDay': serializer.toJson<int>(endDay),
      'repeatWeekdayMask': serializer.toJson<int>(repeatWeekdayMask),
      'reminderMinutesSinceMidnight': serializer.toJson<int?>(
        reminderMinutesSinceMidnight,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PracticePlan copyWith({
    String? id,
    String? name,
    String? sourceId,
    Value<String?> segmentId = const Value.absent(),
    String? goalType,
    Value<int?> targetLoops = const Value.absent(),
    Value<int?> targetDurationMilliseconds = const Value.absent(),
    int? startDay,
    int? endDay,
    int? repeatWeekdayMask,
    Value<int?> reminderMinutesSinceMidnight = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => PracticePlan(
    id: id ?? this.id,
    name: name ?? this.name,
    sourceId: sourceId ?? this.sourceId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    goalType: goalType ?? this.goalType,
    targetLoops: targetLoops.present ? targetLoops.value : this.targetLoops,
    targetDurationMilliseconds: targetDurationMilliseconds.present
        ? targetDurationMilliseconds.value
        : this.targetDurationMilliseconds,
    startDay: startDay ?? this.startDay,
    endDay: endDay ?? this.endDay,
    repeatWeekdayMask: repeatWeekdayMask ?? this.repeatWeekdayMask,
    reminderMinutesSinceMidnight: reminderMinutesSinceMidnight.present
        ? reminderMinutesSinceMidnight.value
        : this.reminderMinutesSinceMidnight,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PracticePlan copyWithCompanion(PracticePlansCompanion data) {
    return PracticePlan(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      targetLoops: data.targetLoops.present
          ? data.targetLoops.value
          : this.targetLoops,
      targetDurationMilliseconds: data.targetDurationMilliseconds.present
          ? data.targetDurationMilliseconds.value
          : this.targetDurationMilliseconds,
      startDay: data.startDay.present ? data.startDay.value : this.startDay,
      endDay: data.endDay.present ? data.endDay.value : this.endDay,
      repeatWeekdayMask: data.repeatWeekdayMask.present
          ? data.repeatWeekdayMask.value
          : this.repeatWeekdayMask,
      reminderMinutesSinceMidnight: data.reminderMinutesSinceMidnight.present
          ? data.reminderMinutesSinceMidnight.value
          : this.reminderMinutesSinceMidnight,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticePlan(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('goalType: $goalType, ')
          ..write('targetLoops: $targetLoops, ')
          ..write('targetDurationMilliseconds: $targetDurationMilliseconds, ')
          ..write('startDay: $startDay, ')
          ..write('endDay: $endDay, ')
          ..write('repeatWeekdayMask: $repeatWeekdayMask, ')
          ..write(
            'reminderMinutesSinceMidnight: $reminderMinutesSinceMidnight, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sourceId,
    segmentId,
    goalType,
    targetLoops,
    targetDurationMilliseconds,
    startDay,
    endDay,
    repeatWeekdayMask,
    reminderMinutesSinceMidnight,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticePlan &&
          other.id == this.id &&
          other.name == this.name &&
          other.sourceId == this.sourceId &&
          other.segmentId == this.segmentId &&
          other.goalType == this.goalType &&
          other.targetLoops == this.targetLoops &&
          other.targetDurationMilliseconds == this.targetDurationMilliseconds &&
          other.startDay == this.startDay &&
          other.endDay == this.endDay &&
          other.repeatWeekdayMask == this.repeatWeekdayMask &&
          other.reminderMinutesSinceMidnight ==
              this.reminderMinutesSinceMidnight &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PracticePlansCompanion extends UpdateCompanion<PracticePlan> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> sourceId;
  final Value<String?> segmentId;
  final Value<String> goalType;
  final Value<int?> targetLoops;
  final Value<int?> targetDurationMilliseconds;
  final Value<int> startDay;
  final Value<int> endDay;
  final Value<int> repeatWeekdayMask;
  final Value<int?> reminderMinutesSinceMidnight;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PracticePlansCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.goalType = const Value.absent(),
    this.targetLoops = const Value.absent(),
    this.targetDurationMilliseconds = const Value.absent(),
    this.startDay = const Value.absent(),
    this.endDay = const Value.absent(),
    this.repeatWeekdayMask = const Value.absent(),
    this.reminderMinutesSinceMidnight = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticePlansCompanion.insert({
    required String id,
    required String name,
    required String sourceId,
    this.segmentId = const Value.absent(),
    required String goalType,
    this.targetLoops = const Value.absent(),
    this.targetDurationMilliseconds = const Value.absent(),
    required int startDay,
    required int endDay,
    required int repeatWeekdayMask,
    this.reminderMinutesSinceMidnight = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       sourceId = Value(sourceId),
       goalType = Value(goalType),
       startDay = Value(startDay),
       endDay = Value(endDay),
       repeatWeekdayMask = Value(repeatWeekdayMask),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<PracticePlan> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sourceId,
    Expression<String>? segmentId,
    Expression<String>? goalType,
    Expression<int>? targetLoops,
    Expression<int>? targetDurationMilliseconds,
    Expression<int>? startDay,
    Expression<int>? endDay,
    Expression<int>? repeatWeekdayMask,
    Expression<int>? reminderMinutesSinceMidnight,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sourceId != null) 'source_id': sourceId,
      if (segmentId != null) 'segment_id': segmentId,
      if (goalType != null) 'goal_type': goalType,
      if (targetLoops != null) 'target_loops': targetLoops,
      if (targetDurationMilliseconds != null)
        'target_duration_milliseconds': targetDurationMilliseconds,
      if (startDay != null) 'start_day': startDay,
      if (endDay != null) 'end_day': endDay,
      if (repeatWeekdayMask != null) 'repeat_weekday_mask': repeatWeekdayMask,
      if (reminderMinutesSinceMidnight != null)
        'reminder_minutes_since_midnight': reminderMinutesSinceMidnight,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticePlansCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? sourceId,
    Value<String?>? segmentId,
    Value<String>? goalType,
    Value<int?>? targetLoops,
    Value<int?>? targetDurationMilliseconds,
    Value<int>? startDay,
    Value<int>? endDay,
    Value<int>? repeatWeekdayMask,
    Value<int?>? reminderMinutesSinceMidnight,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PracticePlansCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sourceId: sourceId ?? this.sourceId,
      segmentId: segmentId ?? this.segmentId,
      goalType: goalType ?? this.goalType,
      targetLoops: targetLoops ?? this.targetLoops,
      targetDurationMilliseconds:
          targetDurationMilliseconds ?? this.targetDurationMilliseconds,
      startDay: startDay ?? this.startDay,
      endDay: endDay ?? this.endDay,
      repeatWeekdayMask: repeatWeekdayMask ?? this.repeatWeekdayMask,
      reminderMinutesSinceMidnight:
          reminderMinutesSinceMidnight ?? this.reminderMinutesSinceMidnight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (goalType.present) {
      map['goal_type'] = Variable<String>(goalType.value);
    }
    if (targetLoops.present) {
      map['target_loops'] = Variable<int>(targetLoops.value);
    }
    if (targetDurationMilliseconds.present) {
      map['target_duration_milliseconds'] = Variable<int>(
        targetDurationMilliseconds.value,
      );
    }
    if (startDay.present) {
      map['start_day'] = Variable<int>(startDay.value);
    }
    if (endDay.present) {
      map['end_day'] = Variable<int>(endDay.value);
    }
    if (repeatWeekdayMask.present) {
      map['repeat_weekday_mask'] = Variable<int>(repeatWeekdayMask.value);
    }
    if (reminderMinutesSinceMidnight.present) {
      map['reminder_minutes_since_midnight'] = Variable<int>(
        reminderMinutesSinceMidnight.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticePlansCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('goalType: $goalType, ')
          ..write('targetLoops: $targetLoops, ')
          ..write('targetDurationMilliseconds: $targetDurationMilliseconds, ')
          ..write('startDay: $startDay, ')
          ..write('endDay: $endDay, ')
          ..write('repeatWeekdayMask: $repeatWeekdayMask, ')
          ..write(
            'reminderMinutesSinceMidnight: $reminderMinutesSinceMidnight, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES practice_plans (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _practiceDayMeta = const VerificationMeta(
    'practiceDay',
  );
  @override
  late final GeneratedColumn<int> practiceDay = GeneratedColumn<int>(
    'practice_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeDurationMillisecondsMeta =
      const VerificationMeta('activeDurationMilliseconds');
  @override
  late final GeneratedColumn<int> activeDurationMilliseconds =
      GeneratedColumn<int>(
        'active_duration_milliseconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _loopCountMeta = const VerificationMeta(
    'loopCount',
  );
  @override
  late final GeneratedColumn<int> loopCount = GeneratedColumn<int>(
    'loop_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    sourceId,
    segmentId,
    practiceDay,
    startedAt,
    endedAt,
    activeDurationMilliseconds,
    loopCount,
    completed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('practice_day')) {
      context.handle(
        _practiceDayMeta,
        practiceDay.isAcceptableOrUnknown(
          data['practice_day']!,
          _practiceDayMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_practiceDayMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('active_duration_milliseconds')) {
      context.handle(
        _activeDurationMillisecondsMeta,
        activeDurationMilliseconds.isAcceptableOrUnknown(
          data['active_duration_milliseconds']!,
          _activeDurationMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('loop_count')) {
      context.handle(
        _loopCountMeta,
        loopCount.isAcceptableOrUnknown(data['loop_count']!, _loopCountMeta),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      practiceDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}practice_day'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      activeDurationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}active_duration_milliseconds'],
      )!,
      loopCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loop_count'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final String id;
  final String? planId;
  final String sourceId;
  final String? segmentId;
  final int practiceDay;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int activeDurationMilliseconds;
  final int loopCount;
  final bool completed;
  const PracticeSession({
    required this.id,
    this.planId,
    required this.sourceId,
    this.segmentId,
    required this.practiceDay,
    required this.startedAt,
    this.endedAt,
    required this.activeDurationMilliseconds,
    required this.loopCount,
    required this.completed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    map['practice_day'] = Variable<int>(practiceDay);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['active_duration_milliseconds'] = Variable<int>(
      activeDurationMilliseconds,
    );
    map['loop_count'] = Variable<int>(loopCount);
    map['completed'] = Variable<bool>(completed);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      planId: planId == null && nullToAbsent
          ? const Value.absent()
          : Value(planId),
      sourceId: Value(sourceId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      practiceDay: Value(practiceDay),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      activeDurationMilliseconds: Value(activeDurationMilliseconds),
      loopCount: Value(loopCount),
      completed: Value(completed),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String?>(json['planId']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      practiceDay: serializer.fromJson<int>(json['practiceDay']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      activeDurationMilliseconds: serializer.fromJson<int>(
        json['activeDurationMilliseconds'],
      ),
      loopCount: serializer.fromJson<int>(json['loopCount']),
      completed: serializer.fromJson<bool>(json['completed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planId': serializer.toJson<String?>(planId),
      'sourceId': serializer.toJson<String>(sourceId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'practiceDay': serializer.toJson<int>(practiceDay),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'activeDurationMilliseconds': serializer.toJson<int>(
        activeDurationMilliseconds,
      ),
      'loopCount': serializer.toJson<int>(loopCount),
      'completed': serializer.toJson<bool>(completed),
    };
  }

  PracticeSession copyWith({
    String? id,
    Value<String?> planId = const Value.absent(),
    String? sourceId,
    Value<String?> segmentId = const Value.absent(),
    int? practiceDay,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? activeDurationMilliseconds,
    int? loopCount,
    bool? completed,
  }) => PracticeSession(
    id: id ?? this.id,
    planId: planId.present ? planId.value : this.planId,
    sourceId: sourceId ?? this.sourceId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    practiceDay: practiceDay ?? this.practiceDay,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    activeDurationMilliseconds:
        activeDurationMilliseconds ?? this.activeDurationMilliseconds,
    loopCount: loopCount ?? this.loopCount,
    completed: completed ?? this.completed,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      practiceDay: data.practiceDay.present
          ? data.practiceDay.value
          : this.practiceDay,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      activeDurationMilliseconds: data.activeDurationMilliseconds.present
          ? data.activeDurationMilliseconds.value
          : this.activeDurationMilliseconds,
      loopCount: data.loopCount.present ? data.loopCount.value : this.loopCount,
      completed: data.completed.present ? data.completed.value : this.completed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('practiceDay: $practiceDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('activeDurationMilliseconds: $activeDurationMilliseconds, ')
          ..write('loopCount: $loopCount, ')
          ..write('completed: $completed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    sourceId,
    segmentId,
    practiceDay,
    startedAt,
    endedAt,
    activeDurationMilliseconds,
    loopCount,
    completed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.sourceId == this.sourceId &&
          other.segmentId == this.segmentId &&
          other.practiceDay == this.practiceDay &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.activeDurationMilliseconds == this.activeDurationMilliseconds &&
          other.loopCount == this.loopCount &&
          other.completed == this.completed);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<String> id;
  final Value<String?> planId;
  final Value<String> sourceId;
  final Value<String?> segmentId;
  final Value<int> practiceDay;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> activeDurationMilliseconds;
  final Value<int> loopCount;
  final Value<bool> completed;
  final Value<int> rowid;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.practiceDay = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.activeDurationMilliseconds = const Value.absent(),
    this.loopCount = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    required String id,
    this.planId = const Value.absent(),
    required String sourceId,
    this.segmentId = const Value.absent(),
    required int practiceDay,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.activeDurationMilliseconds = const Value.absent(),
    this.loopCount = const Value.absent(),
    this.completed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       practiceDay = Value(practiceDay),
       startedAt = Value(startedAt);
  static Insertable<PracticeSession> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? sourceId,
    Expression<String>? segmentId,
    Expression<int>? practiceDay,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? activeDurationMilliseconds,
    Expression<int>? loopCount,
    Expression<bool>? completed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (sourceId != null) 'source_id': sourceId,
      if (segmentId != null) 'segment_id': segmentId,
      if (practiceDay != null) 'practice_day': practiceDay,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (activeDurationMilliseconds != null)
        'active_duration_milliseconds': activeDurationMilliseconds,
      if (loopCount != null) 'loop_count': loopCount,
      if (completed != null) 'completed': completed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? planId,
    Value<String>? sourceId,
    Value<String?>? segmentId,
    Value<int>? practiceDay,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? activeDurationMilliseconds,
    Value<int>? loopCount,
    Value<bool>? completed,
    Value<int>? rowid,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      sourceId: sourceId ?? this.sourceId,
      segmentId: segmentId ?? this.segmentId,
      practiceDay: practiceDay ?? this.practiceDay,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      activeDurationMilliseconds:
          activeDurationMilliseconds ?? this.activeDurationMilliseconds,
      loopCount: loopCount ?? this.loopCount,
      completed: completed ?? this.completed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (practiceDay.present) {
      map['practice_day'] = Variable<int>(practiceDay.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (activeDurationMilliseconds.present) {
      map['active_duration_milliseconds'] = Variable<int>(
        activeDurationMilliseconds.value,
      );
    }
    if (loopCount.present) {
      map['loop_count'] = Variable<int>(loopCount.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('practiceDay: $practiceDay, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('activeDurationMilliseconds: $activeDurationMilliseconds, ')
          ..write('loopCount: $loopCount, ')
          ..write('completed: $completed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PracticeRecordingsTable extends PracticeRecordings
    with TableInfo<$PracticeRecordingsTable, PracticeRecording> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeRecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _segmentIdMeta = const VerificationMeta(
    'segmentId',
  );
  @override
  late final GeneratedColumn<String> segmentId = GeneratedColumn<String>(
    'segment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _durationMillisecondsMeta =
      const VerificationMeta('durationMilliseconds');
  @override
  late final GeneratedColumn<int> durationMilliseconds = GeneratedColumn<int>(
    'duration_milliseconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceStartMillisecondsMeta =
      const VerificationMeta('referenceStartMilliseconds');
  @override
  late final GeneratedColumn<int> referenceStartMilliseconds =
      GeneratedColumn<int>(
        'reference_start_milliseconds',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _referenceEndMillisecondsMeta =
      const VerificationMeta('referenceEndMilliseconds');
  @override
  late final GeneratedColumn<int> referenceEndMilliseconds =
      GeneratedColumn<int>(
        'reference_end_milliseconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _referenceSpeedMeta = const VerificationMeta(
    'referenceSpeed',
  );
  @override
  late final GeneratedColumn<double> referenceSpeed = GeneratedColumn<double>(
    'reference_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceId,
    segmentId,
    planId,
    sessionId,
    kind,
    filePath,
    durationMilliseconds,
    referenceStartMilliseconds,
    referenceEndMilliseconds,
    referenceSpeed,
    title,
    note,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_recordings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeRecording> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('segment_id')) {
      context.handle(
        _segmentIdMeta,
        segmentId.isAcceptableOrUnknown(data['segment_id']!, _segmentIdMeta),
      );
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('duration_milliseconds')) {
      context.handle(
        _durationMillisecondsMeta,
        durationMilliseconds.isAcceptableOrUnknown(
          data['duration_milliseconds']!,
          _durationMillisecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_durationMillisecondsMeta);
    }
    if (data.containsKey('reference_start_milliseconds')) {
      context.handle(
        _referenceStartMillisecondsMeta,
        referenceStartMilliseconds.isAcceptableOrUnknown(
          data['reference_start_milliseconds']!,
          _referenceStartMillisecondsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceStartMillisecondsMeta);
    }
    if (data.containsKey('reference_end_milliseconds')) {
      context.handle(
        _referenceEndMillisecondsMeta,
        referenceEndMilliseconds.isAcceptableOrUnknown(
          data['reference_end_milliseconds']!,
          _referenceEndMillisecondsMeta,
        ),
      );
    }
    if (data.containsKey('reference_speed')) {
      context.handle(
        _referenceSpeedMeta,
        referenceSpeed.isAcceptableOrUnknown(
          data['reference_speed']!,
          _referenceSpeedMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeRecording map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeRecording(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      segmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_id'],
      ),
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      ),
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      durationMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_milliseconds'],
      )!,
      referenceStartMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_start_milliseconds'],
      )!,
      referenceEndMilliseconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_end_milliseconds'],
      ),
      referenceSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}reference_speed'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $PracticeRecordingsTable createAlias(String alias) {
    return $PracticeRecordingsTable(attachedDatabase, alias);
  }
}

class PracticeRecording extends DataClass
    implements Insertable<PracticeRecording> {
  final String id;
  final String sourceId;
  final String? segmentId;
  final String? planId;
  final String? sessionId;
  final String kind;
  final String filePath;
  final int durationMilliseconds;
  final int referenceStartMilliseconds;
  final int? referenceEndMilliseconds;
  final double referenceSpeed;
  final String title;
  final String? note;
  final DateTime recordedAt;
  const PracticeRecording({
    required this.id,
    required this.sourceId,
    this.segmentId,
    this.planId,
    this.sessionId,
    required this.kind,
    required this.filePath,
    required this.durationMilliseconds,
    required this.referenceStartMilliseconds,
    this.referenceEndMilliseconds,
    required this.referenceSpeed,
    required this.title,
    this.note,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || segmentId != null) {
      map['segment_id'] = Variable<String>(segmentId);
    }
    if (!nullToAbsent || planId != null) {
      map['plan_id'] = Variable<String>(planId);
    }
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['kind'] = Variable<String>(kind);
    map['file_path'] = Variable<String>(filePath);
    map['duration_milliseconds'] = Variable<int>(durationMilliseconds);
    map['reference_start_milliseconds'] = Variable<int>(
      referenceStartMilliseconds,
    );
    if (!nullToAbsent || referenceEndMilliseconds != null) {
      map['reference_end_milliseconds'] = Variable<int>(
        referenceEndMilliseconds,
      );
    }
    map['reference_speed'] = Variable<double>(referenceSpeed);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  PracticeRecordingsCompanion toCompanion(bool nullToAbsent) {
    return PracticeRecordingsCompanion(
      id: Value(id),
      sourceId: Value(sourceId),
      segmentId: segmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(segmentId),
      planId: planId == null && nullToAbsent
          ? const Value.absent()
          : Value(planId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      kind: Value(kind),
      filePath: Value(filePath),
      durationMilliseconds: Value(durationMilliseconds),
      referenceStartMilliseconds: Value(referenceStartMilliseconds),
      referenceEndMilliseconds: referenceEndMilliseconds == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceEndMilliseconds),
      referenceSpeed: Value(referenceSpeed),
      title: Value(title),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      recordedAt: Value(recordedAt),
    );
  }

  factory PracticeRecording.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeRecording(
      id: serializer.fromJson<String>(json['id']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      segmentId: serializer.fromJson<String?>(json['segmentId']),
      planId: serializer.fromJson<String?>(json['planId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      kind: serializer.fromJson<String>(json['kind']),
      filePath: serializer.fromJson<String>(json['filePath']),
      durationMilliseconds: serializer.fromJson<int>(
        json['durationMilliseconds'],
      ),
      referenceStartMilliseconds: serializer.fromJson<int>(
        json['referenceStartMilliseconds'],
      ),
      referenceEndMilliseconds: serializer.fromJson<int?>(
        json['referenceEndMilliseconds'],
      ),
      referenceSpeed: serializer.fromJson<double>(json['referenceSpeed']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String?>(json['note']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceId': serializer.toJson<String>(sourceId),
      'segmentId': serializer.toJson<String?>(segmentId),
      'planId': serializer.toJson<String?>(planId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'kind': serializer.toJson<String>(kind),
      'filePath': serializer.toJson<String>(filePath),
      'durationMilliseconds': serializer.toJson<int>(durationMilliseconds),
      'referenceStartMilliseconds': serializer.toJson<int>(
        referenceStartMilliseconds,
      ),
      'referenceEndMilliseconds': serializer.toJson<int?>(
        referenceEndMilliseconds,
      ),
      'referenceSpeed': serializer.toJson<double>(referenceSpeed),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String?>(note),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  PracticeRecording copyWith({
    String? id,
    String? sourceId,
    Value<String?> segmentId = const Value.absent(),
    Value<String?> planId = const Value.absent(),
    Value<String?> sessionId = const Value.absent(),
    String? kind,
    String? filePath,
    int? durationMilliseconds,
    int? referenceStartMilliseconds,
    Value<int?> referenceEndMilliseconds = const Value.absent(),
    double? referenceSpeed,
    String? title,
    Value<String?> note = const Value.absent(),
    DateTime? recordedAt,
  }) => PracticeRecording(
    id: id ?? this.id,
    sourceId: sourceId ?? this.sourceId,
    segmentId: segmentId.present ? segmentId.value : this.segmentId,
    planId: planId.present ? planId.value : this.planId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    kind: kind ?? this.kind,
    filePath: filePath ?? this.filePath,
    durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
    referenceStartMilliseconds:
        referenceStartMilliseconds ?? this.referenceStartMilliseconds,
    referenceEndMilliseconds: referenceEndMilliseconds.present
        ? referenceEndMilliseconds.value
        : this.referenceEndMilliseconds,
    referenceSpeed: referenceSpeed ?? this.referenceSpeed,
    title: title ?? this.title,
    note: note.present ? note.value : this.note,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  PracticeRecording copyWithCompanion(PracticeRecordingsCompanion data) {
    return PracticeRecording(
      id: data.id.present ? data.id.value : this.id,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      segmentId: data.segmentId.present ? data.segmentId.value : this.segmentId,
      planId: data.planId.present ? data.planId.value : this.planId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      kind: data.kind.present ? data.kind.value : this.kind,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      durationMilliseconds: data.durationMilliseconds.present
          ? data.durationMilliseconds.value
          : this.durationMilliseconds,
      referenceStartMilliseconds: data.referenceStartMilliseconds.present
          ? data.referenceStartMilliseconds.value
          : this.referenceStartMilliseconds,
      referenceEndMilliseconds: data.referenceEndMilliseconds.present
          ? data.referenceEndMilliseconds.value
          : this.referenceEndMilliseconds,
      referenceSpeed: data.referenceSpeed.present
          ? data.referenceSpeed.value
          : this.referenceSpeed,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecording(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('planId: $planId, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('filePath: $filePath, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('referenceStartMilliseconds: $referenceStartMilliseconds, ')
          ..write('referenceEndMilliseconds: $referenceEndMilliseconds, ')
          ..write('referenceSpeed: $referenceSpeed, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceId,
    segmentId,
    planId,
    sessionId,
    kind,
    filePath,
    durationMilliseconds,
    referenceStartMilliseconds,
    referenceEndMilliseconds,
    referenceSpeed,
    title,
    note,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeRecording &&
          other.id == this.id &&
          other.sourceId == this.sourceId &&
          other.segmentId == this.segmentId &&
          other.planId == this.planId &&
          other.sessionId == this.sessionId &&
          other.kind == this.kind &&
          other.filePath == this.filePath &&
          other.durationMilliseconds == this.durationMilliseconds &&
          other.referenceStartMilliseconds == this.referenceStartMilliseconds &&
          other.referenceEndMilliseconds == this.referenceEndMilliseconds &&
          other.referenceSpeed == this.referenceSpeed &&
          other.title == this.title &&
          other.note == this.note &&
          other.recordedAt == this.recordedAt);
}

class PracticeRecordingsCompanion extends UpdateCompanion<PracticeRecording> {
  final Value<String> id;
  final Value<String> sourceId;
  final Value<String?> segmentId;
  final Value<String?> planId;
  final Value<String?> sessionId;
  final Value<String> kind;
  final Value<String> filePath;
  final Value<int> durationMilliseconds;
  final Value<int> referenceStartMilliseconds;
  final Value<int?> referenceEndMilliseconds;
  final Value<double> referenceSpeed;
  final Value<String> title;
  final Value<String?> note;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const PracticeRecordingsCompanion({
    this.id = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.segmentId = const Value.absent(),
    this.planId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.kind = const Value.absent(),
    this.filePath = const Value.absent(),
    this.durationMilliseconds = const Value.absent(),
    this.referenceStartMilliseconds = const Value.absent(),
    this.referenceEndMilliseconds = const Value.absent(),
    this.referenceSpeed = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeRecordingsCompanion.insert({
    required String id,
    required String sourceId,
    this.segmentId = const Value.absent(),
    this.planId = const Value.absent(),
    this.sessionId = const Value.absent(),
    required String kind,
    required String filePath,
    required int durationMilliseconds,
    required int referenceStartMilliseconds,
    this.referenceEndMilliseconds = const Value.absent(),
    this.referenceSpeed = const Value.absent(),
    required String title,
    this.note = const Value.absent(),
    required DateTime recordedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceId = Value(sourceId),
       kind = Value(kind),
       filePath = Value(filePath),
       durationMilliseconds = Value(durationMilliseconds),
       referenceStartMilliseconds = Value(referenceStartMilliseconds),
       title = Value(title),
       recordedAt = Value(recordedAt);
  static Insertable<PracticeRecording> custom({
    Expression<String>? id,
    Expression<String>? sourceId,
    Expression<String>? segmentId,
    Expression<String>? planId,
    Expression<String>? sessionId,
    Expression<String>? kind,
    Expression<String>? filePath,
    Expression<int>? durationMilliseconds,
    Expression<int>? referenceStartMilliseconds,
    Expression<int>? referenceEndMilliseconds,
    Expression<double>? referenceSpeed,
    Expression<String>? title,
    Expression<String>? note,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceId != null) 'source_id': sourceId,
      if (segmentId != null) 'segment_id': segmentId,
      if (planId != null) 'plan_id': planId,
      if (sessionId != null) 'session_id': sessionId,
      if (kind != null) 'kind': kind,
      if (filePath != null) 'file_path': filePath,
      if (durationMilliseconds != null)
        'duration_milliseconds': durationMilliseconds,
      if (referenceStartMilliseconds != null)
        'reference_start_milliseconds': referenceStartMilliseconds,
      if (referenceEndMilliseconds != null)
        'reference_end_milliseconds': referenceEndMilliseconds,
      if (referenceSpeed != null) 'reference_speed': referenceSpeed,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeRecordingsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceId,
    Value<String?>? segmentId,
    Value<String?>? planId,
    Value<String?>? sessionId,
    Value<String>? kind,
    Value<String>? filePath,
    Value<int>? durationMilliseconds,
    Value<int>? referenceStartMilliseconds,
    Value<int?>? referenceEndMilliseconds,
    Value<double>? referenceSpeed,
    Value<String>? title,
    Value<String?>? note,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return PracticeRecordingsCompanion(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      segmentId: segmentId ?? this.segmentId,
      planId: planId ?? this.planId,
      sessionId: sessionId ?? this.sessionId,
      kind: kind ?? this.kind,
      filePath: filePath ?? this.filePath,
      durationMilliseconds: durationMilliseconds ?? this.durationMilliseconds,
      referenceStartMilliseconds:
          referenceStartMilliseconds ?? this.referenceStartMilliseconds,
      referenceEndMilliseconds:
          referenceEndMilliseconds ?? this.referenceEndMilliseconds,
      referenceSpeed: referenceSpeed ?? this.referenceSpeed,
      title: title ?? this.title,
      note: note ?? this.note,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (segmentId.present) {
      map['segment_id'] = Variable<String>(segmentId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (durationMilliseconds.present) {
      map['duration_milliseconds'] = Variable<int>(durationMilliseconds.value);
    }
    if (referenceStartMilliseconds.present) {
      map['reference_start_milliseconds'] = Variable<int>(
        referenceStartMilliseconds.value,
      );
    }
    if (referenceEndMilliseconds.present) {
      map['reference_end_milliseconds'] = Variable<int>(
        referenceEndMilliseconds.value,
      );
    }
    if (referenceSpeed.present) {
      map['reference_speed'] = Variable<double>(referenceSpeed.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecordingsCompanion(')
          ..write('id: $id, ')
          ..write('sourceId: $sourceId, ')
          ..write('segmentId: $segmentId, ')
          ..write('planId: $planId, ')
          ..write('sessionId: $sessionId, ')
          ..write('kind: $kind, ')
          ..write('filePath: $filePath, ')
          ..write('durationMilliseconds: $durationMilliseconds, ')
          ..write('referenceStartMilliseconds: $referenceStartMilliseconds, ')
          ..write('referenceEndMilliseconds: $referenceEndMilliseconds, ')
          ..write('referenceSpeed: $referenceSpeed, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxEntriesTable extends SyncOutboxEntries
    with TableInfo<$SyncOutboxEntriesTable, SyncOutboxEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<DateTime> changedAt = GeneratedColumn<DateTime>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entityType,
    entityId,
    operation,
    revision,
    changedAt,
    attemptCount,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncOutboxEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entityType, entityId};
  @override
  SyncOutboxEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxEntry(
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}changed_at'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncOutboxEntriesTable createAlias(String alias) {
    return $SyncOutboxEntriesTable(attachedDatabase, alias);
  }
}

class SyncOutboxEntry extends DataClass implements Insertable<SyncOutboxEntry> {
  final String entityType;
  final String entityId;
  final String operation;
  final int revision;
  final DateTime changedAt;
  final int attemptCount;
  final String? lastError;
  const SyncOutboxEntry({
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.revision,
    required this.changedAt,
    required this.attemptCount,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['revision'] = Variable<int>(revision);
    map['changed_at'] = Variable<DateTime>(changedAt);
    map['attempt_count'] = Variable<int>(attemptCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxEntriesCompanion(
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      revision: Value(revision),
      changedAt: Value(changedAt),
      attemptCount: Value(attemptCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxEntry(
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      revision: serializer.fromJson<int>(json['revision']),
      changedAt: serializer.fromJson<DateTime>(json['changedAt']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'revision': serializer.toJson<int>(revision),
      'changedAt': serializer.toJson<DateTime>(changedAt),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxEntry copyWith({
    String? entityType,
    String? entityId,
    String? operation,
    int? revision,
    DateTime? changedAt,
    int? attemptCount,
    Value<String?> lastError = const Value.absent(),
  }) => SyncOutboxEntry(
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    revision: revision ?? this.revision,
    changedAt: changedAt ?? this.changedAt,
    attemptCount: attemptCount ?? this.attemptCount,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncOutboxEntry copyWithCompanion(SyncOutboxEntriesCompanion data) {
    return SyncOutboxEntry(
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      revision: data.revision.present ? data.revision.value : this.revision,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntry(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('revision: $revision, ')
          ..write('changedAt: $changedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    entityType,
    entityId,
    operation,
    revision,
    changedAt,
    attemptCount,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxEntry &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.revision == this.revision &&
          other.changedAt == this.changedAt &&
          other.attemptCount == this.attemptCount &&
          other.lastError == this.lastError);
}

class SyncOutboxEntriesCompanion extends UpdateCompanion<SyncOutboxEntry> {
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<int> revision;
  final Value<DateTime> changedAt;
  final Value<int> attemptCount;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxEntriesCompanion({
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.revision = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxEntriesCompanion.insert({
    required String entityType,
    required String entityId,
    required String operation,
    this.revision = const Value.absent(),
    required DateTime changedAt,
    this.attemptCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       changedAt = Value(changedAt);
  static Insertable<SyncOutboxEntry> custom({
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<int>? revision,
    Expression<DateTime>? changedAt,
    Expression<int>? attemptCount,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (revision != null) 'revision': revision,
      if (changedAt != null) 'changed_at': changedAt,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxEntriesCompanion copyWith({
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<int>? revision,
    Value<DateTime>? changedAt,
    Value<int>? attemptCount,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncOutboxEntriesCompanion(
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      revision: revision ?? this.revision,
      changedAt: changedAt ?? this.changedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<DateTime>(changedAt.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxEntriesCompanion(')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('revision: $revision, ')
          ..write('changedAt: $changedAt, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlgorithmTasksTable extends AlgorithmTasks
    with TableInfo<$AlgorithmTasksTable, AlgorithmTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlgorithmTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chords'),
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputPathMeta = const VerificationMeta(
    'inputPath',
  );
  @override
  late final GeneratedColumn<String> inputPath = GeneratedColumn<String>(
    'input_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputNameMeta = const VerificationMeta(
    'inputName',
  );
  @override
  late final GeneratedColumn<String> inputName = GeneratedColumn<String>(
    'input_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputSizeBytesMeta = const VerificationMeta(
    'inputSizeBytes',
  );
  @override
  late final GeneratedColumn<int> inputSizeBytes = GeneratedColumn<int>(
    'input_size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputDurationMsMeta = const VerificationMeta(
    'inputDurationMs',
  );
  @override
  late final GeneratedColumn<int> inputDurationMs = GeneratedColumn<int>(
    'input_duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownsInputMeta = const VerificationMeta(
    'ownsInput',
  );
  @override
  late final GeneratedColumn<bool> ownsInput = GeneratedColumn<bool>(
    'owns_input',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("owns_input" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recordingIdMeta = const VerificationMeta(
    'recordingId',
  );
  @override
  late final GeneratedColumn<String> recordingId = GeneratedColumn<String>(
    'recording_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteJobIdMeta = const VerificationMeta(
    'remoteJobId',
  );
  @override
  late final GeneratedColumn<String> remoteJobId = GeneratedColumn<String>(
    'remote_job_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<int> progress = GeneratedColumn<int>(
    'progress',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultJsonMeta = const VerificationMeta(
    'resultJson',
  );
  @override
  late final GeneratedColumn<String> resultJson = GeneratedColumn<String>(
    'result_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextPollAtMeta = const VerificationMeta(
    'nextPollAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextPollAt = GeneratedColumn<DateTime>(
    'next_poll_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operation,
    endpoint,
    inputPath,
    inputName,
    inputSizeBytes,
    inputDurationMs,
    ownsInput,
    recordingId,
    status,
    remoteJobId,
    progress,
    message,
    resultJson,
    consecutiveFailures,
    nextPollAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'algorithm_tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlgorithmTask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('input_path')) {
      context.handle(
        _inputPathMeta,
        inputPath.isAcceptableOrUnknown(data['input_path']!, _inputPathMeta),
      );
    } else if (isInserting) {
      context.missing(_inputPathMeta);
    }
    if (data.containsKey('input_name')) {
      context.handle(
        _inputNameMeta,
        inputName.isAcceptableOrUnknown(data['input_name']!, _inputNameMeta),
      );
    } else if (isInserting) {
      context.missing(_inputNameMeta);
    }
    if (data.containsKey('input_size_bytes')) {
      context.handle(
        _inputSizeBytesMeta,
        inputSizeBytes.isAcceptableOrUnknown(
          data['input_size_bytes']!,
          _inputSizeBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputSizeBytesMeta);
    }
    if (data.containsKey('input_duration_ms')) {
      context.handle(
        _inputDurationMsMeta,
        inputDurationMs.isAcceptableOrUnknown(
          data['input_duration_ms']!,
          _inputDurationMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inputDurationMsMeta);
    }
    if (data.containsKey('owns_input')) {
      context.handle(
        _ownsInputMeta,
        ownsInput.isAcceptableOrUnknown(data['owns_input']!, _ownsInputMeta),
      );
    }
    if (data.containsKey('recording_id')) {
      context.handle(
        _recordingIdMeta,
        recordingId.isAcceptableOrUnknown(
          data['recording_id']!,
          _recordingIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('remote_job_id')) {
      context.handle(
        _remoteJobIdMeta,
        remoteJobId.isAcceptableOrUnknown(
          data['remote_job_id']!,
          _remoteJobIdMeta,
        ),
      );
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    }
    if (data.containsKey('result_json')) {
      context.handle(
        _resultJsonMeta,
        resultJson.isAcceptableOrUnknown(data['result_json']!, _resultJsonMeta),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('next_poll_at')) {
      context.handle(
        _nextPollAtMeta,
        nextPollAt.isAcceptableOrUnknown(
          data['next_poll_at']!,
          _nextPollAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlgorithmTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlgorithmTask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      inputPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_path'],
      )!,
      inputName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_name'],
      )!,
      inputSizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_size_bytes'],
      )!,
      inputDurationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_duration_ms'],
      )!,
      ownsInput: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}owns_input'],
      )!,
      recordingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recording_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      remoteJobId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_job_id'],
      ),
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}progress'],
      ),
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      ),
      resultJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_json'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      nextPollAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_poll_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AlgorithmTasksTable createAlias(String alias) {
    return $AlgorithmTasksTable(attachedDatabase, alias);
  }
}

class AlgorithmTask extends DataClass implements Insertable<AlgorithmTask> {
  final String id;
  final String operation;
  final String endpoint;
  final String inputPath;
  final String inputName;
  final int inputSizeBytes;
  final int inputDurationMs;
  final bool ownsInput;
  final String? recordingId;
  final String status;
  final String? remoteJobId;
  final int? progress;
  final String? message;
  final String? resultJson;
  final int consecutiveFailures;
  final DateTime? nextPollAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AlgorithmTask({
    required this.id,
    required this.operation,
    required this.endpoint,
    required this.inputPath,
    required this.inputName,
    required this.inputSizeBytes,
    required this.inputDurationMs,
    required this.ownsInput,
    this.recordingId,
    required this.status,
    this.remoteJobId,
    this.progress,
    this.message,
    this.resultJson,
    required this.consecutiveFailures,
    this.nextPollAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['operation'] = Variable<String>(operation);
    map['endpoint'] = Variable<String>(endpoint);
    map['input_path'] = Variable<String>(inputPath);
    map['input_name'] = Variable<String>(inputName);
    map['input_size_bytes'] = Variable<int>(inputSizeBytes);
    map['input_duration_ms'] = Variable<int>(inputDurationMs);
    map['owns_input'] = Variable<bool>(ownsInput);
    if (!nullToAbsent || recordingId != null) {
      map['recording_id'] = Variable<String>(recordingId);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || remoteJobId != null) {
      map['remote_job_id'] = Variable<String>(remoteJobId);
    }
    if (!nullToAbsent || progress != null) {
      map['progress'] = Variable<int>(progress);
    }
    if (!nullToAbsent || message != null) {
      map['message'] = Variable<String>(message);
    }
    if (!nullToAbsent || resultJson != null) {
      map['result_json'] = Variable<String>(resultJson);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    if (!nullToAbsent || nextPollAt != null) {
      map['next_poll_at'] = Variable<DateTime>(nextPollAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AlgorithmTasksCompanion toCompanion(bool nullToAbsent) {
    return AlgorithmTasksCompanion(
      id: Value(id),
      operation: Value(operation),
      endpoint: Value(endpoint),
      inputPath: Value(inputPath),
      inputName: Value(inputName),
      inputSizeBytes: Value(inputSizeBytes),
      inputDurationMs: Value(inputDurationMs),
      ownsInput: Value(ownsInput),
      recordingId: recordingId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordingId),
      status: Value(status),
      remoteJobId: remoteJobId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteJobId),
      progress: progress == null && nullToAbsent
          ? const Value.absent()
          : Value(progress),
      message: message == null && nullToAbsent
          ? const Value.absent()
          : Value(message),
      resultJson: resultJson == null && nullToAbsent
          ? const Value.absent()
          : Value(resultJson),
      consecutiveFailures: Value(consecutiveFailures),
      nextPollAt: nextPollAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextPollAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AlgorithmTask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlgorithmTask(
      id: serializer.fromJson<String>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      inputPath: serializer.fromJson<String>(json['inputPath']),
      inputName: serializer.fromJson<String>(json['inputName']),
      inputSizeBytes: serializer.fromJson<int>(json['inputSizeBytes']),
      inputDurationMs: serializer.fromJson<int>(json['inputDurationMs']),
      ownsInput: serializer.fromJson<bool>(json['ownsInput']),
      recordingId: serializer.fromJson<String?>(json['recordingId']),
      status: serializer.fromJson<String>(json['status']),
      remoteJobId: serializer.fromJson<String?>(json['remoteJobId']),
      progress: serializer.fromJson<int?>(json['progress']),
      message: serializer.fromJson<String?>(json['message']),
      resultJson: serializer.fromJson<String?>(json['resultJson']),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      nextPollAt: serializer.fromJson<DateTime?>(json['nextPollAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'operation': serializer.toJson<String>(operation),
      'endpoint': serializer.toJson<String>(endpoint),
      'inputPath': serializer.toJson<String>(inputPath),
      'inputName': serializer.toJson<String>(inputName),
      'inputSizeBytes': serializer.toJson<int>(inputSizeBytes),
      'inputDurationMs': serializer.toJson<int>(inputDurationMs),
      'ownsInput': serializer.toJson<bool>(ownsInput),
      'recordingId': serializer.toJson<String?>(recordingId),
      'status': serializer.toJson<String>(status),
      'remoteJobId': serializer.toJson<String?>(remoteJobId),
      'progress': serializer.toJson<int?>(progress),
      'message': serializer.toJson<String?>(message),
      'resultJson': serializer.toJson<String?>(resultJson),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'nextPollAt': serializer.toJson<DateTime?>(nextPollAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AlgorithmTask copyWith({
    String? id,
    String? operation,
    String? endpoint,
    String? inputPath,
    String? inputName,
    int? inputSizeBytes,
    int? inputDurationMs,
    bool? ownsInput,
    Value<String?> recordingId = const Value.absent(),
    String? status,
    Value<String?> remoteJobId = const Value.absent(),
    Value<int?> progress = const Value.absent(),
    Value<String?> message = const Value.absent(),
    Value<String?> resultJson = const Value.absent(),
    int? consecutiveFailures,
    Value<DateTime?> nextPollAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AlgorithmTask(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    endpoint: endpoint ?? this.endpoint,
    inputPath: inputPath ?? this.inputPath,
    inputName: inputName ?? this.inputName,
    inputSizeBytes: inputSizeBytes ?? this.inputSizeBytes,
    inputDurationMs: inputDurationMs ?? this.inputDurationMs,
    ownsInput: ownsInput ?? this.ownsInput,
    recordingId: recordingId.present ? recordingId.value : this.recordingId,
    status: status ?? this.status,
    remoteJobId: remoteJobId.present ? remoteJobId.value : this.remoteJobId,
    progress: progress.present ? progress.value : this.progress,
    message: message.present ? message.value : this.message,
    resultJson: resultJson.present ? resultJson.value : this.resultJson,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    nextPollAt: nextPollAt.present ? nextPollAt.value : this.nextPollAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AlgorithmTask copyWithCompanion(AlgorithmTasksCompanion data) {
    return AlgorithmTask(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      inputPath: data.inputPath.present ? data.inputPath.value : this.inputPath,
      inputName: data.inputName.present ? data.inputName.value : this.inputName,
      inputSizeBytes: data.inputSizeBytes.present
          ? data.inputSizeBytes.value
          : this.inputSizeBytes,
      inputDurationMs: data.inputDurationMs.present
          ? data.inputDurationMs.value
          : this.inputDurationMs,
      ownsInput: data.ownsInput.present ? data.ownsInput.value : this.ownsInput,
      recordingId: data.recordingId.present
          ? data.recordingId.value
          : this.recordingId,
      status: data.status.present ? data.status.value : this.status,
      remoteJobId: data.remoteJobId.present
          ? data.remoteJobId.value
          : this.remoteJobId,
      progress: data.progress.present ? data.progress.value : this.progress,
      message: data.message.present ? data.message.value : this.message,
      resultJson: data.resultJson.present
          ? data.resultJson.value
          : this.resultJson,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      nextPollAt: data.nextPollAt.present
          ? data.nextPollAt.value
          : this.nextPollAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlgorithmTask(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('endpoint: $endpoint, ')
          ..write('inputPath: $inputPath, ')
          ..write('inputName: $inputName, ')
          ..write('inputSizeBytes: $inputSizeBytes, ')
          ..write('inputDurationMs: $inputDurationMs, ')
          ..write('ownsInput: $ownsInput, ')
          ..write('recordingId: $recordingId, ')
          ..write('status: $status, ')
          ..write('remoteJobId: $remoteJobId, ')
          ..write('progress: $progress, ')
          ..write('message: $message, ')
          ..write('resultJson: $resultJson, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('nextPollAt: $nextPollAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operation,
    endpoint,
    inputPath,
    inputName,
    inputSizeBytes,
    inputDurationMs,
    ownsInput,
    recordingId,
    status,
    remoteJobId,
    progress,
    message,
    resultJson,
    consecutiveFailures,
    nextPollAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlgorithmTask &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.endpoint == this.endpoint &&
          other.inputPath == this.inputPath &&
          other.inputName == this.inputName &&
          other.inputSizeBytes == this.inputSizeBytes &&
          other.inputDurationMs == this.inputDurationMs &&
          other.ownsInput == this.ownsInput &&
          other.recordingId == this.recordingId &&
          other.status == this.status &&
          other.remoteJobId == this.remoteJobId &&
          other.progress == this.progress &&
          other.message == this.message &&
          other.resultJson == this.resultJson &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.nextPollAt == this.nextPollAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AlgorithmTasksCompanion extends UpdateCompanion<AlgorithmTask> {
  final Value<String> id;
  final Value<String> operation;
  final Value<String> endpoint;
  final Value<String> inputPath;
  final Value<String> inputName;
  final Value<int> inputSizeBytes;
  final Value<int> inputDurationMs;
  final Value<bool> ownsInput;
  final Value<String?> recordingId;
  final Value<String> status;
  final Value<String?> remoteJobId;
  final Value<int?> progress;
  final Value<String?> message;
  final Value<String?> resultJson;
  final Value<int> consecutiveFailures;
  final Value<DateTime?> nextPollAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AlgorithmTasksCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.inputPath = const Value.absent(),
    this.inputName = const Value.absent(),
    this.inputSizeBytes = const Value.absent(),
    this.inputDurationMs = const Value.absent(),
    this.ownsInput = const Value.absent(),
    this.recordingId = const Value.absent(),
    this.status = const Value.absent(),
    this.remoteJobId = const Value.absent(),
    this.progress = const Value.absent(),
    this.message = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.nextPollAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlgorithmTasksCompanion.insert({
    required String id,
    this.operation = const Value.absent(),
    required String endpoint,
    required String inputPath,
    required String inputName,
    required int inputSizeBytes,
    required int inputDurationMs,
    this.ownsInput = const Value.absent(),
    this.recordingId = const Value.absent(),
    required String status,
    this.remoteJobId = const Value.absent(),
    this.progress = const Value.absent(),
    this.message = const Value.absent(),
    this.resultJson = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.nextPollAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       endpoint = Value(endpoint),
       inputPath = Value(inputPath),
       inputName = Value(inputName),
       inputSizeBytes = Value(inputSizeBytes),
       inputDurationMs = Value(inputDurationMs),
       status = Value(status),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AlgorithmTask> custom({
    Expression<String>? id,
    Expression<String>? operation,
    Expression<String>? endpoint,
    Expression<String>? inputPath,
    Expression<String>? inputName,
    Expression<int>? inputSizeBytes,
    Expression<int>? inputDurationMs,
    Expression<bool>? ownsInput,
    Expression<String>? recordingId,
    Expression<String>? status,
    Expression<String>? remoteJobId,
    Expression<int>? progress,
    Expression<String>? message,
    Expression<String>? resultJson,
    Expression<int>? consecutiveFailures,
    Expression<DateTime>? nextPollAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (endpoint != null) 'endpoint': endpoint,
      if (inputPath != null) 'input_path': inputPath,
      if (inputName != null) 'input_name': inputName,
      if (inputSizeBytes != null) 'input_size_bytes': inputSizeBytes,
      if (inputDurationMs != null) 'input_duration_ms': inputDurationMs,
      if (ownsInput != null) 'owns_input': ownsInput,
      if (recordingId != null) 'recording_id': recordingId,
      if (status != null) 'status': status,
      if (remoteJobId != null) 'remote_job_id': remoteJobId,
      if (progress != null) 'progress': progress,
      if (message != null) 'message': message,
      if (resultJson != null) 'result_json': resultJson,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (nextPollAt != null) 'next_poll_at': nextPollAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlgorithmTasksCompanion copyWith({
    Value<String>? id,
    Value<String>? operation,
    Value<String>? endpoint,
    Value<String>? inputPath,
    Value<String>? inputName,
    Value<int>? inputSizeBytes,
    Value<int>? inputDurationMs,
    Value<bool>? ownsInput,
    Value<String?>? recordingId,
    Value<String>? status,
    Value<String?>? remoteJobId,
    Value<int?>? progress,
    Value<String?>? message,
    Value<String?>? resultJson,
    Value<int>? consecutiveFailures,
    Value<DateTime?>? nextPollAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AlgorithmTasksCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      endpoint: endpoint ?? this.endpoint,
      inputPath: inputPath ?? this.inputPath,
      inputName: inputName ?? this.inputName,
      inputSizeBytes: inputSizeBytes ?? this.inputSizeBytes,
      inputDurationMs: inputDurationMs ?? this.inputDurationMs,
      ownsInput: ownsInput ?? this.ownsInput,
      recordingId: recordingId ?? this.recordingId,
      status: status ?? this.status,
      remoteJobId: remoteJobId ?? this.remoteJobId,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      resultJson: resultJson ?? this.resultJson,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      nextPollAt: nextPollAt ?? this.nextPollAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (inputPath.present) {
      map['input_path'] = Variable<String>(inputPath.value);
    }
    if (inputName.present) {
      map['input_name'] = Variable<String>(inputName.value);
    }
    if (inputSizeBytes.present) {
      map['input_size_bytes'] = Variable<int>(inputSizeBytes.value);
    }
    if (inputDurationMs.present) {
      map['input_duration_ms'] = Variable<int>(inputDurationMs.value);
    }
    if (ownsInput.present) {
      map['owns_input'] = Variable<bool>(ownsInput.value);
    }
    if (recordingId.present) {
      map['recording_id'] = Variable<String>(recordingId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (remoteJobId.present) {
      map['remote_job_id'] = Variable<String>(remoteJobId.value);
    }
    if (progress.present) {
      map['progress'] = Variable<int>(progress.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    if (resultJson.present) {
      map['result_json'] = Variable<String>(resultJson.value);
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (nextPollAt.present) {
      map['next_poll_at'] = Variable<DateTime>(nextPollAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlgorithmTasksCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('endpoint: $endpoint, ')
          ..write('inputPath: $inputPath, ')
          ..write('inputName: $inputName, ')
          ..write('inputSizeBytes: $inputSizeBytes, ')
          ..write('inputDurationMs: $inputDurationMs, ')
          ..write('ownsInput: $ownsInput, ')
          ..write('recordingId: $recordingId, ')
          ..write('status: $status, ')
          ..write('remoteJobId: $remoteJobId, ')
          ..write('progress: $progress, ')
          ..write('message: $message, ')
          ..write('resultJson: $resultJson, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('nextPollAt: $nextPollAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PracticeSourcesTable practiceSources = $PracticeSourcesTable(
    this,
  );
  late final $PracticeSegmentsTable practiceSegments = $PracticeSegmentsTable(
    this,
  );
  late final $PracticePlansTable practicePlans = $PracticePlansTable(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final $PracticeRecordingsTable practiceRecordings =
      $PracticeRecordingsTable(this);
  late final $SyncOutboxEntriesTable syncOutboxEntries =
      $SyncOutboxEntriesTable(this);
  late final $AlgorithmTasksTable algorithmTasks = $AlgorithmTasksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    practiceSources,
    practiceSegments,
    practicePlans,
    practiceSessions,
    practiceRecordings,
    syncOutboxEntries,
    algorithmTasks,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_segments', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_sources',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_plans', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_segments',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_plans', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'practice_plans',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('practice_sessions', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$PracticeSourcesTableCreateCompanionBuilder =
    PracticeSourcesCompanion Function({
      required String id,
      required String platform,
      required String kind,
      Value<String?> originalUrl,
      Value<String?> canonicalUrl,
      Value<String?> externalId,
      required String title,
      Value<String?> thumbnailUrl,
      Value<int?> durationMilliseconds,
      Value<String?> note,
      Value<String> syncStatus,
      Value<DateTime?> completedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PracticeSourcesTableUpdateCompanionBuilder =
    PracticeSourcesCompanion Function({
      Value<String> id,
      Value<String> platform,
      Value<String> kind,
      Value<String?> originalUrl,
      Value<String?> canonicalUrl,
      Value<String?> externalId,
      Value<String> title,
      Value<String?> thumbnailUrl,
      Value<int?> durationMilliseconds,
      Value<String?> note,
      Value<String> syncStatus,
      Value<DateTime?> completedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PracticeSourcesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSourcesTable, PracticeSource> {
  $$PracticeSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PracticeSegmentsTable, List<PracticeSegment>>
  _practiceSegmentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practiceSegments,
    aliasName: 'practice_sources__id__practice_segments__source_id',
  );

  $$PracticeSegmentsTableProcessedTableManager get practiceSegmentsRefs {
    final manager = $$PracticeSegmentsTableTableManager(
      $_db,
      $_db.practiceSegments,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _practiceSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PracticePlansTable, List<PracticePlan>>
  _practicePlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practicePlans,
    aliasName: 'practice_sources__id__practice_plans__source_id',
  );

  $$PracticePlansTableProcessedTableManager get practicePlansRefs {
    final manager = $$PracticePlansTableTableManager(
      $_db,
      $_db.practicePlans,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_practicePlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticeSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSourcesTable> {
  $$PracticeSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> practiceSegmentsRefs(
    Expression<bool> Function($$PracticeSegmentsTableFilterComposer f) f,
  ) {
    final $$PracticeSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSegments,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> practicePlansRefs(
    Expression<bool> Function($$PracticePlansTableFilterComposer f) f,
  ) {
    final $$PracticePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableFilterComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSourcesTable> {
  $$PracticeSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSourcesTable> {
  $$PracticeSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get originalUrl => $composableBuilder(
    column: $table.originalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get canonicalUrl => $composableBuilder(
    column: $table.canonicalUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get thumbnailUrl => $composableBuilder(
    column: $table.thumbnailUrl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> practiceSegmentsRefs<T extends Object>(
    Expression<T> Function($$PracticeSegmentsTableAnnotationComposer a) f,
  ) {
    final $$PracticeSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSegments,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> practicePlansRefs<T extends Object>(
    Expression<T> Function($$PracticePlansTableAnnotationComposer a) f,
  ) {
    final $$PracticePlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableAnnotationComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSourcesTable,
          PracticeSource,
          $$PracticeSourcesTableFilterComposer,
          $$PracticeSourcesTableOrderingComposer,
          $$PracticeSourcesTableAnnotationComposer,
          $$PracticeSourcesTableCreateCompanionBuilder,
          $$PracticeSourcesTableUpdateCompanionBuilder,
          (PracticeSource, $$PracticeSourcesTableReferences),
          PracticeSource,
          PrefetchHooks Function({
            bool practiceSegmentsRefs,
            bool practicePlansRefs,
          })
        > {
  $$PracticeSourcesTableTableManager(
    _$AppDatabase db,
    $PracticeSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSourcesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> originalUrl = const Value.absent(),
                Value<String?> canonicalUrl = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSourcesCompanion(
                id: id,
                platform: platform,
                kind: kind,
                originalUrl: originalUrl,
                canonicalUrl: canonicalUrl,
                externalId: externalId,
                title: title,
                thumbnailUrl: thumbnailUrl,
                durationMilliseconds: durationMilliseconds,
                note: note,
                syncStatus: syncStatus,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String platform,
                required String kind,
                Value<String?> originalUrl = const Value.absent(),
                Value<String?> canonicalUrl = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                required String title,
                Value<String?> thumbnailUrl = const Value.absent(),
                Value<int?> durationMilliseconds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PracticeSourcesCompanion.insert(
                id: id,
                platform: platform,
                kind: kind,
                originalUrl: originalUrl,
                canonicalUrl: canonicalUrl,
                externalId: externalId,
                title: title,
                thumbnailUrl: thumbnailUrl,
                durationMilliseconds: durationMilliseconds,
                note: note,
                syncStatus: syncStatus,
                completedAt: completedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeSourcesTable, PracticeSource>(table),
                  $$PracticeSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({practiceSegmentsRefs = false, practicePlansRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (practiceSegmentsRefs) db.practiceSegments,
                    if (practicePlansRefs) db.practicePlans,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (practiceSegmentsRefs)
                        await $_getPrefetchedData<
                          PracticeSource,
                          $PracticeSourcesTable,
                          PracticeSegment
                        >(
                          currentTable: table,
                          referencedTable: $$PracticeSourcesTableReferences
                              ._practiceSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticeSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).practiceSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (practicePlansRefs)
                        await $_getPrefetchedData<
                          PracticeSource,
                          $PracticeSourcesTable,
                          PracticePlan
                        >(
                          currentTable: table,
                          referencedTable: $$PracticeSourcesTableReferences
                              ._practicePlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticeSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).practicePlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PracticeSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSourcesTable,
      PracticeSource,
      $$PracticeSourcesTableFilterComposer,
      $$PracticeSourcesTableOrderingComposer,
      $$PracticeSourcesTableAnnotationComposer,
      $$PracticeSourcesTableCreateCompanionBuilder,
      $$PracticeSourcesTableUpdateCompanionBuilder,
      (PracticeSource, $$PracticeSourcesTableReferences),
      PracticeSource,
      PrefetchHooks Function({
        bool practiceSegmentsRefs,
        bool practicePlansRefs,
      })
    >;
typedef $$PracticeSegmentsTableCreateCompanionBuilder =
    PracticeSegmentsCompanion Function({
      required String id,
      required String sourceId,
      required String title,
      required int startMilliseconds,
      required int endMilliseconds,
      Value<String?> note,
      Value<double> preferredSpeed,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PracticeSegmentsTableUpdateCompanionBuilder =
    PracticeSegmentsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String> title,
      Value<int> startMilliseconds,
      Value<int> endMilliseconds,
      Value<String?> note,
      Value<double> preferredSpeed,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PracticeSegmentsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSegmentsTable, PracticeSegment> {
  $$PracticeSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PracticeSourcesTable _sourceIdTable(_$AppDatabase db) => db
      .practiceSources
      .createAlias('practice_segments__source_id__practice_sources__id');

  $$PracticeSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$PracticeSourcesTableTableManager(
      $_db,
      $_db.practiceSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PracticePlansTable, List<PracticePlan>>
  _practicePlansRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practicePlans,
    aliasName: 'practice_segments__id__practice_plans__segment_id',
  );

  $$PracticePlansTableProcessedTableManager get practicePlansRefs {
    final manager = $$PracticePlansTableTableManager(
      $_db,
      $_db.practicePlans,
    ).filter((f) => f.segmentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_practicePlansRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticeSegmentsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSegmentsTable> {
  $$PracticeSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startMilliseconds => $composableBuilder(
    column: $table.startMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endMilliseconds => $composableBuilder(
    column: $table.endMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get preferredSpeed => $composableBuilder(
    column: $table.preferredSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticeSourcesTableFilterComposer get sourceId {
    final $$PracticeSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableFilterComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> practicePlansRefs(
    Expression<bool> Function($$PracticePlansTableFilterComposer f) f,
  ) {
    final $$PracticePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.segmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableFilterComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSegmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSegmentsTable> {
  $$PracticeSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startMilliseconds => $composableBuilder(
    column: $table.startMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endMilliseconds => $composableBuilder(
    column: $table.endMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get preferredSpeed => $composableBuilder(
    column: $table.preferredSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticeSourcesTableOrderingComposer get sourceId {
    final $$PracticeSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSegmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSegmentsTable> {
  $$PracticeSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get startMilliseconds => $composableBuilder(
    column: $table.startMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endMilliseconds => $composableBuilder(
    column: $table.endMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get preferredSpeed => $composableBuilder(
    column: $table.preferredSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PracticeSourcesTableAnnotationComposer get sourceId {
    final $$PracticeSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> practicePlansRefs<T extends Object>(
    Expression<T> Function($$PracticePlansTableAnnotationComposer a) f,
  ) {
    final $$PracticePlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.segmentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableAnnotationComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticeSegmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSegmentsTable,
          PracticeSegment,
          $$PracticeSegmentsTableFilterComposer,
          $$PracticeSegmentsTableOrderingComposer,
          $$PracticeSegmentsTableAnnotationComposer,
          $$PracticeSegmentsTableCreateCompanionBuilder,
          $$PracticeSegmentsTableUpdateCompanionBuilder,
          (PracticeSegment, $$PracticeSegmentsTableReferences),
          PracticeSegment,
          PrefetchHooks Function({bool sourceId, bool practicePlansRefs})
        > {
  $$PracticeSegmentsTableTableManager(
    _$AppDatabase db,
    $PracticeSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSegmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSegmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> startMilliseconds = const Value.absent(),
                Value<int> endMilliseconds = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double> preferredSpeed = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSegmentsCompanion(
                id: id,
                sourceId: sourceId,
                title: title,
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                note: note,
                preferredSpeed: preferredSpeed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                required String title,
                required int startMilliseconds,
                required int endMilliseconds,
                Value<String?> note = const Value.absent(),
                Value<double> preferredSpeed = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PracticeSegmentsCompanion.insert(
                id: id,
                sourceId: sourceId,
                title: title,
                startMilliseconds: startMilliseconds,
                endMilliseconds: endMilliseconds,
                note: note,
                preferredSpeed: preferredSpeed,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeSegmentsTable, PracticeSegment>(table),
                  $$PracticeSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceId = false, practicePlansRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (practicePlansRefs) db.practicePlans,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$PracticeSegmentsTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$PracticeSegmentsTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (practicePlansRefs)
                        await $_getPrefetchedData<
                          PracticeSegment,
                          $PracticeSegmentsTable,
                          PracticePlan
                        >(
                          currentTable: table,
                          referencedTable: $$PracticeSegmentsTableReferences
                              ._practicePlansRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticeSegmentsTableReferences(
                                db,
                                table,
                                p0,
                              ).practicePlansRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.segmentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PracticeSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSegmentsTable,
      PracticeSegment,
      $$PracticeSegmentsTableFilterComposer,
      $$PracticeSegmentsTableOrderingComposer,
      $$PracticeSegmentsTableAnnotationComposer,
      $$PracticeSegmentsTableCreateCompanionBuilder,
      $$PracticeSegmentsTableUpdateCompanionBuilder,
      (PracticeSegment, $$PracticeSegmentsTableReferences),
      PracticeSegment,
      PrefetchHooks Function({bool sourceId, bool practicePlansRefs})
    >;
typedef $$PracticePlansTableCreateCompanionBuilder =
    PracticePlansCompanion Function({
      required String id,
      required String name,
      required String sourceId,
      Value<String?> segmentId,
      required String goalType,
      Value<int?> targetLoops,
      Value<int?> targetDurationMilliseconds,
      required int startDay,
      required int endDay,
      required int repeatWeekdayMask,
      Value<int?> reminderMinutesSinceMidnight,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PracticePlansTableUpdateCompanionBuilder =
    PracticePlansCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> sourceId,
      Value<String?> segmentId,
      Value<String> goalType,
      Value<int?> targetLoops,
      Value<int?> targetDurationMilliseconds,
      Value<int> startDay,
      Value<int> endDay,
      Value<int> repeatWeekdayMask,
      Value<int?> reminderMinutesSinceMidnight,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$PracticePlansTableReferences
    extends BaseReferences<_$AppDatabase, $PracticePlansTable, PracticePlan> {
  $$PracticePlansTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PracticeSourcesTable _sourceIdTable(_$AppDatabase db) => db
      .practiceSources
      .createAlias('practice_plans__source_id__practice_sources__id');

  $$PracticeSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$PracticeSourcesTableTableManager(
      $_db,
      $_db.practiceSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PracticeSegmentsTable _segmentIdTable(_$AppDatabase db) => db
      .practiceSegments
      .createAlias('practice_plans__segment_id__practice_segments__id');

  $$PracticeSegmentsTableProcessedTableManager? get segmentId {
    final $_column = $_itemColumn<String>('segment_id');
    if ($_column == null) return null;
    final manager = $$PracticeSegmentsTableTableManager(
      $_db,
      $_db.practiceSegments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_segmentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PracticeSessionsTable, List<PracticeSession>>
  _practiceSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.practiceSessions,
    aliasName: 'practice_plans__id__practice_sessions__plan_id',
  );

  $$PracticeSessionsTableProcessedTableManager get practiceSessionsRefs {
    final manager = $$PracticeSessionsTableTableManager(
      $_db,
      $_db.practiceSessions,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _practiceSessionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PracticePlansTableFilterComposer
    extends Composer<_$AppDatabase, $PracticePlansTable> {
  $$PracticePlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetLoops => $composableBuilder(
    column: $table.targetLoops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetDurationMilliseconds => $composableBuilder(
    column: $table.targetDurationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startDay => $composableBuilder(
    column: $table.startDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endDay => $composableBuilder(
    column: $table.endDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatWeekdayMask => $composableBuilder(
    column: $table.repeatWeekdayMask,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderMinutesSinceMidnight => $composableBuilder(
    column: $table.reminderMinutesSinceMidnight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticeSourcesTableFilterComposer get sourceId {
    final $$PracticeSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableFilterComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PracticeSegmentsTableFilterComposer get segmentId {
    final $$PracticeSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.practiceSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> practiceSessionsRefs(
    Expression<bool> Function($$PracticeSessionsTableFilterComposer f) f,
  ) {
    final $$PracticeSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableFilterComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticePlansTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticePlansTable> {
  $$PracticePlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetLoops => $composableBuilder(
    column: $table.targetLoops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetDurationMilliseconds => $composableBuilder(
    column: $table.targetDurationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startDay => $composableBuilder(
    column: $table.startDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endDay => $composableBuilder(
    column: $table.endDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatWeekdayMask => $composableBuilder(
    column: $table.repeatWeekdayMask,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderMinutesSinceMidnight => $composableBuilder(
    column: $table.reminderMinutesSinceMidnight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticeSourcesTableOrderingComposer get sourceId {
    final $$PracticeSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PracticeSegmentsTableOrderingComposer get segmentId {
    final $$PracticeSegmentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.practiceSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSegmentsTableOrderingComposer(
            $db: $db,
            $table: $db.practiceSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticePlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticePlansTable> {
  $$PracticePlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<int> get targetLoops => $composableBuilder(
    column: $table.targetLoops,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetDurationMilliseconds => $composableBuilder(
    column: $table.targetDurationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startDay =>
      $composableBuilder(column: $table.startDay, builder: (column) => column);

  GeneratedColumn<int> get endDay =>
      $composableBuilder(column: $table.endDay, builder: (column) => column);

  GeneratedColumn<int> get repeatWeekdayMask => $composableBuilder(
    column: $table.repeatWeekdayMask,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderMinutesSinceMidnight => $composableBuilder(
    column: $table.reminderMinutesSinceMidnight,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PracticeSourcesTableAnnotationComposer get sourceId {
    final $$PracticeSourcesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.practiceSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSourcesTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PracticeSegmentsTableAnnotationComposer get segmentId {
    final $$PracticeSegmentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.segmentId,
      referencedTable: $db.practiceSegments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSegmentsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> practiceSessionsRefs<T extends Object>(
    Expression<T> Function($$PracticeSessionsTableAnnotationComposer a) f,
  ) {
    final $$PracticeSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.practiceSessions,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticeSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.practiceSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PracticePlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticePlansTable,
          PracticePlan,
          $$PracticePlansTableFilterComposer,
          $$PracticePlansTableOrderingComposer,
          $$PracticePlansTableAnnotationComposer,
          $$PracticePlansTableCreateCompanionBuilder,
          $$PracticePlansTableUpdateCompanionBuilder,
          (PracticePlan, $$PracticePlansTableReferences),
          PracticePlan,
          PrefetchHooks Function({
            bool sourceId,
            bool segmentId,
            bool practiceSessionsRefs,
          })
        > {
  $$PracticePlansTableTableManager(_$AppDatabase db, $PracticePlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticePlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticePlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticePlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<String> goalType = const Value.absent(),
                Value<int?> targetLoops = const Value.absent(),
                Value<int?> targetDurationMilliseconds = const Value.absent(),
                Value<int> startDay = const Value.absent(),
                Value<int> endDay = const Value.absent(),
                Value<int> repeatWeekdayMask = const Value.absent(),
                Value<int?> reminderMinutesSinceMidnight = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticePlansCompanion(
                id: id,
                name: name,
                sourceId: sourceId,
                segmentId: segmentId,
                goalType: goalType,
                targetLoops: targetLoops,
                targetDurationMilliseconds: targetDurationMilliseconds,
                startDay: startDay,
                endDay: endDay,
                repeatWeekdayMask: repeatWeekdayMask,
                reminderMinutesSinceMidnight: reminderMinutesSinceMidnight,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String sourceId,
                Value<String?> segmentId = const Value.absent(),
                required String goalType,
                Value<int?> targetLoops = const Value.absent(),
                Value<int?> targetDurationMilliseconds = const Value.absent(),
                required int startDay,
                required int endDay,
                required int repeatWeekdayMask,
                Value<int?> reminderMinutesSinceMidnight = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PracticePlansCompanion.insert(
                id: id,
                name: name,
                sourceId: sourceId,
                segmentId: segmentId,
                goalType: goalType,
                targetLoops: targetLoops,
                targetDurationMilliseconds: targetDurationMilliseconds,
                startDay: startDay,
                endDay: endDay,
                repeatWeekdayMask: repeatWeekdayMask,
                reminderMinutesSinceMidnight: reminderMinutesSinceMidnight,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticePlansTable, PracticePlan>(table),
                  $$PracticePlansTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sourceId = false,
                segmentId = false,
                practiceSessionsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (practiceSessionsRefs) db.practiceSessions,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sourceId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.sourceId,
                            referencedTable: $$PracticePlansTableReferences
                                ._sourceIdTable(db),
                            referencedColumn: $$PracticePlansTableReferences
                                ._sourceIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (segmentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.segmentId,
                            referencedTable: $$PracticePlansTableReferences
                                ._segmentIdTable(db),
                            referencedColumn: $$PracticePlansTableReferences
                                ._segmentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (practiceSessionsRefs)
                        await $_getPrefetchedData<
                          PracticePlan,
                          $PracticePlansTable,
                          PracticeSession
                        >(
                          currentTable: table,
                          referencedTable: $$PracticePlansTableReferences
                              ._practiceSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PracticePlansTableReferences(
                                db,
                                table,
                                p0,
                              ).practiceSessionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PracticePlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticePlansTable,
      PracticePlan,
      $$PracticePlansTableFilterComposer,
      $$PracticePlansTableOrderingComposer,
      $$PracticePlansTableAnnotationComposer,
      $$PracticePlansTableCreateCompanionBuilder,
      $$PracticePlansTableUpdateCompanionBuilder,
      (PracticePlan, $$PracticePlansTableReferences),
      PracticePlan,
      PrefetchHooks Function({
        bool sourceId,
        bool segmentId,
        bool practiceSessionsRefs,
      })
    >;
typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      required String id,
      Value<String?> planId,
      required String sourceId,
      Value<String?> segmentId,
      required int practiceDay,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> activeDurationMilliseconds,
      Value<int> loopCount,
      Value<bool> completed,
      Value<int> rowid,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<String> id,
      Value<String?> planId,
      Value<String> sourceId,
      Value<String?> segmentId,
      Value<int> practiceDay,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> activeDurationMilliseconds,
      Value<int> loopCount,
      Value<bool> completed,
      Value<int> rowid,
    });

final class $$PracticeSessionsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession> {
  $$PracticeSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PracticePlansTable _planIdTable(_$AppDatabase db) => db.practicePlans
      .createAlias('practice_sessions__plan_id__practice_plans__id');

  $$PracticePlansTableProcessedTableManager? get planId {
    final $_column = $_itemColumn<String>('plan_id');
    if ($_column == null) return null;
    final manager = $$PracticePlansTableTableManager(
      $_db,
      $_db.practicePlans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get practiceDay => $composableBuilder(
    column: $table.practiceDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activeDurationMilliseconds => $composableBuilder(
    column: $table.activeDurationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  $$PracticePlansTableFilterComposer get planId {
    final $$PracticePlansTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableFilterComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get practiceDay => $composableBuilder(
    column: $table.practiceDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activeDurationMilliseconds => $composableBuilder(
    column: $table.activeDurationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loopCount => $composableBuilder(
    column: $table.loopCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  $$PracticePlansTableOrderingComposer get planId {
    final $$PracticePlansTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableOrderingComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<int> get practiceDay => $composableBuilder(
    column: $table.practiceDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get activeDurationMilliseconds => $composableBuilder(
    column: $table.activeDurationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loopCount =>
      $composableBuilder(column: $table.loopCount, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  $$PracticePlansTableAnnotationComposer get planId {
    final $$PracticePlansTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.practicePlans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PracticePlansTableAnnotationComposer(
            $db: $db,
            $table: $db.practicePlans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (PracticeSession, $$PracticeSessionsTableReferences),
          PracticeSession,
          PrefetchHooks Function({bool planId})
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<int> practiceDay = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> activeDurationMilliseconds = const Value.absent(),
                Value<int> loopCount = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                planId: planId,
                sourceId: sourceId,
                segmentId: segmentId,
                practiceDay: practiceDay,
                startedAt: startedAt,
                endedAt: endedAt,
                activeDurationMilliseconds: activeDurationMilliseconds,
                loopCount: loopCount,
                completed: completed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> planId = const Value.absent(),
                required String sourceId,
                Value<String?> segmentId = const Value.absent(),
                required int practiceDay,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> activeDurationMilliseconds = const Value.absent(),
                Value<int> loopCount = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeSessionsCompanion.insert(
                id: id,
                planId: planId,
                sourceId: sourceId,
                segmentId: segmentId,
                practiceDay: practiceDay,
                startedAt: startedAt,
                endedAt: endedAt,
                activeDurationMilliseconds: activeDurationMilliseconds,
                loopCount: loopCount,
                completed: completed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeSessionsTable, PracticeSession>(table),
                  $$PracticeSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.planId,
                        referencedTable: $$PracticeSessionsTableReferences
                            ._planIdTable(db),
                        referencedColumn: $$PracticeSessionsTableReferences
                            ._planIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (PracticeSession, $$PracticeSessionsTableReferences),
      PracticeSession,
      PrefetchHooks Function({bool planId})
    >;
typedef $$PracticeRecordingsTableCreateCompanionBuilder =
    PracticeRecordingsCompanion Function({
      required String id,
      required String sourceId,
      Value<String?> segmentId,
      Value<String?> planId,
      Value<String?> sessionId,
      required String kind,
      required String filePath,
      required int durationMilliseconds,
      required int referenceStartMilliseconds,
      Value<int?> referenceEndMilliseconds,
      Value<double> referenceSpeed,
      required String title,
      Value<String?> note,
      required DateTime recordedAt,
      Value<int> rowid,
    });
typedef $$PracticeRecordingsTableUpdateCompanionBuilder =
    PracticeRecordingsCompanion Function({
      Value<String> id,
      Value<String> sourceId,
      Value<String?> segmentId,
      Value<String?> planId,
      Value<String?> sessionId,
      Value<String> kind,
      Value<String> filePath,
      Value<int> durationMilliseconds,
      Value<int> referenceStartMilliseconds,
      Value<int?> referenceEndMilliseconds,
      Value<double> referenceSpeed,
      Value<String> title,
      Value<String?> note,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

class $$PracticeRecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceStartMilliseconds => $composableBuilder(
    column: $table.referenceStartMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get referenceEndMilliseconds => $composableBuilder(
    column: $table.referenceEndMilliseconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get referenceSpeed => $composableBuilder(
    column: $table.referenceSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PracticeRecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentId => $composableBuilder(
    column: $table.segmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planId => $composableBuilder(
    column: $table.planId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceStartMilliseconds => $composableBuilder(
    column: $table.referenceStartMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get referenceEndMilliseconds => $composableBuilder(
    column: $table.referenceEndMilliseconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get referenceSpeed => $composableBuilder(
    column: $table.referenceSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeRecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeRecordingsTable> {
  $$PracticeRecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get segmentId =>
      $composableBuilder(column: $table.segmentId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get durationMilliseconds => $composableBuilder(
    column: $table.durationMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get referenceStartMilliseconds => $composableBuilder(
    column: $table.referenceStartMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get referenceEndMilliseconds => $composableBuilder(
    column: $table.referenceEndMilliseconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get referenceSpeed => $composableBuilder(
    column: $table.referenceSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );
}

class $$PracticeRecordingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeRecordingsTable,
          PracticeRecording,
          $$PracticeRecordingsTableFilterComposer,
          $$PracticeRecordingsTableOrderingComposer,
          $$PracticeRecordingsTableAnnotationComposer,
          $$PracticeRecordingsTableCreateCompanionBuilder,
          $$PracticeRecordingsTableUpdateCompanionBuilder,
          (
            PracticeRecording,
            BaseReferences<
              _$AppDatabase,
              $PracticeRecordingsTable,
              PracticeRecording
            >,
          ),
          PracticeRecording,
          PrefetchHooks Function()
        > {
  $$PracticeRecordingsTableTableManager(
    _$AppDatabase db,
    $PracticeRecordingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeRecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeRecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeRecordingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> segmentId = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int> durationMilliseconds = const Value.absent(),
                Value<int> referenceStartMilliseconds = const Value.absent(),
                Value<int?> referenceEndMilliseconds = const Value.absent(),
                Value<double> referenceSpeed = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PracticeRecordingsCompanion(
                id: id,
                sourceId: sourceId,
                segmentId: segmentId,
                planId: planId,
                sessionId: sessionId,
                kind: kind,
                filePath: filePath,
                durationMilliseconds: durationMilliseconds,
                referenceStartMilliseconds: referenceStartMilliseconds,
                referenceEndMilliseconds: referenceEndMilliseconds,
                referenceSpeed: referenceSpeed,
                title: title,
                note: note,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceId,
                Value<String?> segmentId = const Value.absent(),
                Value<String?> planId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                required String kind,
                required String filePath,
                required int durationMilliseconds,
                required int referenceStartMilliseconds,
                Value<int?> referenceEndMilliseconds = const Value.absent(),
                Value<double> referenceSpeed = const Value.absent(),
                required String title,
                Value<String?> note = const Value.absent(),
                required DateTime recordedAt,
                Value<int> rowid = const Value.absent(),
              }) => PracticeRecordingsCompanion.insert(
                id: id,
                sourceId: sourceId,
                segmentId: segmentId,
                planId: planId,
                sessionId: sessionId,
                kind: kind,
                filePath: filePath,
                durationMilliseconds: durationMilliseconds,
                referenceStartMilliseconds: referenceStartMilliseconds,
                referenceEndMilliseconds: referenceEndMilliseconds,
                referenceSpeed: referenceSpeed,
                title: title,
                note: note,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PracticeRecordingsTable, PracticeRecording>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $PracticeRecordingsTable,
                    PracticeRecording
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PracticeRecordingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeRecordingsTable,
      PracticeRecording,
      $$PracticeRecordingsTableFilterComposer,
      $$PracticeRecordingsTableOrderingComposer,
      $$PracticeRecordingsTableAnnotationComposer,
      $$PracticeRecordingsTableCreateCompanionBuilder,
      $$PracticeRecordingsTableUpdateCompanionBuilder,
      (
        PracticeRecording,
        BaseReferences<
          _$AppDatabase,
          $PracticeRecordingsTable,
          PracticeRecording
        >,
      ),
      PracticeRecording,
      PrefetchHooks Function()
    >;
typedef $$SyncOutboxEntriesTableCreateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      required String entityType,
      required String entityId,
      required String operation,
      Value<int> revision,
      required DateTime changedAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncOutboxEntriesTableUpdateCompanionBuilder =
    SyncOutboxEntriesCompanion Function({
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<int> revision,
      Value<DateTime> changedAt,
      Value<int> attemptCount,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncOutboxEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncOutboxEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncOutboxEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxEntriesTable> {
  $$SyncOutboxEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncOutboxEntriesTable,
          SyncOutboxEntry,
          $$SyncOutboxEntriesTableFilterComposer,
          $$SyncOutboxEntriesTableOrderingComposer,
          $$SyncOutboxEntriesTableAnnotationComposer,
          $$SyncOutboxEntriesTableCreateCompanionBuilder,
          $$SyncOutboxEntriesTableUpdateCompanionBuilder,
          (
            SyncOutboxEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncOutboxEntriesTable,
              SyncOutboxEntry
            >,
          ),
          SyncOutboxEntry,
          PrefetchHooks Function()
        > {
  $$SyncOutboxEntriesTableTableManager(
    _$AppDatabase db,
    $SyncOutboxEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<DateTime> changedAt = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion(
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                revision: revision,
                changedAt: changedAt,
                attemptCount: attemptCount,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entityType,
                required String entityId,
                required String operation,
                Value<int> revision = const Value.absent(),
                required DateTime changedAt,
                Value<int> attemptCount = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncOutboxEntriesCompanion.insert(
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                revision: revision,
                changedAt: changedAt,
                attemptCount: attemptCount,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncOutboxEntriesTable, SyncOutboxEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncOutboxEntriesTable,
                    SyncOutboxEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncOutboxEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncOutboxEntriesTable,
      SyncOutboxEntry,
      $$SyncOutboxEntriesTableFilterComposer,
      $$SyncOutboxEntriesTableOrderingComposer,
      $$SyncOutboxEntriesTableAnnotationComposer,
      $$SyncOutboxEntriesTableCreateCompanionBuilder,
      $$SyncOutboxEntriesTableUpdateCompanionBuilder,
      (
        SyncOutboxEntry,
        BaseReferences<_$AppDatabase, $SyncOutboxEntriesTable, SyncOutboxEntry>,
      ),
      SyncOutboxEntry,
      PrefetchHooks Function()
    >;
typedef $$AlgorithmTasksTableCreateCompanionBuilder =
    AlgorithmTasksCompanion Function({
      required String id,
      Value<String> operation,
      required String endpoint,
      required String inputPath,
      required String inputName,
      required int inputSizeBytes,
      required int inputDurationMs,
      Value<bool> ownsInput,
      Value<String?> recordingId,
      required String status,
      Value<String?> remoteJobId,
      Value<int?> progress,
      Value<String?> message,
      Value<String?> resultJson,
      Value<int> consecutiveFailures,
      Value<DateTime?> nextPollAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AlgorithmTasksTableUpdateCompanionBuilder =
    AlgorithmTasksCompanion Function({
      Value<String> id,
      Value<String> operation,
      Value<String> endpoint,
      Value<String> inputPath,
      Value<String> inputName,
      Value<int> inputSizeBytes,
      Value<int> inputDurationMs,
      Value<bool> ownsInput,
      Value<String?> recordingId,
      Value<String> status,
      Value<String?> remoteJobId,
      Value<int?> progress,
      Value<String?> message,
      Value<String?> resultJson,
      Value<int> consecutiveFailures,
      Value<DateTime?> nextPollAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AlgorithmTasksTableFilterComposer
    extends Composer<_$AppDatabase, $AlgorithmTasksTable> {
  $$AlgorithmTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputName => $composableBuilder(
    column: $table.inputName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputSizeBytes => $composableBuilder(
    column: $table.inputSizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputDurationMs => $composableBuilder(
    column: $table.inputDurationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ownsInput => $composableBuilder(
    column: $table.ownsInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteJobId => $composableBuilder(
    column: $table.remoteJobId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextPollAt => $composableBuilder(
    column: $table.nextPollAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlgorithmTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $AlgorithmTasksTable> {
  $$AlgorithmTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputPath => $composableBuilder(
    column: $table.inputPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputName => $composableBuilder(
    column: $table.inputName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputSizeBytes => $composableBuilder(
    column: $table.inputSizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputDurationMs => $composableBuilder(
    column: $table.inputDurationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ownsInput => $composableBuilder(
    column: $table.ownsInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteJobId => $composableBuilder(
    column: $table.remoteJobId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextPollAt => $composableBuilder(
    column: $table.nextPollAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlgorithmTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlgorithmTasksTable> {
  $$AlgorithmTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get inputPath =>
      $composableBuilder(column: $table.inputPath, builder: (column) => column);

  GeneratedColumn<String> get inputName =>
      $composableBuilder(column: $table.inputName, builder: (column) => column);

  GeneratedColumn<int> get inputSizeBytes => $composableBuilder(
    column: $table.inputSizeBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inputDurationMs => $composableBuilder(
    column: $table.inputDurationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get ownsInput =>
      $composableBuilder(column: $table.ownsInput, builder: (column) => column);

  GeneratedColumn<String> get recordingId => $composableBuilder(
    column: $table.recordingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get remoteJobId => $composableBuilder(
    column: $table.remoteJobId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);

  GeneratedColumn<String> get resultJson => $composableBuilder(
    column: $table.resultJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextPollAt => $composableBuilder(
    column: $table.nextPollAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AlgorithmTasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlgorithmTasksTable,
          AlgorithmTask,
          $$AlgorithmTasksTableFilterComposer,
          $$AlgorithmTasksTableOrderingComposer,
          $$AlgorithmTasksTableAnnotationComposer,
          $$AlgorithmTasksTableCreateCompanionBuilder,
          $$AlgorithmTasksTableUpdateCompanionBuilder,
          (
            AlgorithmTask,
            BaseReferences<_$AppDatabase, $AlgorithmTasksTable, AlgorithmTask>,
          ),
          AlgorithmTask,
          PrefetchHooks Function()
        > {
  $$AlgorithmTasksTableTableManager(
    _$AppDatabase db,
    $AlgorithmTasksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlgorithmTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlgorithmTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlgorithmTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> inputPath = const Value.absent(),
                Value<String> inputName = const Value.absent(),
                Value<int> inputSizeBytes = const Value.absent(),
                Value<int> inputDurationMs = const Value.absent(),
                Value<bool> ownsInput = const Value.absent(),
                Value<String?> recordingId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> remoteJobId = const Value.absent(),
                Value<int?> progress = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> nextPollAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlgorithmTasksCompanion(
                id: id,
                operation: operation,
                endpoint: endpoint,
                inputPath: inputPath,
                inputName: inputName,
                inputSizeBytes: inputSizeBytes,
                inputDurationMs: inputDurationMs,
                ownsInput: ownsInput,
                recordingId: recordingId,
                status: status,
                remoteJobId: remoteJobId,
                progress: progress,
                message: message,
                resultJson: resultJson,
                consecutiveFailures: consecutiveFailures,
                nextPollAt: nextPollAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> operation = const Value.absent(),
                required String endpoint,
                required String inputPath,
                required String inputName,
                required int inputSizeBytes,
                required int inputDurationMs,
                Value<bool> ownsInput = const Value.absent(),
                Value<String?> recordingId = const Value.absent(),
                required String status,
                Value<String?> remoteJobId = const Value.absent(),
                Value<int?> progress = const Value.absent(),
                Value<String?> message = const Value.absent(),
                Value<String?> resultJson = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<DateTime?> nextPollAt = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AlgorithmTasksCompanion.insert(
                id: id,
                operation: operation,
                endpoint: endpoint,
                inputPath: inputPath,
                inputName: inputName,
                inputSizeBytes: inputSizeBytes,
                inputDurationMs: inputDurationMs,
                ownsInput: ownsInput,
                recordingId: recordingId,
                status: status,
                remoteJobId: remoteJobId,
                progress: progress,
                message: message,
                resultJson: resultJson,
                consecutiveFailures: consecutiveFailures,
                nextPollAt: nextPollAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlgorithmTasksTable, AlgorithmTask>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AlgorithmTasksTable,
                    AlgorithmTask
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlgorithmTasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlgorithmTasksTable,
      AlgorithmTask,
      $$AlgorithmTasksTableFilterComposer,
      $$AlgorithmTasksTableOrderingComposer,
      $$AlgorithmTasksTableAnnotationComposer,
      $$AlgorithmTasksTableCreateCompanionBuilder,
      $$AlgorithmTasksTableUpdateCompanionBuilder,
      (
        AlgorithmTask,
        BaseReferences<_$AppDatabase, $AlgorithmTasksTable, AlgorithmTask>,
      ),
      AlgorithmTask,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PracticeSourcesTableTableManager get practiceSources =>
      $$PracticeSourcesTableTableManager(_db, _db.practiceSources);
  $$PracticeSegmentsTableTableManager get practiceSegments =>
      $$PracticeSegmentsTableTableManager(_db, _db.practiceSegments);
  $$PracticePlansTableTableManager get practicePlans =>
      $$PracticePlansTableTableManager(_db, _db.practicePlans);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
  $$PracticeRecordingsTableTableManager get practiceRecordings =>
      $$PracticeRecordingsTableTableManager(_db, _db.practiceRecordings);
  $$SyncOutboxEntriesTableTableManager get syncOutboxEntries =>
      $$SyncOutboxEntriesTableTableManager(_db, _db.syncOutboxEntries);
  $$AlgorithmTasksTableTableManager get algorithmTasks =>
      $$AlgorithmTasksTableTableManager(_db, _db.algorithmTasks);
}
