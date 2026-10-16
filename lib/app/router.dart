import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/create/create_practice_screen.dart';
import '../features/create/local_video_draft_screen.dart';
import '../features/home/home_screen.dart';
import '../features/inbox/domain/shared_item.dart';
import '../features/inbox/inbox_screen.dart';
import '../features/library/practice_library_screen.dart';
import '../features/library/practice_source_detail_screen.dart';
import '../features/plans/plan_overview_screen.dart';
import '../features/plans/plan_editor_screen.dart';
import '../features/player/practice_player_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/app_settings_screen.dart';
import '../features/recordings/presentation/plan_outcome_recordings_screen.dart';
import 'navigation/app_navigation_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/today',
  routes: [
    GoRoute(path: '/', redirect: (context, state) => '/today'),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppNavigationShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const PracticeLibraryScreen(),
              routes: [
                GoRoute(
                  path: 'source/:sourceId',
                  builder: (context, state) => PracticeSourceDetailScreen(
                    sourceId: state.pathParameters['sourceId']!,
                  ),
                  routes: [
                    GoRoute(
                      parentNavigatorKey: _rootNavigatorKey,
                      path: 'practice',
                      builder: (context, state) => PracticePlayerRouteScreen(
                        sourceId: state.pathParameters['sourceId']!,
                        segmentId: state.uri.queryParameters['segmentId'],
                        planId: state.uri.queryParameters['planId'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/plans',
              builder: (context, state) => const PlanOverviewScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const AppSettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/create',
      builder: (context, state) => CreatePracticeScreen(
        returnToPlan: state.uri.queryParameters['returnTo'] == 'plan',
      ),
      routes: [
        GoRoute(
          path: 'local/:draftId',
          builder: (context, state) => LocalVideoDraftScreen(
            draftId: state.pathParameters['draftId']!,
            returnToPlan: state.uri.queryParameters['returnTo'] == 'plan',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/inbox',
      builder: (context, state) {
        final item = state.extra;
        return InboxScreen(
          item: item is SharedItem
              ? item
              : _restoreSharedItem(state.uri.queryParameters['url']),
          returnToPlan: state.uri.queryParameters['returnTo'] == 'plan',
        );
      },
    ),
    GoRoute(
      path: '/plans/new',
      builder: (context, state) => PlanEditorScreen(
        initialSourceId: state.uri.queryParameters['sourceId'],
        initialSegmentId: state.uri.queryParameters['segmentId'],
      ),
    ),
    GoRoute(
      path: '/plans/:planId/edit',
      builder: (context, state) =>
          PlanEditorScreen(planId: state.pathParameters['planId']),
    ),
    GoRoute(
      path: '/plans/:planId/recordings',
      builder: (context, state) =>
          PlanOutcomeRecordingsScreen(planId: state.pathParameters['planId']!),
    ),
    GoRoute(
      path: '/practice/:sourceId',
      builder: (context, state) => PracticePlayerRouteScreen(
        sourceId: state.pathParameters['sourceId']!,
        segmentId: state.uri.queryParameters['segmentId'],
        planId: state.uri.queryParameters['planId'],
      ),
    ),
  ],
);

SharedItem _restoreSharedItem(String? value) {
  final uri = value == null ? null : Uri.tryParse(value);
  final isWebUri =
      uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty;
  return SharedItem(
    id: isWebUri ? 'restored-${value.hashCode}' : 'invalid',
    rawText: isWebUri ? value! : '',
    detectedUri: isWebUri ? uri : null,
    receivedAt: DateTime.now().toUtc(),
  );
}
