import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'account_providers.dart';
import 'domain/account_session.dart';
import 'domain/practice_insights.dart';
import 'practice_insights_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final insights = ref.watch(practiceInsightsProvider);
    final accountSession = ref.watch(accountSessionProvider).asData?.value;
    final authConfigured = ref
        .watch(authRepositoryProvider)
        .availableMethods
        .isNotEmpty;
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
                  _LocalProfileCard(
                    session: accountSession,
                    authConfigured: authConfigured,
                    onOpenAccount: () => context.push('/profile/account'),
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
                    data: (value) => _FeedbackEntry(
                      insights: value,
                      onTap: () => context.push('/profile/insights'),
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
                        if (kDebugMode) ...[
                          _StatusTile(
                            key: const Key('profile_audio_tools_entry'),
                            icon: Icons.graphic_eq_rounded,
                            title: '音频工具（实验）',
                            subtitle: '上传自有音频、查看和弦分析与任务记录',
                            status: '联调',
                            available: true,
                            onTap: () => context.push('/audio-tools'),
                          ),
                          const Divider(height: 1, indent: 64),
                        ],
                        const _StatusTile(
                          icon: Icons.shield_outlined,
                          title: '本地数据与隐私',
                          subtitle: '练习数据默认保存在本机，实验分析需确认上传',
                          status: '已启用',
                          available: true,
                        ),
                        const Divider(height: 1, indent: 64),
                        _StatusTile(
                          key: const Key('profile_reminders_entry'),
                          icon: Icons.notifications_none_rounded,
                          title: '练习提醒',
                          subtitle: '集中开启、关闭或修改所有计划的提醒时间',
                          status: '管理',
                          available: true,
                          onTap: () => context.push('/plans/reminders'),
                        ),
                        const Divider(height: 1, indent: 64),
                        _StatusTile(
                          key: const Key('profile_account_entry'),
                          icon: Icons.person_outline_rounded,
                          title: '账号与同步',
                          subtitle: authConfigured
                              ? 'Supabase 登录、本机数据迁移与同步设置'
                              : '了解登录、跨设备同步与录音隐私方案',
                          status: _accountStatusLabel(
                            accountSession,
                            authConfigured,
                          ),
                          available: authConfigured,
                          onTap: () => context.push('/profile/account'),
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

class _LocalProfileCard extends StatelessWidget {
  const _LocalProfileCard({
    required this.session,
    required this.authConfigured,
    required this.onOpenAccount,
  });

  final AccountSession? session;
  final bool authConfigured;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isSignedIn = session?.status == AccountSessionStatus.signedIn;
    final isAuthenticating =
        session?.status == AccountSessionStatus.authenticating;
    final title = isSignedIn
        ? session!.label
        : isAuthenticating
        ? '正在安全登录'
        : '本地练习空间';
    final subtitle = isSignedIn
        ? session!.email ?? 'Supabase 账号已连接。'
        : isAuthenticating
        ? '完成邮件或浏览器授权后会自动返回 GuitarPal。'
        : authConfigured
        ? '无需登录也可练习；登录后可逐步启用跨设备同步。'
        : '无需登录，练习内容、计划和记录保存在本机。';
    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Icon(
                    isSignedIn
                        ? Icons.verified_user_outlined
                        : Icons.music_note_rounded,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('profile_account_header_button'),
              onPressed: onOpenAccount,
              icon: const Icon(Icons.cloud_outlined),
              label: Text(
                isSignedIn
                    ? '管理账号与同步'
                    : authConfigured
                    ? '登录或管理同步'
                    : '了解账号与同步',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _accountStatusLabel(AccountSession? session, bool authConfigured) {
  return switch (session?.status) {
    AccountSessionStatus.authenticating => '登录中',
    AccountSessionStatus.signedIn => '已登录',
    AccountSessionStatus.expired => '需重登',
    AccountSessionStatus.local || null => authConfigured ? '可登录' : '规划中',
  };
}

class _FeedbackEntry extends StatelessWidget {
  const _FeedbackEntry({required this.insights, required this.onTap});

  final PracticeInsights insights;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('profile_insights_entry'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                child: const Icon(Icons.insights_rounded),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '查看完整练习反馈',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '累计 ${_formatDuration(insights.totalActiveDuration)} · '
                      '${insights.sessionCount} 次 · '
                      '连续 ${insights.currentStreakDays} 天',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
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
    super.key,
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
