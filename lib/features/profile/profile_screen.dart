import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'domain/practice_insights.dart';
import 'practice_insights_providers.dart';

enum _TrendRange { days14, weeks12 }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _TrendRange _trendRange = _TrendRange.days14;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final insights = ref.watch(practiceInsightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('个人中心')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    color: colors.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '本地练习空间',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '无需登录，练习内容、计划和记录保存在本机。',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '训练反馈',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  insights.when(
                    loading: () => const Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                    error: (_, _) => Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          '训练反馈暂时无法读取，请稍后重试。',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ),
                    data: (value) => _TrainingFeedback(
                      insights: value,
                      range: _trendRange,
                      onRangeChanged: (range) {
                        setState(() => _trendRange = range);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '数据与应用',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        const _StatusTile(
                          icon: Icons.shield_outlined,
                          title: '本地数据与隐私',
                          subtitle: '数据当前仅保存在这台设备上',
                          status: '已启用',
                          available: true,
                        ),
                        const Divider(height: 1, indent: 64),
                        const _StatusTile(
                          icon: Icons.notifications_none_rounded,
                          title: '练习提醒',
                          subtitle: '可在每个练习计划中设置时间和重复日期',
                          status: '已接入',
                          available: true,
                        ),
                        const Divider(height: 1, indent: 64),
                        _StatusTile(
                          icon: Icons.tune_rounded,
                          title: '应用设置',
                          subtitle: '主题模式与默认练习倍速',
                          status: '可设置',
                          available: true,
                          onTap: () => context.push('/profile/settings'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '帮助',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  const Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _StatusTile(
                          icon: Icons.support_agent_rounded,
                          title: '支持',
                          subtitle: '帮助中心尚未接入',
                          status: '未接入',
                        ),
                        Divider(height: 1, indent: 64),
                        _StatusTile(
                          icon: Icons.feedback_outlined,
                          title: '问题反馈',
                          subtitle: '反馈渠道尚未开放',
                          status: '未接入',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingFeedback extends StatelessWidget {
  const _TrainingFeedback({
    required this.insights,
    required this.range,
    required this.onRangeChanged,
  });

  final PracticeInsights insights;
  final _TrendRange range;
  final ValueChanged<_TrendRange> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final buckets = range == _TrendRange.days14
        ? insights.recentDays
        : insights.recentWeeks;
    final rangeDuration = buckets.fold(
      Duration.zero,
      (total, bucket) => total + bucket.activeDuration,
    );
    final activeBuckets = buckets.where((bucket) => bucket.hasActivity).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('profile_practice_trend'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '练习时长趋势',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_formatDuration(rangeDuration)} · '
                            '活跃 $activeBuckets '
                            '${range == _TrendRange.days14 ? '天' : '周'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<_TrendRange>(
                      key: const Key('profile_trend_range'),
                      segments: const [
                        ButtonSegment(
                          value: _TrendRange.days14,
                          label: Text('14 天'),
                        ),
                        ButtonSegment(
                          value: _TrendRange.weeks12,
                          label: Text('12 周'),
                        ),
                      ],
                      selected: {range},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        onRangeChanged(selection.single);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PracticeTrendChart(
                  buckets: buckets,
                  weekly: range == _TrendRange.weeks12,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _MetricGrid(insights: insights),
      ],
    );
  }
}

class _PracticeTrendChart extends StatelessWidget {
  const _PracticeTrendChart({required this.buckets, required this.weekly});

  final List<PracticeTrendBucket> buckets;
  final bool weekly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maximumMilliseconds = buckets.fold(
      0,
      (maximum, bucket) => bucket.activeDuration.inMilliseconds > maximum
          ? bucket.activeDuration.inMilliseconds
          : maximum,
    );
    return SizedBox(
      height: 158,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < buckets.length; index++)
            Expanded(
              child: Semantics(
                label: _bucketSemanticLabel(buckets[index], weekly),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final bucket = buckets[index];
                            final fraction = maximumMilliseconds == 0
                                ? 0.0
                                : bucket.activeDuration.inMilliseconds /
                                      maximumMilliseconds;
                            final height = bucket.hasActivity
                                ? (constraints.maxHeight * fraction).clamp(
                                    6.0,
                                    constraints.maxHeight,
                                  )
                                : 2.0;
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                key: Key('profile_trend_bar_$index'),
                                duration: const Duration(milliseconds: 220),
                                width: double.infinity,
                                height: height,
                                decoration: BoxDecoration(
                                  color: bucket.hasActivity
                                      ? colors.primary
                                      : colors.outlineVariant,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(5),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _bucketAxisLabel(buckets[index], index, weekly),
                        maxLines: 1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontSize: weekly ? 9 : 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.insights});

  final PracticeInsights insights;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      key: const Key('profile_practice_metrics'),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _MetricCard(
          key: const Key('profile_total_duration'),
          icon: Icons.timer_outlined,
          label: '累计练习',
          value: _formatDuration(insights.totalActiveDuration),
        ),
        _MetricCard(
          key: const Key('profile_session_count'),
          icon: Icons.check_circle_outline_rounded,
          label: '有效练习',
          value: '${insights.sessionCount} 次',
        ),
        _MetricCard(
          key: const Key('profile_completed_sources'),
          icon: Icons.library_music_outlined,
          label: '完成曲目',
          value: '${insights.completedSourceCount} / ${insights.sourceCount}',
        ),
        _MetricCard(
          key: const Key('profile_loop_count'),
          icon: Icons.repeat_rounded,
          label: 'A-B 循环',
          value: '${insights.loopCount} 次',
        ),
        _MetricCard(
          key: const Key('profile_active_days'),
          icon: Icons.calendar_today_outlined,
          label: '练习天数',
          value: '${insights.activeDayCount} 天',
        ),
        _MetricCard(
          key: const Key('profile_current_streak'),
          icon: Icons.local_fire_department_outlined,
          label: '当前连续',
          value: '${insights.currentStreakDays} 天',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    this.available = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
        child: Row(
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: available
                    ? colors.primaryContainer
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                status,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: available
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  if (duration <= Duration.zero) return '0 分钟';
  if (duration.inMinutes == 0) return '${duration.inSeconds} 秒';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes 分钟';
  return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分钟';
}

String _bucketAxisLabel(PracticeTrendBucket bucket, int index, bool weekly) {
  if (!weekly) return '${bucket.start.day}';
  if (index == 11) return '本周';
  if (index.isOdd) return '';
  return '${bucket.start.month}/${bucket.start.day}';
}

String _bucketSemanticLabel(PracticeTrendBucket bucket, bool weekly) {
  final period = weekly
      ? '${bucket.start.month}月${bucket.start.day}日至'
            '${bucket.end.month}月${bucket.end.day}日'
      : '${bucket.start.month}月${bucket.start.day}日';
  return '$period，练习${_formatDuration(bucket.activeDuration)}，'
      '${bucket.sessionCount} 次记录，${bucket.loopCount} 次循环';
}
