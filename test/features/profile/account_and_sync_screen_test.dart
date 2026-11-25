import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/sync/sync_outbox.dart';
import 'package:guitar_pal/features/profile/account_and_sync_screen.dart';
import 'package:guitar_pal/features/profile/account_providers.dart';
import 'package:guitar_pal/features/profile/application/account_profile_repository.dart';
import 'package:guitar_pal/features/profile/application/auth_repository.dart';
import 'package:guitar_pal/features/profile/domain/account_profile.dart';
import 'package:guitar_pal/features/profile/domain/account_session.dart';
import 'package:guitar_pal/features/profile/domain/local_data_inventory.dart';

void main() {
  testWidgets('collects an email before starting a magic-link sign-in', (
    tester,
  ) async {
    final repository = _EmailAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          localDataInventoryProvider.overrideWithValue(
            const AsyncData(_emptyInventory),
          ),
          syncOutboxSummaryProvider.overrideWithValue(
            const AsyncData(SyncOutboxSummary.empty()),
          ),
        ],
        child: const MaterialApp(home: AccountAndSyncScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('account_email_sign_in')),
      300,
    );
    await tester.tap(find.byKey(const Key('account_email_sign_in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('account_email_field')),
      'player@example.com',
    );
    await tester.tap(find.byKey(const Key('account_email_continue')));
    await tester.pumpAndSettle();

    expect(repository.sentEmail, 'player@example.com');
    expect(find.textContaining('登录邮件已发送'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('starts only a configured sign-in method', (tester) async {
    final repository = _ConfiguredLocalAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          localDataInventoryProvider.overrideWithValue(
            const AsyncData(_emptyInventory),
          ),
          syncOutboxSummaryProvider.overrideWithValue(
            const AsyncData(SyncOutboxSummary.empty()),
          ),
        ],
        child: const MaterialApp(home: AccountAndSyncScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account_choose_sign_in')), findsOneWidget);
    await tester.tap(find.byKey(const Key('account_choose_sign_in')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('account_google_sign_in')),
      300,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('account_google_sign_in')),
        matching: find.text('可用'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('account_apple_sign_in')),
        matching: find.text('未配置'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('account_google_sign_in')));
    await tester.pumpAndSettle();
    expect(repository.startedMethods, [AccountSignInMethod.google]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'renders a signed-in session and keeps sign-out provider-neutral',
    (tester) async {
      final repository = _SignedInAuthRepository();
      const inventory = LocalDataInventory(
        sourceCount: 2,
        segmentCount: 3,
        planCount: 1,
        sessionCount: 8,
        recordingCount: 4,
        noteCount: 5,
        recordingDuration: Duration(minutes: 6),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(repository),
            localDataInventoryProvider.overrideWithValue(
              const AsyncData(inventory),
            ),
            syncOutboxSummaryProvider.overrideWithValue(
              const AsyncData(
                SyncOutboxSummary(pendingCount: 14, failedCount: 0),
              ),
            ),
          ],
          child: const MaterialApp(home: AccountAndSyncScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('木吉他练习者'), findsOneWidget);
      expect(find.text('player@example.com'), findsOneWidget);
      expect(find.byKey(const Key('account_sign_in_disabled')), findsNothing);
      expect(find.text('14 条练习数据可在登录后合并'), findsOneWidget);
      expect(find.text('14 项变更等待账号同步'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('account_inventory_recordings')),
          matching: find.text('录音 4'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('account_sign_out_button')));
      await tester.pumpAndSettle();
      expect(repository.signOutCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'edits avatar and unique ID then restores them in a new session view',
    (tester) async {
      final repository = _ProfileRepository();
      Widget accountScreen() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInAuthRepository()),
          accountProfileRepositoryProvider.overrideWithValue(repository),
          accountAvatarPickerProvider.overrideWithValue(() async => _avatar),
          localDataInventoryProvider.overrideWithValue(
            const AsyncData(_emptyInventory),
          ),
          syncOutboxSummaryProvider.overrideWithValue(
            const AsyncData(SyncOutboxSummary.empty()),
          ),
        ],
        child: const MaterialApp(home: AccountAndSyncScreen()),
      );
      await tester.pumpWidget(accountScreen());
      await tester.pumpAndSettle();
      final edit = find.byKey(const Key('account_edit_profile'));
      final field = find.byKey(const Key('account_profile_handle'));
      final save = find.byKey(const Key('account_save_profile'));
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account_pick_avatar')));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);

      await tester.enterText(field, 'x!');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.attempts, 0);
      await tester.enterText(field, 'Taken');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('此用户 ID 已被使用'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      await tester.enterText(field, '  Slow_Riff  ');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.attempts, 2);
      expect(repository.profile.handle, 'slow_riff');
      expect(repository.savedAvatar, _avatar);
      expect(find.text('@slow_riff'), findsOneWidget);
      expect(find.text('资料已保存'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(accountScreen());
      await tester.pumpAndSettle();
      expect(find.text('@slow_riff'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(find.text('移除头像'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repository.profile.avatarPath, isNull);
      expect(find.text('@slow_riff'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
}

final _avatar = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aVecAAAAASUVORK5CYII=',
);

final class _ProfileRepository implements AccountProfileRepository {
  AccountProfile profile = const AccountProfile(userId: 'user-1');
  Uint8List? savedAvatar;
  int attempts = 0;

  @override
  Future<AccountProfile> load(String userId) async {
    expect(userId, profile.userId);
    return profile;
  }

  @override
  Future<Uint8List> downloadAvatar(String path) async {
    expect(path, profile.avatarPath);
    return savedAvatar!;
  }

  @override
  Future<void> save(
    AccountProfile original, {
    required String handle,
    Uint8List? avatar,
    bool removeAvatar = false,
  }) async {
    expect(original, profile);
    attempts++;
    if (handle == 'taken') {
      throw const AccountProfileException('此用户 ID 已被使用', handleTaken: true);
    }
    savedAvatar = removeAvatar ? null : avatar ?? savedAvatar;
    profile = AccountProfile(
      userId: profile.userId,
      handle: handle,
      avatarPath: savedAvatar == null ? null : '${profile.userId}/avatar.png',
      revision: attempts,
    );
  }
}

const _emptyInventory = LocalDataInventory(
  sourceCount: 0,
  segmentCount: 0,
  planCount: 0,
  sessionCount: 0,
  recordingCount: 0,
  noteCount: 0,
  recordingDuration: Duration.zero,
);

final class _EmailAuthRepository implements AuthRepository {
  String? sentEmail;

  @override
  Set<AccountSignInMethod> get availableMethods => const {
    AccountSignInMethod.emailLink,
  };

  @override
  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  }) async {
    sentEmail = email;
    return AuthStartResult.emailLinkSent;
  }

  @override
  Future<void> signOut() async {}

  @override
  Stream<AccountSession> watchSession() =>
      Stream.value(const AccountSession.local());
}

final class _ConfiguredLocalAuthRepository implements AuthRepository {
  final List<AccountSignInMethod> startedMethods = [];

  @override
  Set<AccountSignInMethod> get availableMethods => const {
    AccountSignInMethod.google,
  };

  @override
  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  }) async {
    startedMethods.add(method);
    return AuthStartResult.browserOpened;
  }

  @override
  Future<void> signOut() async {}

  @override
  Stream<AccountSession> watchSession() => Stream.value(AccountSession.local());
}

final class _SignedInAuthRepository implements AuthRepository {
  int signOutCalls = 0;

  @override
  Set<AccountSignInMethod> get availableMethods => const {
    AccountSignInMethod.google,
  };

  @override
  Stream<AccountSession> watchSession() => Stream.value(
    AccountSession.signedIn(
      userId: 'user-1',
      email: 'player@example.com',
      displayName: '木吉他练习者',
      signInMethod: AccountSignInMethod.google,
    ),
  );

  @override
  Future<AuthStartResult> beginSignIn(
    AccountSignInMethod method, {
    String? email,
  }) async => AuthStartResult.browserOpened;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}
