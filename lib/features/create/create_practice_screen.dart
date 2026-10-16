import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/local_video_gateway.dart';
import '../inbox/inbox_providers.dart';
import 'local_video_providers.dart';

class CreatePracticeScreen extends ConsumerStatefulWidget {
  const CreatePracticeScreen({this.returnToPlan = false, super.key});

  final bool returnToPlan;

  @override
  ConsumerState<CreatePracticeScreen> createState() =>
      _CreatePracticeScreenState();
}

class _CreatePracticeScreenState extends ConsumerState<CreatePracticeScreen> {
  final _shareTextController = TextEditingController();
  String? _validationMessage;
  bool _isPickingLocalVideo = false;

  @override
  void dispose() {
    _shareTextController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;

    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      setState(() => _validationMessage = '剪贴板中没有可用的文字或链接');
      return;
    }

    _shareTextController.text = text;
    _shareTextController.selection = TextSelection.collapsed(
      offset: text.length,
    );
    setState(() => _validationMessage = null);
  }

  void _continueWithLink() {
    final rawText = _shareTextController.text.trim();
    if (rawText.isEmpty) {
      setState(() => _validationMessage = '请粘贴分享文字或输入视频链接');
      return;
    }

    final item = ref.read(sharedItemParserProvider).parse(rawText);
    if (item.detectedUri == null) {
      setState(() => _validationMessage = '没有识别到有效的 http/https 链接');
      return;
    }

    final inboxLocation = Uri(
      path: '/inbox',
      queryParameters: {
        'url': item.detectedUri.toString(),
        if (widget.returnToPlan) 'returnTo': 'plan',
      },
    ).toString();
    context.pushReplacement(inboxLocation, extra: item);
  }

  Future<void> _pickLocalVideo(LocalVideoPickOrigin origin) async {
    if (_isPickingLocalVideo) return;
    if (!Platform.isAndroid) {
      _showMessage('本地视频导入当前先在 Android 版本开放');
      return;
    }

    setState(() => _isPickingLocalVideo = true);
    final gateway = ref.read(localVideoGatewayProvider);
    try {
      final file = await gateway.pickVideo(origin);
      if (file == null) return;
      if (!mounted) {
        try {
          await gateway.discardDraft(file.path);
        } on Object {
          // The operating system will eventually reclaim an orphaned cache file.
        }
        return;
      }
      final draft = ref
          .read(localVideoDraftStoreProvider)
          .create(origin: origin, file: file);
      setState(() => _isPickingLocalVideo = false);
      final location = Uri(
        path: '/create/local/${Uri.encodeComponent(draft.id)}',
        queryParameters: {if (widget.returnToPlan) 'returnTo': 'plan'},
      ).toString();
      context.push(location);
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(error.message ?? '无法读取这个视频，请选择其他文件');
    } on Object catch (error) {
      if (!mounted) return;
      debugPrint('Failed to pick a local video: $error');
      _showMessage('无法读取这个视频，请选择其他文件');
    } finally {
      if (mounted && _isPickingLocalVideo) {
        setState(() => _isPickingLocalVideo = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('新建练习')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '从哪里开始？',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.returnToPlan
                        ? '保存后会返回新建计划，并自动选中这项练习。'
                        : '先把教程加入练习库，再设置倍速、A-B 循环和练习片段。',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.link_rounded, color: colors.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '从链接添加',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '支持 B站、抖音、小红书、YouTube 及普通网页链接，也可以粘贴含链接的完整分享文案。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            key: const Key('create_share_text_field'),
                            controller: _shareTextController,
                            minLines: 3,
                            maxLines: 6,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) {
                              if (_validationMessage != null) {
                                setState(() => _validationMessage = null);
                              }
                            },
                            onSubmitted: (_) => _continueWithLink(),
                            decoration: InputDecoration(
                              labelText: '分享文字或链接',
                              hintText: '例如：https://www.bilibili.com/video/BV…',
                              errorText: _validationMessage,
                              alignLabelWithHint: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  key: const Key('create_paste_button'),
                                  onPressed: _pasteFromClipboard,
                                  icon: const Icon(Icons.content_paste_rounded),
                                  label: const Text('从剪贴板粘贴'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  key: const Key('create_continue_button'),
                                  onPressed: _continueWithLink,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('识别并继续'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '本地视频',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _LocalImportTile(
                    key: const Key('pick_gallery_video'),
                    icon: Icons.photo_library_outlined,
                    title: '从相册选择',
                    subtitle: '使用 Android 系统照片选择器，无需读取整个相册',
                    isLoading: _isPickingLocalVideo,
                    onTap: () => _pickLocalVideo(LocalVideoPickOrigin.gallery),
                  ),
                  const SizedBox(height: 8),
                  _LocalImportTile(
                    key: const Key('pick_file_video'),
                    icon: Icons.folder_open_rounded,
                    title: '从文件导入',
                    subtitle: '从下载目录、云盘或其他文件位置选择视频',
                    isLoading: _isPickingLocalVideo,
                    onTap: () => _pickLocalVideo(LocalVideoPickOrigin.files),
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

class _LocalImportTile extends StatelessWidget {
  const _LocalImportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      child: ListTile(
        enabled: !isLoading,
        onTap: isLoading ? null : onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
