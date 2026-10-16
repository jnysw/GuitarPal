import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_source/practice_source.dart';
import '../library/presentation/source_artwork.dart';
import '../library/practice_source_providers.dart';
import '../../media/adapters/practice_source_adapter.dart';
import 'domain/shared_item.dart';
import 'inbox_providers.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({required this.item, this.returnToPlan = false, super.key});

  final SharedItem item;
  final bool returnToPlan;

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  String? _editedTitle;
  bool _isSaving = false;
  String? _saveError;

  Future<void> _save(ResolvedSource resolved, {bool startNow = false}) async {
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final source = await ref
          .read(sourceImportServiceProvider)
          .save(
            item: widget.item,
            resolved: resolved,
            title: _editedTitle ?? resolved.title,
          );
      if (!mounted) return;
      ref.invalidate(practiceSourcesProvider);
      ref.invalidate(practiceSourceByIdProvider(source.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('已保存：${source.title}')));
      final encodedSourceId = Uri.encodeComponent(source.id);
      final detailLocation = '/library/source/$encodedSourceId';
      if (startNow) {
        context.go('$detailLocation/practice');
      } else if (widget.returnToPlan) {
        context.go('/plans/new?sourceId=$encodedSourceId');
      } else {
        context.go(detailLocation);
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = '保存失败，请稍后重试。';
      });
      debugPrint('Failed to save shared source: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = widget.item.detectedUri;
    if (uri == null) return const _InvalidShareView();

    final resolved = ref.watch(resolvedSourceProvider(uri));
    return Scaffold(
      appBar: AppBar(title: const Text('添加到 GuitarPal')),
      body: SafeArea(
        child: resolved.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _ResolveErrorView(),
          data: (source) => _ConfirmationView(
            source: source,
            isSaving: _isSaving,
            returnToPlan: widget.returnToPlan,
            saveError: _saveError,
            onTitleChanged: (value) => _editedTitle = value,
            onCancel: () => context.pop(),
            onSave: () => _save(source),
            onStart: () => _save(source, startNow: true),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView({
    required this.source,
    required this.isSaving,
    required this.returnToPlan,
    required this.onTitleChanged,
    required this.onCancel,
    required this.onSave,
    required this.onStart,
    this.saveError,
  });

  final ResolvedSource source;
  final bool isSaving;
  final bool returnToPlan;
  final String? saveError;
  final ValueChanged<String> onTitleChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (source.thumbnailUri != null)
                AspectRatio(
                  key: const Key('shared_source_artwork'),
                  aspectRatio: 16 / 9,
                  child: SourceArtwork(
                    platform: source.platform,
                    thumbnailUri: source.thumbnailUri,
                    borderRadius: 18,
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox.square(
                    dimension: 72,
                    child: SourceArtwork(
                      platform: source.platform,
                      borderRadius: 22,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                _platformLabel(source.platform),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('shared_source_title'),
                initialValue: source.title,
                onChanged: onTitleChanged,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: '练习名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                source.canonicalUri.toString(),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text('当前能力', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _CapabilityRow(
                available: source.capabilities.canOpen,
                label: '可打开原内容',
              ),
              _CapabilityRow(
                available: source.capabilities.canPlayInline,
                label: 'App 内播放',
              ),
              _CapabilityRow(
                available: source.capabilities.canLoop,
                label: 'A-B Loop',
              ),
              if (source.externalId case final externalId?) ...[
                const SizedBox(height: 12),
                Text(
                  '内容 ID：$externalId',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (saveError case final error?) ...[
                const SizedBox(height: 16),
                Text(error, style: TextStyle(color: colors.error)),
              ],
              const SizedBox(height: 28),
              if (returnToPlan)
                FilledButton.icon(
                  key: const Key('save_shared_source'),
                  onPressed: isSaving ? null : onSave,
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_task_rounded),
                  label: const Text('保存并加入计划'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('save_shared_source'),
                        onPressed: isSaving ? null : onSave,
                        child: isSaving
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('保存到练习库'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('start_shared_source'),
                        onPressed:
                            isSaving ||
                                !source.capabilities.canPlayInline ||
                                source.externalId == null
                            ? null
                            : onStart,
                        child: const Text('保存并开始'),
                      ),
                    ),
                  ],
                ),
              TextButton(
                onPressed: isSaving ? null : onCancel,
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.available, required this.label});

  final bool available;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            available
                ? Icons.check_circle_rounded
                : Icons.remove_circle_outline,
            size: 20,
            color: available
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 10),
          Text(available ? label : '$label（当前不可用）'),
        ],
      ),
    );
  }
}

class _ResolveErrorView extends StatelessWidget {
  const _ResolveErrorView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('暂时无法识别该来源，你可以稍后重试。'),
      ),
    );
  }
}

class _InvalidShareView extends StatelessWidget {
  const _InvalidShareView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加到 GuitarPal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded, size: 48),
              const SizedBox(height: 16),
              const Text('分享内容中没有可识别的 URL'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/create'),
                child: const Text('返回添加内容'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地文件',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'Bilibili',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页链接',
  };
}
