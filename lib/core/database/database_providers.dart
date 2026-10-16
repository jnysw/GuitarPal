import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

final databaseReadyProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(databaseProvider);
  await database.customSelect('SELECT 1').getSingle();
});
