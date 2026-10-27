import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_outbox.dart';
import 'account_providers.dart';
import 'application/auth_repository.dart';
import 'domain/account_session.dart';
import 'domain/local_data_inventory.dart';

class AccountAndSyncScreen extends ConsumerStatefulWidget {
  const AccountAndSyncScreen({super.key});

  @override
  ConsumerState<AccountAndSyncScreen> createState() =>
      _AccountAndSyncScreenState();
}

class _AccountAndSyncScreenState extends ConsumerState<AccountAndSyncScreen> {
  final _signInMethodsKey = GlobalKey();
  bool _signingOut = false;
  AccountSignInMethod? _startingMethod;

  Future<void> _showSignInMethods() async {
    final targetContext = _signInMethodsKey.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  Future<void> _beginSignIn(AccountSignInMethod method) async {
    if (_startingMethod != null) return;
    String? email;
    if (method == AccountSignInMethod.emailLink) {
      email = await _requestEmail();
      if (email == null || !mounted) return;
    }
    setState(() => _startingMethod = method);
    try {
      final result = await ref
          .read(authRepositoryProvider)
          .beginSignIn(method, email: email);
      if (!mounted) return;
      switch (result) {
        case AuthStartResult.emailLinkSent:
          _showMessage('登录邮件已发送，请在当前设备打开邮件中的链接');
        case AuthStartResult.browserOpened:
          break;
      }
    } on AuthUnavailableException catch (error) {
      if (mounted) _showMessage(error.message);
    } on AuthOperationException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('登录暂时无法开始，请稍后重试');
    } finally {
      if (mounted) setState(() => _startingMethod = null);
    }
  }

  Future<String?> _requestEmail() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _EmailSignInDialog(),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('退出登录失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(accountSessionProvider);
    final inventory = ref.watch(localDataInventoryProvider);
    final syncSummary = ref.watch(syncOutboxSummaryProvider);
    final availableMethods = ref.watch(authRepositoryProvider).availableMethods;
    final currentSession = session.asData?.value;
    return Scaffold(
      appBar: AppBar(title: const Text('账号与同步')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _AccountSessionCard(
              session: session,
              signingOut: _signingOut,
              onSignOut: _signOut,
              hasAvailableMethods: availableMethods.isNotEmpty,
              onChooseSignIn: _showSignInMethods,
            ),
            const SizedBox(height: 18),
            const _SectionTitle('本机数据迁移预览'),
            const SizedBox(height: 8),
            _LocalInventoryCard(inventory: inventory),
            const SizedBox(height: 10),
            _SyncPreparationCard(summary: syncSummary),
            const SizedBox(height: 18),
            _SectionTitle(availableMethods.isEmpty ? '计划中的登录方式' : '登录方式'),
            const SizedBox(height: 8),
            Card(
              key: _signInMethodsKey,
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _PlanTile(
                    key: const Key('account_email_sign_in'),
                    icon: Icons.mail_outline_rounded,
                    title: '邮箱快捷登录',
                    subtitle: '通过一次性链接或验证码登录，不在应用内保存密码',
                    trailing: _methodStatus(
                      AccountSignInMethod.emailLink,
                      availableMethods,
                      currentSession,
                    ),
                    onTap:
                        _canStartSignIn(
                          AccountSignInMethod.emailLink,
                          availableMethods,
                          currentSession?.status,
                        )
                        ? () => _beginSignIn(AccountSignInMethod.emailLink)
                        : null,
                  ),
                  const Divider(height: 1, indent: 64),
                  _PlanTile(
                    key: const Key('account_google_sign_in'),
                    icon: Icons.android_rounded,
                    title: 'Google 登录',
                    subtitle: 'Android 优先支持，使用系统浏览器完成安全授权',
                    trailing: _methodStatus(
                      AccountSignInMethod.google,
                      availableMethods,
                      currentSession,
                    ),
                    onTap:
                        _canStartSignIn(
                          AccountSignInMethod.google,
                          availableMethods,
                          currentSession?.status,
                        )
                        ? () => _beginSignIn(AccountSignInMethod.google)
                        : null,
                  ),
                  const Divider(height: 1, indent: 64),
                  _PlanTile(
                    key: const Key('account_apple_sign_in'),
                    icon: Icons.apple_rounded,
                    title: 'Apple 登录',
                    subtitle: '在 iOS 版本进入开发后一起接入',
                    trailing: _methodStatus(
                      AccountSignInMethod.apple,
                      availableMethods,
                      currentSession,
                    ),
                    onTap:
                        _canStartSignIn(
                          AccountSignInMethod.apple,
                          availableMethods,
                          currentSession?.status,
                        )
                        ? () => _beginSignIn(AccountSignInMethod.apple)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionTitle('同步范围'),
            const SizedBox(height: 8),
            const Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  _PlanTile(
                    icon: Icons.cloud_sync_outlined,
                    title: '第一阶段：练习数据',
                    subtitle: '同步曲目元数据、片段、计划、练习记录和笔记',
                    trailing: '优先',
                  ),
                  Divider(height: 1, indent: 64),
                  _PlanTile(
                    icon: Icons.mic_none_rounded,
                    title: '第二阶段：录音文件',
                    subtitle: '默认仍留在本机，用户主动开启后才上传',
                    trailing: '可选',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Card(
              margin: EdgeInsets.zero,
              child: ExpansionTile(
                key: const Key('account_privacy_explanation'),
                leading: const Icon(Icons.security_rounded),
                title: const Text(
                  '数据迁移与隐私原则',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('展开查看登录后会发生什么'),
                childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                children: const [
                  Text(
                    '首次登录时会先保留本机数据，再由用户确认合并到账号。'
                    '计划和记录采用可恢复的增量同步；删除操作也会同步，避免另一台设备把旧数据重新带回。'
                    '录音属于敏感内容，默认不上传，并提供单独的同步开关、导出和删除入口。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _methodStatus(
    AccountSignInMethod method,
    Set<AccountSignInMethod> availableMethods,
    AccountSession? session,
  ) {
    if (_startingMethod == method) return '启动中';
    if (!availableMethods.contains(method)) return '未配置';
    if (session?.signInMethod == method) {
      if (session?.status == AccountSessionStatus.signedIn) return '已登录';
      if (session?.status == AccountSessionStatus.authenticating) return '登录中';
    }
    if (session?.status == AccountSessionStatus.signedIn) return '未使用';
    if (session?.status == AccountSessionStatus.authenticating) return '等待';
    return '可用';
  }

  bool _canStartSignIn(
    AccountSignInMethod method,
    Set<AccountSignInMethod> availableMethods,
    AccountSessionStatus? sessionStatus,
  ) {
    final canAuthenticate =
        sessionStatus == AccountSessionStatus.local ||
        sessionStatus == AccountSessionStatus.expired;
    return _startingMethod == null &&
        canAuthenticate &&
        availableMethods.contains(method);
  }
}

class _SyncPreparationCard extends StatelessWidget {
  const _SyncPreparationCard({required this.summary});

  final AsyncValue<SyncOutboxSummary> summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.filled(
      key: const Key('account_sync_outbox_summary'),
      margin: EdgeInsets.zero,
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summary.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('本机同步队列暂时无法读取，练习数据不受影响。'),
          data: (value) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync_rounded, color: colors.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value.isEmpty
                          ? '本机同步队列已准备'
                          : '${value.pendingCount} 项变更等待账号同步',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value.failedCount > 0
                          ? '${value.failedCount} 项上次同步失败，联网并重新登录后会重试。'
                          : '曲目、片段、计划和练习记录会进入队列；录音仍默认只保存在本机。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailSignInDialog extends StatefulWidget {
  const _EmailSignInDialog();

  @override
  State<_EmailSignInDialog> createState() => _EmailSignInDialogState();
}

class _EmailSignInDialogState extends State<_EmailSignInDialog> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    final separator = value.indexOf('@');
    final isValid = separator > 0 && separator < value.length - 1;
    if (!isValid) {
      setState(() => _errorText = '请输入有效的邮箱地址');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邮箱快捷登录'),
      content: TextField(
        key: const Key('account_email_field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: '邮箱地址',
          hintText: 'name@example.com',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('account_email_continue'),
          onPressed: _submit,
          child: const Text('继续'),
        ),
      ],
    );
  }
}

class _AccountSessionCard extends StatelessWidget {
  const _AccountSessionCard({
    required this.session,
    required this.signingOut,
    required this.onSignOut,
    required this.hasAvailableMethods,
    required this.onChooseSignIn,
  });

  final AsyncValue<AccountSession> session;
  final bool signingOut;
  final VoidCallback onSignOut;
  final bool hasAvailableMethods;
  final VoidCallback onChooseSignIn;

  @override
  Widget build(BuildContext context) {
    return session.when(
      loading: () => const Card.filled(
        key: Key('account_session_loading'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (_, _) => Card.filled(
        key: const Key('account_session_error'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('账号状态暂时无法读取，本地数据不受影响。')),
            ],
          ),
        ),
      ),
      data: (value) => _AccountSessionContent(
        session: value,
        signingOut: signingOut,
        onSignOut: onSignOut,
        hasAvailableMethods: hasAvailableMethods,
        onChooseSignIn: onChooseSignIn,
      ),
    );
  }
}

class _AccountSessionContent extends StatelessWidget {
  const _AccountSessionContent({
    required this.session,
    required this.signingOut,
    required this.onSignOut,
    required this.hasAvailableMethods,
    required this.onChooseSignIn,
  });

  final AccountSession session;
  final bool signingOut;
  final VoidCallback onSignOut;
  final bool hasAvailableMethods;
  final VoidCallback onChooseSignIn;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (title, subtitle, icon) = switch (session.status) {
      AccountSessionStatus.local => (
        '当前使用本地模式',
        '无需账号即可使用全部现有练习功能。',
        Icons.phone_android_rounded,
      ),
      AccountSessionStatus.authenticating => (
        '正在安全登录',
        session.signInMethod == AccountSignInMethod.emailLink
            ? '请在当前设备打开登录邮件中的链接。'
            : '请在系统浏览器中完成授权。',
        Icons.login_rounded,
      ),
      AccountSessionStatus.signedIn => (
        session.label,
        session.email ?? '账号已连接，本机数据可以进入同步流程。',
        Icons.verified_user_outlined,
      ),
      AccountSessionStatus.expired => (
        '登录已过期',
        '本机数据仍可使用，重新认证后再继续同步。',
        Icons.lock_clock_outlined,
      ),
    };
    return Card.filled(
      key: const Key('account_local_mode_card'),
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
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (session.status == AccountSessionStatus.signedIn)
              OutlinedButton.icon(
                key: const Key('account_sign_out_button'),
                onPressed: signingOut ? null : onSignOut,
                icon: signingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded),
                label: const Text('退出账号，保留本机数据'),
              )
            else
              FilledButton.icon(
                key: Key(
                  _canChooseSignIn
                      ? 'account_choose_sign_in'
                      : 'account_sign_in_disabled',
                ),
                onPressed: _canChooseSignIn ? onChooseSignIn : null,
                icon: session.status == AccountSessionStatus.authenticating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(
                  _canChooseSignIn
                      ? '选择登录方式'
                      : session.status == AccountSessionStatus.authenticating
                      ? '正在登录'
                      : session.status == AccountSessionStatus.expired
                      ? '重新登录尚未开放'
                      : '登录与同步尚未开放',
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _canChooseSignIn =>
      hasAvailableMethods &&
      (session.status == AccountSessionStatus.local ||
          session.status == AccountSessionStatus.expired);
}

class _LocalInventoryCard extends StatelessWidget {
  const _LocalInventoryCard({required this.inventory});

  final AsyncValue<LocalDataInventory> inventory;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('account_local_inventory'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: inventory.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const Text('本机数据清单暂时无法读取。'),
          data: (value) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                value.isEmpty
                    ? '本机目前还没有需要迁移的练习数据'
                    : '${value.metadataItemCount} 条练习数据可在登录后合并',
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '录音文件默认不进入同步，之后可单独选择是否上传。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InventoryMetric(
                    key: const Key('account_inventory_sources'),
                    label: '曲目',
                    value: value.sourceCount,
                  ),
                  _InventoryMetric(
                    key: const Key('account_inventory_segments'),
                    label: '片段',
                    value: value.segmentCount,
                  ),
                  _InventoryMetric(
                    key: const Key('account_inventory_plans'),
                    label: '计划',
                    value: value.planCount,
                  ),
                  _InventoryMetric(
                    key: const Key('account_inventory_sessions'),
                    label: '练习记录',
                    value: value.sessionCount,
                  ),
                  _InventoryMetric(
                    key: const Key('account_inventory_recordings'),
                    label: '录音',
                    value: value.recordingCount,
                  ),
                  _InventoryMetric(
                    key: const Key('account_inventory_notes'),
                    label: '笔记',
                    value: value.noteCount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({required this.label, required this.value, super.key});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text('$label $value'),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: TextStyle(
                color: onTap == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
