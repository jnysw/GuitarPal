import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_source/practice_source.dart';
import '../../domain/practice_plan/calendar_date.dart';
import '../../domain/practice_plan/practice_plan.dart';
import '../../domain/practice_plan/practice_plan_progress.dart';
import '../library/practice_source_providers.dart';
import '../plans/practice_plan_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(practiceSourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('今日')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TodayHeader(),
                  const SizedBox(height: 18),
                  const _QuickStartCard(),
                  const SizedBox(height: 14),
                  const _TodayPlanCard(),
                  const SizedBox(height: 22),
                  _RecentSourcesSection(sources: sources),
                  const SizedBox(height: 14),
                  const _TodayProgressCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayHeader extends ConsumerWidget {
  const _TodayHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final today = ref.watch(currentCalendarDateProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 27,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: const Icon(Icons.music_note_rounded, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '准备开始今天的练习',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _formatToday(today),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  const _QuickStartCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.inverseSurface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 36,
              color: colors.inversePrimary,
            ),
            const SizedBox(height: 14),
            Text(
              '今天想练什么？',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onInverseSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '添加一个教程，或从练习库继续上次保存的内容和片段。',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onInverseSurface.withValues(alpha: 0.78),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  key: const Key('today_create_practice'),
                  onPressed: () => context.push('/create'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.inversePrimary,
                    foregroundColor: colors.onPrimaryContainer,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建练习'),
                ),
                OutlinedButton.icon(
                  key: const Key('today_open_library'),
                  onPressed: () => context.go('/library'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.onInverseSurface,
                    side: BorderSide(
                      color: colors.onInverseSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  icon: const Icon(Icons.library_music_outlined),
                  label: const Text('打开练习库'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPlanCard extends ConsumerWidget {
  const _TodayPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final progress = ref.watch(todayPlanProgressProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: progress.when(
          loading: () => const SizedBox(
            height: 72,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (_, _) => _TodayPlanMessage(
            icon: Icons.sync_problem_outlined,
            title: '暂时无法读取今日计划',
            message: '可以前往计划页重试。',
            actionLabel: '查看',
            onAction: () => context.go('/plans'),
          ),
          data: (items) {
            if (items.isEmpty) {
              return _TodayPlanMessage(
                icon: Icons.event_available_outlined,
                title: '今日计划',
                message: '今天还没有练习安排。创建计划后，符合日期和星期的任务会出现在这里。',
                actionLabel: '创建计划',
                onAction: () => context.push('/plans/new'),
              );
            }
            final completed = items.where((item) => item.isComplete).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_note_rounded, color: colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '今日计划',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('$completed / ${items.length} 已完成'),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: completed / items.length,
                  borderRadius: BorderRadius.circular(99),
                ),
                const SizedBox(height: 10),
                for (final item in items.take(3))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      item.isComplete
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.isComplete
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      item.plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_goalProgressLabel(item)),
                    onTap: () => context.go('/plans'),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('today_view_plans'),
                    onPressed: () => context.go('/plans'),
                    child: const Text('管理与记录'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodayPlanMessage extends StatelessWidget {
  const _TodayPlanMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.primary, size: 30),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _RecentSourcesSection extends StatelessWidget {
  const _RecentSourcesSection({required this.sources});

  final AsyncValue<List<PracticeSource>> sources;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近添加',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              key: const Key('open_practice_library'),
              onPressed: () => context.go('/library'),
              child: const Text('查看全部'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: sources.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  '暂时无法读取练习库，请稍后重试。',
                  style: TextStyle(color: colors.error),
                ),
              ),
              data: (items) {
                if (items.isEmpty) return const _EmptyRecentSources();
                return Column(
                  children: items
                      .take(4)
                      .map(
                        (source) => _RecentSourceTile(
                          source: source,
                          onTap: () => context.go(
                            '/library/source/${Uri.encodeComponent(source.id)}',
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRecentSources extends StatelessWidget {
  const _EmptyRecentSources();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        children: [
          Icon(Icons.library_music_outlined, size: 38, color: colors.outline),
          const SizedBox(height: 10),
          Text(
            '练习库还是空的',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '导入本地视频、分享平台链接，或点击“新建练习”手动添加。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.push('/create'),
            icon: const Icon(Icons.add_link_rounded),
            label: const Text('添加第一个练习'),
          ),
        ],
      ),
    );
  }
}

class _RecentSourceTile extends StatelessWidget {
  const _RecentSourceTile({required this.source, required this.onTap});

  final PracticeSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canPractice =
        (source.platform == SourcePlatform.bilibili &&
            source.externalId != null) ||
        (source.platform == SourcePlatform.local &&
            source.kind == SourceKind.video &&
            source.canonicalUri?.scheme == 'file');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: CircleAvatar(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        child: Icon(_platformIcon(source.platform)),
      ),
      title: Text(
        source.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_platformLabel(source.platform)} · '
        '${canPractice ? '支持倍速与 A-B 循环' : '引用模式'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _TodayProgressCard extends ConsumerWidget {
  const _TodayProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final date = ref.watch(currentCalendarDateProvider);
    final sessions = ref.watch(practiceSessionsForDateProvider(date));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: sessions.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) =>
            Text('今日练习记录暂时无法读取', style: TextStyle(color: colors.error)),
        data: (items) {
          final completed = items
              .where((item) => item.hasPracticeActivity)
              .toList();
          final duration = completed.fold(
            Duration.zero,
            (total, item) => total + item.activeDuration,
          );
          final loops = completed.fold(
            0,
            (total, item) => total + item.loopCount,
          );
          return Row(
            children: [
              Icon(Icons.insights_outlined, color: colors.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日练习记录',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      completed.isEmpty
                          ? '完成一次练习后，时长和循环次数会显示在这里。'
                          : '${_formatPracticeDuration(duration)} · '
                                '${completed.length} 次记录 · $loops 次循环',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _goalProgressLabel(PracticePlanProgress progress) {
  final goal = progress.plan.goal;
  return switch (goal.type) {
    PracticeGoalType.loops =>
      '${progress.completedLoops} / ${goal.targetLoops} 次循环',
    PracticeGoalType.duration =>
      '${progress.completedDuration.inMinutes} / '
          '${goal.targetDuration!.inMinutes} 分钟',
  };
}

String _formatPracticeDuration(Duration duration) {
  if (duration.inMinutes == 0) return '${duration.inSeconds} 秒';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes 分钟';
  return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分钟';
}

String _formatToday(CalendarDate date) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日 · 星期${weekdays[date.weekday - 1]}';
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地视频',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'Bilibili',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页链接',
  };
}

IconData _platformIcon(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => Icons.video_file_rounded,
    SourcePlatform.youtube => Icons.play_circle_fill_rounded,
    SourcePlatform.bilibili => Icons.smart_display_rounded,
    SourcePlatform.douyin => Icons.music_note_rounded,
    SourcePlatform.xiaohongshu => Icons.menu_book_rounded,
    SourcePlatform.genericWeb => Icons.public_rounded,
  };
}
