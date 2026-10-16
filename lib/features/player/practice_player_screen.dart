import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../library/practice_source_providers.dart';
import '../plans/practice_plan_providers.dart';
import '../profile/app_settings_providers.dart';
import '../segments/practice_segment_providers.dart';
import 'bilibili_web_player_screen.dart';
import 'local_video_player_screen.dart';

class PracticePlayerRouteScreen extends ConsumerWidget {
  const PracticePlayerRouteScreen({
    required this.sourceId,
    this.segmentId,
    this.planId,
    super.key,
  });

  final String sourceId;
  final String? segmentId;
  final String? planId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(practiceSourceByIdProvider(sourceId));
    return source.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) =>
          const _PlayerUnavailableView(message: '暂时无法读取练习内容，请返回后重试。'),
      data: (source) {
        if (source == null) {
          return const _PlayerUnavailableView(message: '这个练习内容不存在或已被删除。');
        }

        final requestedPlanId = planId;
        if (requestedPlanId != null) {
          final plan = ref.watch(practicePlanByIdProvider(requestedPlanId));
          return plan.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => _buildPlayer(ref, source),
            data: (plan) {
              final validPlan = plan?.sourceId == source.id ? plan : null;
              return _buildPlayer(
                ref,
                source,
                effectivePlanId: validPlan?.id,
                planSegmentId: validPlan?.segmentId,
                usePlanSegment: validPlan != null,
              );
            },
          );
        }

        return _buildPlayer(ref, source);
      },
    );
  }

  Widget _buildPlayer(
    WidgetRef ref,
    PracticeSource source, {
    String? effectivePlanId,
    String? planSegmentId,
    bool usePlanSegment = false,
  }) {
    final defaultPlaybackSpeed =
        ref.watch(appSettingsProvider).asData?.value.defaultPlaybackSpeed ??
        1.0;
    final requestedSegmentId = usePlanSegment ? planSegmentId : segmentId;
    if (requestedSegmentId == null) {
      return PracticePlayerScreen(
        source: source,
        planId: effectivePlanId,
        defaultPlaybackSpeed: defaultPlaybackSpeed,
      );
    }

    final segments = ref.watch(practiceSegmentsProvider(source.id));
    return segments.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => PracticePlayerScreen(
        source: source,
        planId: effectivePlanId,
        defaultPlaybackSpeed: defaultPlaybackSpeed,
      ),
      data: (items) {
        final initialSegment = items
            .where((segment) => segment.id == requestedSegmentId)
            .firstOrNull;
        return PracticePlayerScreen(
          source: source,
          initialSegment: initialSegment,
          planId: initialSegment == null ? null : effectivePlanId,
          defaultPlaybackSpeed: defaultPlaybackSpeed,
        );
      },
    );
  }
}

class PracticePlayerScreen extends StatelessWidget {
  const PracticePlayerScreen({
    required this.source,
    this.initialSegment,
    this.planId,
    this.defaultPlaybackSpeed = 1.0,
    super.key,
  });

  final PracticeSource source;
  final PracticeSegment? initialSegment;
  final String? planId;
  final double defaultPlaybackSpeed;

  @override
  Widget build(BuildContext context) {
    if (source.platform == SourcePlatform.local &&
        source.kind == SourceKind.video) {
      return LocalVideoPlayerScreen(
        source: source,
        initialSegment: initialSegment,
        planId: planId,
        defaultPlaybackSpeed: defaultPlaybackSpeed,
      );
    }

    if (source.platform == SourcePlatform.bilibili) {
      return BilibiliWebPlayerScreen(
        source: source,
        initialSegment: initialSegment,
        planId: planId,
        defaultPlaybackSpeed: defaultPlaybackSpeed,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(source.title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('这个来源目前使用引用模式，App 内播放器将在对应 Adapter 就绪后开放。'),
        ),
      ),
    );
  }
}

class _PlayerUnavailableView extends StatelessWidget {
  const _PlayerUnavailableView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('练习播放器')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
