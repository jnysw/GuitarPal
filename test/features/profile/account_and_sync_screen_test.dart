import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/core/sync/sync_outbox.dart';
import 'package:guitar_pal/features/profile/account_and_sync_screen.dart';
import 'package:guitar_pal/features/profile/account_providers.dart';
import 'package:guitar_pal/features/profile/application/auth_repository.dart';
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
