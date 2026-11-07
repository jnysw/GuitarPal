import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/practice_insights.dart';
import 'practice_insights_providers.dart';

enum _TrendRange { days14, weeks12 }

class PracticeInsightsScreen extends ConsumerStatefulWidget {
  const PracticeInsightsScreen({super.key});

  @override
  ConsumerState<PracticeInsightsScreen> createState() =>
      _PracticeInsightsScreenState();
}

class _PracticeInsightsScreenState
    extends ConsumerState<PracticeInsightsScreen> {
  _TrendRange _trendRange = _TrendRange.days14;

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(practiceInsightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('练习反馈')),
      body: SafeArea(
        child: insights.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('练习反馈暂时无法读取，请稍后重试。'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(practiceInsightsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
          data: (value) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _InsightsHeader(insights: value),
              const SizedBox(height: 14),
              _InsightsSection(
                key: const Key('profile_practice_trend'),
                title: '练习时长趋势',
                subtitle: '查看最近 14 天或 12 周的练习节奏',
                icon: Icons.stacked_bar_chart_rounded,
                initiallyExpanded: true,
                child: _TrendSection(
                  insights: value,
                  range: _trendRange,
                  onRangeChanged: (range) {
                    setState(() => _trendRange = range);
                  },
                ),
              ),
              const SizedBox(height: 10),
              _InsightsSection(
                key: const Key('profile_practice_metrics_section'),
                title: '累计统计',
                subtitle: '练习次数、循环、活跃天数和完成曲目',
                icon: Icons.insights_outlined,
                child: _MetricGrid(insights: value),
              ),
              const SizedBox(height: 10),
              const _InsightsSection(
                key: Key('profile_insights_help_section'),
                title: '如何理解这些数据',
                subtitle: '反馈口径与使用建议',
                icon: Icons.help_outline_rounded,
                child: _InsightsExplanation(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  const _InsightsHeader({required this.insights});

  final PracticeInsights insights;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
              child: const Icon(Icons.show_chart_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '累计练习 ${_formatDuration(insights.totalActiveDuration)}',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '有效练习 ${insights.sessionCount} 次 · '
                    '当前连续 ${insights.currentStreakDays} 天',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [child],
      ),
    );
  }
}

class _TrendSection extends StatelessWidget {
  const _TrendSection({
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
        SegmentedButton<_TrendRange>(
          key: const Key('profile_trend_range'),
          segments: const [
            ButtonSegment(value: _TrendRange.days14, label: Text('14 天')),
            ButtonSegment(value: _TrendRange.weeks12, label: Text('12 周')),
          ],
          selected: {range},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            onRangeChanged(selection.single);
          },
        ),
        const SizedBox(height: 10),
        Text(
          '${_formatDuration(rangeDuration)} · 活跃 $activeBuckets '
          '${range == _TrendRange.days14 ? '天' : '周'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        _PracticeTrendChart(
          buckets: buckets,
          weekly: range == _TrendRange.weeks12,
        ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
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
    );
  }
}

class _InsightsExplanation extends StatelessWidget {
  const _InsightsExplanation();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• 只统计包含有效播放时长或 A-B 循环的练习记录。'),
        SizedBox(height: 7),
        Text('• 暂停和应用进入后台的时间不会计入练习时长。'),
        SizedBox(height: 7),
        Text('• 连续练习允许今天尚未开始，但昨天有练习时继续显示当前连续天数。'),
        SizedBox(height: 7),
        Text('• 这些数据用于观察习惯，不代表演奏水平评分。'),
      ],
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
