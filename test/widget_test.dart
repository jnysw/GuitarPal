import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_pal/app/app.dart';
import 'package:guitar_pal/app/router.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/core/platform/local_video_gateway.dart';
import 'package:guitar_pal/core/platform/share_intent_gateway.dart';
import 'package:guitar_pal/core/platform/text_share_gateway.dart';
import 'package:guitar_pal/domain/practice_plan/calendar_date.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan.dart';
import 'package:guitar_pal/domain/practice_plan/practice_plan_repository.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording.dart';
import 'package:guitar_pal/domain/practice_recording/practice_recording_repository.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment.dart';
import 'package:guitar_pal/domain/practice_segment/practice_segment_repository.dart';
import 'package:guitar_pal/domain/practice_session/practice_session.dart';
import 'package:guitar_pal/domain/practice_session/practice_session_repository.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart';
import 'package:guitar_pal/domain/practice_source/practice_source_repository.dart';
import 'package:guitar_pal/features/create/application/local_video_draft_store.dart';
import 'package:guitar_pal/features/create/local_video_providers.dart';
import 'package:guitar_pal/features/library/practice_source_providers.dart';
import 'package:guitar_pal/features/plans/practice_plan_providers.dart';
import 'package:guitar_pal/features/recordings/practice_recording_providers.dart';
import 'package:guitar_pal/features/segments/practice_segment_providers.dart';
import 'package:guitar_pal/media/metadata/source_metadata.dart';
import 'package:guitar_pal/media/metadata/source_metadata_providers.dart';

void main() {
  setUp(() => appRouter.go('/'));

  testWidgets('home shows the dashboard inside the primary navigation', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_MemoryPracticeSourceRepository()));
    await tester.pumpAndSettle();

    expect(find.text('准备开始今天的练习'), findsOneWidget);
    expect(find.text('今天想练什么？'), findsOneWidget);
    expect(find.text('今日计划'), findsOneWidget);
    expect(find.text('最近添加'), findsOneWidget);
    expect(find.text('练习库还是空的'), findsOneWidget);
    expect(find.byKey(const Key('today_create_practice')), findsOneWidget);
    expect(find.byKey(const Key('navigation_today')), findsOneWidget);
    expect(find.byKey(const Key('navigation_library')), findsOneWidget);
    expect(find.byKey(const Key('navigation_create')), findsOneWidget);
    expect(find.byKey(const Key('navigation_plans')), findsOneWidget);
    expect(find.byKey(const Key('navigation_profile')), findsOneWidget);
  });

  testWidgets('global create action imports a shared link into the library', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('navigation_create')));
    await tester.pumpAndSettle();

    expect(find.text('新建练习'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('create_share_text_field')),
      '教程 https://www.bilibili.com/video/BV1create123',
    );
    await tester.tap(find.byKey(const Key('create_continue_button')));
    await tester.pumpAndSettle();

    expect(find.text('添加到 GuitarPal'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('shared_source_title')),
      'Alternate picking',
    );
    await tester.tap(find.byKey(const Key('save_shared_source')));
    await tester.pumpAndSettle();

    expect(repository.sources, hasLength(1));
    expect(repository.sources.single.title, 'Alternate picking');
    expect(find.text('练习详情'), findsOneWidget);
    expect(find.text('开始练习'), findsOneWidget);
  });

  testWidgets('primary destinations switch without becoming create pages', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(_MemoryPracticeSourceRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('navigation_plans')));
    await tester.pumpAndSettle();
    expect(find.text('练习计划'), findsOneWidget);
    expect(find.text('还没有练习计划'), findsOneWidget);

    await tester.tap(find.byKey(const Key('navigation_profile')));
    await tester.pumpAndSettle();
    expect(find.text('个人中心'), findsOneWidget);
    expect(find.text('本地练习空间'), findsOneWidget);

    await tester.ensureVisible(find.text('应用设置'));
    await tester.tap(find.text('应用设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题模式'), findsOneWidget);
    expect(find.text('默认练习倍速'), findsOneWidget);

    await tester.tap(find.byKey(const Key('navigation_today')));
    await tester.pumpAndSettle();
    expect(find.text('准备开始今天的练习'), findsOneWidget);
  });

  testWidgets('profile shows lifetime metrics and switches trend ranges', (
    tester,
  ) async {
    final sourceRepository = _MemoryPracticeSourceRepository();
    final sessionRepository = _MemoryPracticeSessionRepository();
    final today = CalendarDate(2026, 10, 14);
    final now = DateTime.utc(2026, 10, 14, 9);
    sourceRepository.sources.addAll([
      PracticeSource(
        id: 'completed-profile-source',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '已完成曲目',
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      PracticeSource(
        id: 'pending-profile-source',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.video,
        title: '待练曲目',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    sessionRepository.sessions.addAll([
      PracticeSession(
        id: 'profile-session-today',
        sourceId: 'completed-profile-source',
        practiceDate: today,
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 20)),
        activeDuration: const Duration(minutes: 20),
        loopCount: 4,
        completed: true,
      ),
      PracticeSession(
        id: 'profile-session-yesterday',
        sourceId: 'pending-profile-source',
        practiceDate: today.addDays(-1),
        startedAt: now.subtract(const Duration(days: 1)),
        endedAt: now
            .subtract(const Duration(days: 1))
            .add(const Duration(minutes: 25)),
        activeDuration: const Duration(minutes: 25),
        loopCount: 3,
        completed: true,
      ),
    ]);
    appRouter.go('/profile');
    await tester.pumpWidget(
      _testApp(
        sourceRepository,
        sessionRepository: sessionRepository,
        currentDate: today,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('训练反馈'), findsOneWidget);
    expect(find.byKey(const Key('profile_practice_trend')), findsOneWidget);
    expect(find.byKey(const Key('profile_trend_bar_13')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile_total_duration')),
        matching: find.text('45 分钟'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile_completed_sources')),
        matching: find.text('1 / 2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile_current_streak')),
        matching: find.text('2 天'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('12 周'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_trend_bar_11')), findsOneWidget);
    expect(find.byKey(const Key('profile_trend_bar_13')), findsNothing);
  });

  testWidgets(
    'creating content from an empty plan editor returns with it selected',
    (tester) async {
      final repository = _MemoryPracticeSourceRepository();
      appRouter.go('/plans/new');
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      expect(find.text('还没有可加入计划的练习'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('plan_editor_create_practice_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('保存后会返回新建计划，并自动选中这项练习。'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('create_share_text_field')),
        'https://www.bilibili.com/video/BV1planreturn',
      );
      await tester.tap(find.byKey(const Key('create_continue_button')));
      await tester.pumpAndSettle();

      expect(find.text('保存并加入计划'), findsOneWidget);
      expect(find.byKey(const Key('start_shared_source')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('shared_source_title')),
        '计划中新建的练习',
      );
      await tester.tap(find.byKey(const Key('save_shared_source')));
      await tester.pumpAndSettle();

      expect(repository.sources, hasLength(1));
      expect(find.text('新建计划'), findsOneWidget);
      expect(find.byKey(const Key('plan_name_field')), findsOneWidget);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const Key('plan_source_dropdown')),
      );
      expect(dropdown.initialValue, repository.sources.single.id);
      expect(find.textContaining('计划中新建的练习'), findsWidgets);
    },
  );

  testWidgets(
    'leaving local video confirmation returns to create and cleans draft',
    (tester) async {
      final repository = _MemoryPracticeSourceRepository();
      final gateway = _FakeLocalVideoGateway();
      final draftStore = LocalVideoDraftStore();
      final draft = draftStore.create(
        origin: LocalVideoPickOrigin.gallery,
        file: const LocalVideoFileInfo(
          path: '/cache/guitarpal_video_drafts/navigation-test.mp4',
          displayName: 'navigation-test.mp4',
          sizeBytes: 1024,
          duration: Duration(seconds: 5),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseReadyProvider.overrideWith((ref) async {}),
            practiceSourceRepositoryProvider.overrideWithValue(repository),
            practiceSegmentRepositoryProvider.overrideWithValue(
              _MemoryPracticeSegmentRepository(),
            ),
            practicePlanRepositoryProvider.overrideWithValue(
              _MemoryPracticePlanRepository(),
            ),
            practiceSessionRepositoryProvider.overrideWithValue(
              _MemoryPracticeSessionRepository(),
            ),
            practiceRecordingRepositoryProvider.overrideWithValue(
              _MemoryPracticeRecordingRepository(),
            ),
            shareIntentGatewayProvider.overrideWithValue(
              _FakeShareIntentGateway(null),
            ),
            localVideoGatewayProvider.overrideWithValue(gateway),
            localVideoDraftStoreProvider.overrideWithValue(draftStore),
          ],
          child: const GuitarPalApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('navigation_create')));
      await tester.pumpAndSettle();
      appRouter.push('/create/local/${draft.id}');
      await tester.pumpAndSettle();

      expect(find.text('确认本地视频'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('新建练习'), findsOneWidget);
      expect(gateway.discardedDraftPaths, [draft.file.path]);
      expect(draftStore.getById(draft.id), isNull);
    },
  );

  testWidgets('initial Android share can be confirmed and saved', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseReadyProvider.overrideWith((ref) async {}),
          shareIntentGatewayProvider.overrideWithValue(
            _FakeShareIntentGateway(
              '看看这个 https://www.bilibili.com/video/BV1abc123?utm_source=test',
            ),
          ),
          practiceSourceRepositoryProvider.overrideWithValue(repository),
          practiceSegmentRepositoryProvider.overrideWithValue(
            _MemoryPracticeSegmentRepository(),
          ),
          practicePlanRepositoryProvider.overrideWithValue(
            _MemoryPracticePlanRepository(),
          ),
          practiceSessionRepositoryProvider.overrideWithValue(
            _MemoryPracticeSessionRepository(),
          ),
          practiceRecordingRepositoryProvider.overrideWithValue(
            _MemoryPracticeRecordingRepository(),
          ),
          sourceMetadataLoaderProvider.overrideWithValue(
            const NoopSourceMetadataLoader(),
          ),
        ],
        child: const GuitarPalApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加到 GuitarPal'), findsOneWidget);
    expect(find.text('Bilibili'), findsOneWidget);
    expect(find.text('可打开原内容'), findsOneWidget);
    expect(find.text('App 内播放'), findsOneWidget);
    expect(find.text('A-B Loop'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save_shared_source')));
    await tester.pumpAndSettle();

    expect(repository.sources, hasLength(1));
    expect(repository.sources.single.platform, SourcePlatform.bilibili);
    expect(repository.sources.single.externalId, 'BV1abc123');
    expect(
      repository.sources.single.canonicalUri.toString(),
      'https://www.bilibili.com/video/BV1abc123',
    );
  });

  testWidgets('inbox restores its pending URL without route extra', (
    tester,
  ) async {
    final location = Uri(
      path: '/inbox',
      queryParameters: {'url': 'https://www.bilibili.com/video/BV1restored123'},
    ).toString();
    appRouter.go(location);

    await tester.pumpWidget(_testApp(_MemoryPracticeSourceRepository()));
    await tester.pumpAndSettle();

    expect(find.text('添加到 GuitarPal'), findsOneWidget);
    expect(find.text('内容 ID：BV1restored123'), findsOneWidget);
    final startButton = tester.widget<FilledButton>(
      find.byKey(const Key('start_shared_source')),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('practice library searches saved sources', (tester) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 12);
    repository.sources.addAll([
      PracticeSource(
        id: 'bilibili-source',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: '指弹练习',
        externalId: 'BV1search',
        createdAt: now,
        updatedAt: now,
      ),
      PracticeSource(
        id: 'youtube-source',
        platform: SourcePlatform.youtube,
        kind: SourceKind.webReference,
        title: 'Alternate Picking',
        note: '注意跨弦时的右手角度',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    appRouter.go('/library');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('指弹练习'), findsOneWidget);
    expect(find.text('Alternate Picking'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('library_search_field')),
      'BV1search',
    );
    await tester.pump();

    expect(find.text('指弹练习'), findsOneWidget);
    expect(find.text('Alternate Picking'), findsNothing);
    expect(find.text('找到 1 项'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('library_search_field')),
      '右手角度',
    );
    await tester.pump();

    expect(find.text('指弹练习'), findsNothing);
    expect(find.text('Alternate Picking'), findsOneWidget);
    expect(find.text('曲目笔记'), findsOneWidget);
  });

  testWidgets(
    'practice library combines platform, completion, and plan filters',
    (tester) async {
      final repository = _MemoryPracticeSourceRepository();
      final planRepository = _MemoryPracticePlanRepository();
      final now = DateTime.utc(2026, 10, 14, 9);
      repository.sources.addAll([
        PracticeSource(
          id: 'planned-completed-bilibili',
          platform: SourcePlatform.bilibili,
          kind: SourceKind.webReference,
          title: '已完成的计划曲目',
          completedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
        PracticeSource(
          id: 'pending-bilibili',
          platform: SourcePlatform.bilibili,
          kind: SourceKind.webReference,
          title: '待练 B站曲目',
          createdAt: now,
          updatedAt: now,
        ),
        PracticeSource(
          id: 'completed-youtube',
          platform: SourcePlatform.youtube,
          kind: SourceKind.webReference,
          title: '已完成 YouTube 曲目',
          completedAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      planRepository.plans.add(
        PracticePlan(
          id: 'plan-1',
          name: '关联计划',
          sourceId: 'planned-completed-bilibili',
          goal: const PracticeGoal.loops(5),
          startDate: CalendarDate(2026, 10, 14),
          endDate: CalendarDate(2026, 10, 31),
          repeatWeekdays: const {1, 2, 3, 4, 5, 6, 7},
          createdAt: now,
          updatedAt: now,
        ),
      );
      appRouter.go('/library');
      await tester.pumpWidget(
        _testApp(repository, planRepository: planRepository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('library_filter_button')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('library_filter_platform_bilibili')),
      );
      await tester.tap(
        find.byKey(const Key('library_filter_completion_completed')),
      );
      await tester.tap(find.byKey(const Key('library_filter_plan_planned')));
      await tester.ensureVisible(
        find.byKey(const Key('library_apply_filters')),
      );
      await tester.tap(find.byKey(const Key('library_apply_filters')));
      await tester.pumpAndSettle();

      expect(find.text('已完成的计划曲目'), findsOneWidget);
      expect(find.text('待练 B站曲目'), findsNothing);
      expect(find.text('已完成 YouTube 曲目'), findsNothing);
      expect(find.text('找到 1 项'), findsOneWidget);
      expect(find.text('筛选 3'), findsOneWidget);
    },
  );

  testWidgets('practice library can mark a source completed and reopen it', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 14, 9);
    repository.sources.add(
      PracticeSource(
        id: 'completion-source',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '完成状态练习',
        createdAt: now,
        updatedAt: now,
      ),
    );
    appRouter.go('/library');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('待练'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为完成'));
    await tester.pumpAndSettle();

    expect(repository.sources.single.isCompleted, isTrue);
    expect(find.text('已完成'), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('移回待练'));
    await tester.pumpAndSettle();

    expect(repository.sources.single.isCompleted, isFalse);
    expect(find.text('待练'), findsOneWidget);
  });

  testWidgets('practice library renames and deletes a source', (tester) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 12);
    repository.sources.add(
      PracticeSource(
        id: 'editable-source',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: '待整理练习',
        createdAt: now,
        updatedAt: now,
      ),
    );
    appRouter.go('/library');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('library_rename_field')),
      '已整理练习',
    );
    await tester.tap(find.byKey(const Key('library_confirm_rename')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.sources.single.title, '已整理练习');

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_confirm_delete')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.sources, isEmpty);
  });

  testWidgets('source detail safely renames a persisted source', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 12);
    repository.sources.add(
      PracticeSource(
        id: 'detail-source',
        platform: SourcePlatform.bilibili,
        kind: SourceKind.webReference,
        title: '详情页旧名称',
        externalId: 'BV1detail',
        canonicalUri: Uri.parse('https://www.bilibili.com/video/BV1detail'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    appRouter.go('/library/source/detail-source');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source_detail_information')), findsOneWidget);
    expect(find.text('来源信息'), findsOneWidget);
    expect(find.text('www.bilibili.com'), findsOneWidget);
    expect(find.byKey(const Key('source_detail_copy_url')), findsOneWidget);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('source_detail_rename_field')),
      '详情页新名称',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.sources.single.title, '详情页新名称');
    expect(find.text('详情页新名称'), findsOneWidget);
  });

  testWidgets('source detail toggles the explicit completion state', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 14, 9);
    repository.sources.add(
      PracticeSource(
        id: 'detail-completion-source',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '详情完成状态',
        createdAt: now,
        updatedAt: now,
      ),
    );
    appRouter.go('/library/source/detail-completion-source');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('待练'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('标记为完成'));
    await tester.pumpAndSettle();

    expect(repository.sources.single.isCompleted, isTrue);
    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets('source detail adds, edits, and clears an overall note', (
    tester,
  ) async {
    final repository = _MemoryPracticeSourceRepository();
    final now = DateTime.utc(2026, 10, 14, 9);
    repository.sources.add(
      PracticeSource(
        id: 'detail-note-source',
        platform: SourcePlatform.local,
        kind: SourceKind.video,
        title: '曲目笔记练习',
        createdAt: now,
        updatedAt: now,
      ),
    );
    appRouter.go('/library/source/detail-note-source');
    await tester.pumpWidget(_testApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('source_detail_note')), findsOneWidget);
    expect(find.text('曲目笔记'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('source_note_edit')));
    await tester.tap(find.byKey(const Key('source_note_edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('source_note_field')),
      '保持右手放松\n下次从 0.75x 开始',
    );
    await tester.tap(find.byKey(const Key('source_note_save')));
    await tester.pumpAndSettle();

    expect(repository.sources.single.note, '保持右手放松\n下次从 0.75x 开始');
    expect(find.textContaining('保持右手放松'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('source_note_edit')));
    await tester.tap(find.byKey(const Key('source_note_edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('source_note_clear')));
    await tester.pumpAndSettle();

    expect(repository.sources.single.note, isNull);
    expect(find.textContaining('记录整首曲目的练习目标'), findsOneWidget);
  });

  testWidgets(
    'source detail exports source and segment notes with system share',
    (tester) async {
      final repository = _MemoryPracticeSourceRepository();
      final segmentRepository = _MemoryPracticeSegmentRepository();
      final shareGateway = _FakeTextShareGateway();
      final now = DateTime.utc(2026, 10, 14, 9);
      repository.sources.add(
        PracticeSource(
          id: 'detail-export-source',
          platform: SourcePlatform.bilibili,
          kind: SourceKind.video,
          title: '导出测试曲目',
          originalUri: Uri.parse('https://www.bilibili.com/video/BV1export'),
          note: '整曲先保持放松',
          createdAt: now,
          updatedAt: now,
        ),
      );
      segmentRepository.segments.add(
        PracticeSegment(
          id: 'detail-export-segment',
          sourceId: 'detail-export-source',
          title: '主歌换把',
          start: const Duration(seconds: 12, milliseconds: 250),
          end: const Duration(seconds: 18, milliseconds: 750),
          note: '食指提前准备',
          preferredSpeed: 0.73,
          createdAt: now,
          updatedAt: now,
        ),
      );
      appRouter.go('/library/source/detail-export-source');
      await tester.pumpWidget(
        _testApp(
          repository,
          segmentRepository: segmentRepository,
          textShareGateway: shareGateway,
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('source_note_export')));
      await tester.tap(find.byKey(const Key('source_note_export')));
      await tester.pumpAndSettle();

      expect(find.text('导出练习笔记'), findsOneWidget);
      expect(find.textContaining('1 个片段笔记'), findsOneWidget);
      await tester.tap(find.byKey(const Key('source_note_export_share')));
      await tester.pumpAndSettle();

      expect(shareGateway.subject, '导出测试曲目 · GuitarPal 练习笔记');
      expect(shareGateway.text, contains('整曲先保持放松'));
      expect(shareGateway.text, contains('### 主歌换把'));
      expect(shareGateway.text, contains('0:12.250 – 0:18.750'));
      expect(shareGateway.text, contains('0.73x'));
      expect(shareGateway.text, contains('食指提前准备'));
    },
  );
}

Widget _testApp(
  _MemoryPracticeSourceRepository repository, {
  _MemoryPracticePlanRepository? planRepository,
  _MemoryPracticeSegmentRepository? segmentRepository,
  _MemoryPracticeSessionRepository? sessionRepository,
  CalendarDate? currentDate,
  TextShareGateway? textShareGateway,
}) {
  return ProviderScope(
    overrides: [
      databaseReadyProvider.overrideWith((ref) async {}),
      practiceSourceRepositoryProvider.overrideWithValue(repository),
      practiceSegmentRepositoryProvider.overrideWithValue(
        segmentRepository ?? _MemoryPracticeSegmentRepository(),
      ),
      practicePlanRepositoryProvider.overrideWithValue(
        planRepository ?? _MemoryPracticePlanRepository(),
      ),
      practiceSessionRepositoryProvider.overrideWithValue(
        sessionRepository ?? _MemoryPracticeSessionRepository(),
      ),
      practiceRecordingRepositoryProvider.overrideWithValue(
        _MemoryPracticeRecordingRepository(),
      ),
      if (currentDate != null)
        currentCalendarDateProvider.overrideWithValue(currentDate),
      shareIntentGatewayProvider.overrideWithValue(
        _FakeShareIntentGateway(null),
      ),
      textShareGatewayProvider.overrideWithValue(
        textShareGateway ?? _FakeTextShareGateway(),
      ),
      sourceMetadataLoaderProvider.overrideWithValue(
        const NoopSourceMetadataLoader(),
      ),
    ],
    child: const GuitarPalApp(),
  );
}

class _FakeShareIntentGateway implements ShareIntentGateway {
  _FakeShareIntentGateway(this.initialText);

  final String? initialText;

  @override
  Stream<String> get sharedTextStream => const Stream.empty();

  @override
  Future<String?> takeInitialSharedText() async => initialText;

  @override
  void dispose() {}
}

class _FakeTextShareGateway implements TextShareGateway {
  String? subject;
  String? text;
  TextShareResult result = TextShareResult.opened;

  @override
  Future<TextShareResult> share({
    required String subject,
    required String text,
  }) async {
    this.subject = subject;
    this.text = text;
    return result;
  }
}

class _FakeLocalVideoGateway implements LocalVideoGateway {
  final List<String> discardedDraftPaths = [];

  @override
  Future<LocalVideoFileInfo> commitDraft({
    required String draftPath,
    required String sourceId,
  }) {
    throw UnsupportedError('Not used by this test');
  }

  @override
  Future<void> deleteManagedVideo(String path) async {}

  @override
  Future<void> discardDraft(String draftPath) async {
    discardedDraftPaths.add(draftPath);
  }

  @override
  Future<LocalVideoFileInfo?> pickVideo(LocalVideoPickOrigin origin) {
    throw UnsupportedError('Not used by this test');
  }
}

class _MemoryPracticeSourceRepository implements PracticeSourceRepository {
  final List<PracticeSource> sources = [];

  @override
  Future<void> delete(String id) async {
    sources.removeWhere((source) => source.id == id);
  }

  @override
  Future<PracticeSource?> getById(String id) async {
    return sources.where((source) => source.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSource source) async {
    final index = sources.indexWhere((item) => item.id == source.id);
    if (index == -1) {
      sources.add(source);
    } else {
      sources[index] = source;
    }
  }

  @override
  Stream<List<PracticeSource>> watchAll() => Stream.value(List.of(sources));
}

class _MemoryPracticeSegmentRepository implements PracticeSegmentRepository {
  final List<PracticeSegment> segments = [];

  @override
  Future<void> delete(String id) async {
    segments.removeWhere((segment) => segment.id == id);
  }

  @override
  Future<PracticeSegment?> getById(String id) async {
    return segments.where((segment) => segment.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeSegment segment) async {
    final index = segments.indexWhere((item) => item.id == segment.id);
    if (index == -1) {
      segments.add(segment);
    } else {
      segments[index] = segment;
    }
  }

  @override
  Stream<List<PracticeSegment>> watchBySource(String sourceId) {
    return Stream.value(
      segments.where((segment) => segment.sourceId == sourceId).toList(),
    );
  }
}

class _MemoryPracticePlanRepository implements PracticePlanRepository {
  final List<PracticePlan> plans = [];

  @override
  Future<void> delete(String id) async {
    plans.removeWhere((plan) => plan.id == id);
  }

  @override
  Future<PracticePlan?> getById(String id) async {
    return plans.where((plan) => plan.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticePlan plan) async {
    final index = plans.indexWhere((item) => item.id == plan.id);
    if (index == -1) {
      plans.add(plan);
    } else {
      plans[index] = plan;
    }
  }

  @override
  Stream<List<PracticePlan>> watchAll() => Stream.value(List.of(plans));

  @override
  Stream<List<PracticePlan>> watchScheduledFor(CalendarDate date) {
    return Stream.value(
      plans.where((plan) => plan.isScheduledOn(date)).toList(),
    );
  }
}

class _MemoryPracticeSessionRepository implements PracticeSessionRepository {
  final List<PracticeSession> sessions = [];

  @override
  Stream<List<PracticeSession>> watchAll() => Stream.value(List.of(sessions));

  @override
  Future<void> save(PracticeSession session) async {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) {
      sessions.add(session);
    } else {
      sessions[index] = session;
    }
  }

  @override
  Stream<List<PracticeSession>> watchBetween(
    CalendarDate start,
    CalendarDate end,
  ) {
    return Stream.value(
      sessions
          .where(
            (session) =>
                session.practiceDate >= start && session.practiceDate <= end,
          )
          .toList(),
    );
  }

  @override
  Stream<List<PracticeSession>> watchForDate(CalendarDate date) {
    return Stream.value(
      sessions.where((session) => session.practiceDate == date).toList(),
    );
  }
}

class _MemoryPracticeRecordingRepository
    implements PracticeRecordingRepository {
  final List<PracticeRecording> recordings = [];

  @override
  Future<void> delete(String id) async {
    recordings.removeWhere((recording) => recording.id == id);
  }

  @override
  Future<PracticeRecording?> getById(String id) async {
    return recordings.where((recording) => recording.id == id).firstOrNull;
  }

  @override
  Future<void> save(PracticeRecording recording) async {
    recordings.removeWhere((item) => item.id == recording.id);
    recordings.add(recording);
  }

  @override
  Stream<List<PracticeRecording>> watchAll() {
    return Stream.value(List.of(recordings));
  }

  @override
  Stream<List<PracticeRecording>> watchByPlan(String planId) {
    return Stream.value(
      recordings.where((recording) => recording.planId == planId).toList(),
    );
  }

  @override
  Stream<List<PracticeRecording>> watchBySource(String sourceId) {
    return Stream.value(
      recordings.where((recording) => recording.sourceId == sourceId).toList(),
    );
  }
}
