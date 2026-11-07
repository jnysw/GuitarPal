import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:guitar_pal/features/performance/performance_takes_screen.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';

void main() {
  testWidgets(
    'read failure never claims an empty library and explicit retry reaches actionable empty state',
    (tester) async {
      var fail = true;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const PerformanceTakesScreen(sourceId: 'song'),
          ),
          GoRoute(
            path: '/performance/prepare',
            builder: (_, state) => Scaffold(
              body: Text('准备 ${state.uri.queryParameters['sourceId']}'),
            ),
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              performanceDraftsProvider('song').overrideWith((ref) async => []),
              practiceRecordingsForSourceProvider('song').overrideWith(
                (ref) => fail
                    ? Stream.error(StateError('temporary'))
                    : Stream.value([]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('部分录音暂时无法读取'), findsOneWidget);
        expect(find.text('还没有演奏录音'), findsNothing);
        fail = false;
        await tester.tap(find.byKey(const Key('performance_takes_retry')));
        await tester.pumpAndSettle();
        expect(find.text('还没有演奏录音'), findsOneWidget);
        await tester.tap(find.byKey(const Key('performance_takes_prepare')));
        await tester.pumpAndSettle();
        expect(find.text('准备 song'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        router.dispose();
      }
    },
  );
}
