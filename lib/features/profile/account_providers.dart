import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/sync/drift_sync_outbox_repository.dart';
import '../../core/sync/sync_outbox.dart';
import '../library/practice_source_providers.dart';
import '../plans/practice_plan_providers.dart';
import '../recordings/practice_recording_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'application/account_profile_repository.dart';
import 'application/auth_repository.dart';
import 'data/account_avatar_picker.dart';
import 'data/local_only_auth_repository.dart';
import 'domain/account_profile.dart';
import 'domain/account_session.dart';
import 'domain/local_data_inventory.dart';
import 'practice_insights_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return const LocalOnlyAuthRepository();
});

final accountSessionProvider = StreamProvider<AccountSession>((ref) {
  return ref.watch(authRepositoryProvider).watchSession();
});

final accountProfileRepositoryProvider = Provider<AccountProfileRepository?>(
  (ref) => null,
);

final accountProfileProvider = FutureProvider.autoDispose
    .family<AccountProfile, String>((ref, userId) {
      return ref.watch(accountProfileRepositoryProvider)!.load(userId);
    }, retry: (_, _) => null);

final accountAvatarProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, path) {
      return ref.watch(accountProfileRepositoryProvider)!.downloadAvatar(path);
    });

final accountAvatarPickerProvider = Provider<Future<Uint8List?> Function()>(
  (ref) => pickAccountAvatar,
);

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  return DriftSyncOutboxRepository(ref.watch(databaseProvider));
});

final syncOutboxSummaryProvider = StreamProvider<SyncOutboxSummary>((ref) {
  return ref.watch(syncOutboxRepositoryProvider).watchSummary();
});

final localDataInventoryProvider = Provider<AsyncValue<LocalDataInventory>>((
  ref,
) {
  final sources = ref.watch(practiceSourcesProvider);
  final segments = ref.watch(allPracticeSegmentsProvider);
  final plans = ref.watch(practicePlansProvider);
  final sessions = ref.watch(allPracticeSessionsProvider);
  final recordings = ref.watch(practiceRecordingsProvider);

  final values = <AsyncValue<Object?>>[
    sources,
    segments,
    plans,
    sessions,
    recordings,
  ];
  for (final value in values) {
    if (value case AsyncError(:final error, :final stackTrace)) {
      return AsyncError(error, stackTrace);
    }
  }
  if (values.any((value) => !value.hasValue)) {
    return const AsyncLoading();
  }
  return AsyncData(
    LocalDataInventory.calculate(
      sources: sources.requireValue,
      segments: segments.requireValue,
      plans: plans.requireValue,
      sessions: sessions.requireValue,
      recordings: recordings.requireValue,
    ),
  );
});
