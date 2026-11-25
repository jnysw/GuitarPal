import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';
import 'application/account_profile_repository.dart';
import 'domain/account_profile.dart';
import 'widgets/account_avatar.dart';

Future<void> openAccountProfileEditor(
  BuildContext context,
  WidgetRef ref,
  String userId,
) async {
  ref.invalidate(accountProfileProvider(userId));
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => AccountProfileEditor(userId: userId)),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('资料已保存')));
  }
}

class AccountProfileEditor extends ConsumerWidget {
  const AccountProfileEditor({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountSessionProvider).asData?.value;
    final signedIn = session?.isSignedIn == true && session?.userId == userId;
    final provider = accountProfileProvider(userId);
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: SafeArea(
        child: !signedIn
            ? const Center(child: Text('请重新登录后编辑资料'))
            : ref
                  .watch(provider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('暂时无法读取资料'),
                          TextButton(
                            onPressed: () => ref.invalidate(provider),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                    data: (profile) => _ProfileForm(profile: profile),
                  ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final AccountProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _handle = TextEditingController(text: widget.profile.handle ?? '');
  Uint8List? _avatar;
  bool _removeAvatar = false;
  bool _picking = false;
  bool _saving = false;
  String? _handleError;
  String? _message;

  bool get _busy => _picking || _saving;
  bool get _changed =>
      _avatar != null ||
      _removeAvatar ||
      AccountProfile.normalizeHandle(_handle.text) !=
          (widget.profile.handle ?? '');

  Future<void> _pickAvatar() async {
    if (_busy) return;
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final bytes = await ref.read(accountAvatarPickerProvider)();
      if (bytes == null || !mounted) return;
      setState(() {
        _avatar = bytes;
        _removeAvatar = false;
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Object {
      if (mounted) setState(() => _message = '无法读取这张照片，请更换一张');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _clearAvatar() => setState(() {
    _avatar = null;
    _removeAvatar = widget.profile.avatarPath != null;
  });

  Future<void> _save() async {
    if (_busy || !_changed || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final repository = ref.read(accountProfileRepositoryProvider)!;
      await repository.save(
        widget.profile,
        handle: AccountProfile.normalizeHandle(_handle.text),
        avatar: _avatar,
        removeAvatar: _removeAvatar,
      );
      if (!mounted) return;
      ref.invalidate(accountProfileProvider(widget.profile.userId));
      Navigator.of(context).pop(true);
    } on AccountProfileException catch (error) {
      if (mounted) {
        setState(() {
          if (error.handleTaken) {
            _handleError = error.message;
          } else {
            _message = error.message;
          }
        });
      }
    } on Object {
      if (mounted) setState(() => _message = '资料保存失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarPath = _removeAvatar ? null : widget.profile.avatarPath;
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: AccountAvatar(
                      path: avatarPath,
                      preview: _avatar,
                      radius: 48,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        key: const Key('account_pick_avatar'),
                        onPressed: _busy ? null : _pickAvatar,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(_picking ? '正在读取照片…' : '选择头像'),
                      ),
                      if (avatarPath != null || _avatar != null)
                        TextButton(
                          onPressed: _busy ? null : _clearAvatar,
                          child: const Text('移除头像'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    key: const Key('account_profile_handle'),
                    controller: _handle,
                    enabled: !_busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) =>
                        AccountProfile.validateHandle(value ?? ''),
                    forceErrorText: _handleError,
                    onChanged: (_) => setState(() => _handleError = null),
                    onFieldSubmitted: (_) => _save(),
                    decoration: const InputDecoration(
                      labelText: '用户 ID',
                      prefixText: '@',
                      helperText: AccountProfile.handleHint,
                      helperMaxLines: 2,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(_message!)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const Key('account_save_profile'),
                    onPressed: _busy || !_changed || _handleError != null
                        ? null
                        : _save,
                    child: Text(_saving ? '正在保存…' : '保存资料'),
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
