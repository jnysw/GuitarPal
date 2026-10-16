import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/local_video_gateway.dart';
import '../library/practice_source_providers.dart';
import 'application/local_video_draft_store.dart';
import 'application/local_video_import_service.dart';
import 'domain/local_video_draft.dart';
import 'local_video_providers.dart';

class LocalVideoDraftScreen extends ConsumerStatefulWidget {
  const LocalVideoDraftScreen({
    required this.draftId,
    this.returnToPlan = false,
    super.key,
  });

  final String draftId;
  final bool returnToPlan;

  @override
  ConsumerState<LocalVideoDraftScreen> createState() =>
      _LocalVideoDraftScreenState();
}

class _LocalVideoDraftScreenState extends ConsumerState<LocalVideoDraftScreen> {
  LocalVideoDraft? _draft;
  late final LocalVideoImportService _importService;
  late final LocalVideoDraftStore _draftStore;
  TextEditingController? _titleController;
  bool _isSaving = false;
  bool _wasCommitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _importService = ref.read(localVideoImportServiceProvider);
    _draftStore = ref.read(localVideoDraftStoreProvider);
    _draft = _draftStore.getById(widget.draftId);
    final draft = _draft;
    if (draft != null) {
      _titleController = TextEditingController(text: draft.suggestedTitle);
    }
  }

  @override
  void dispose() {
    _titleController?.dispose();
    final draft = _draft;
    if (!_wasCommitted && draft != null) {
      _draftStore.remove(draft.id);
      unawaited(_discardSilently(draft));
    }
    super.dispose();
  }

  Future<void> _discardSilently(LocalVideoDraft draft) async {
    try {
      await _importService.discard(draft);
    } on Object {
      // The operating system will eventually clear an orphaned cache draft.
    }
  }

  Future<void> _save({required bool startNow}) async {
    final draft = _draft;
    final controller = _titleController;
    if (draft == null || controller == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final source = await _importService.save(
        draft: draft,
        requestedTitle: controller.text,
      );
      _wasCommitted = true;
      _draftStore.remove(draft.id);
      if (!mounted) return;
      ref.invalidate(practiceSourcesProvider);
      ref.invalidate(practiceSourceByIdProvider(source.id));

      final detailLocation =
          '/library/source/${Uri.encodeComponent(source.id)}';
      if (!startNow && widget.returnToPlan) {
        context.go(
          '/plans/new?sourceId=${Uri.encodeQueryComponent(source.id)}',
        );
      } else {
        context.go(startNow ? '$detailLocation/practice' : detailLocation);
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } on Object catch (error) {
      if (!mounted) return;
      debugPrint('Failed to import local video: $error');
      setState(() {
        _isSaving = false;
        _errorMessage = '视频导入失败，请确认文件仍然可读并重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final titleController = _titleController;
    if (draft == null || titleController == null) {
      return _MissingDraftView(returnToPlan: widget.returnToPlan);
    }

    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(title: const Text('确认本地视频')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: _previewAspectRatio(draft),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.inverseSurface,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.video_file_rounded,
                            size: 64,
                            color: colors.inversePrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      key: const Key('local_video_title_field'),
                      controller: titleController,
                      enabled: !_isSaving,
                      maxLength: 300,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '练习名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _MetadataTile(
                            icon: Icons.insert_drive_file_outlined,
                            label: '文件',
                            value: draft.file.displayName,
                          ),
                          const Divider(height: 1, indent: 56),
                          _MetadataTile(
                            icon: Icons.schedule_rounded,
                            label: '时长',
                            value: draft.file.duration > Duration.zero
                                ? _formatDuration(draft.file.duration)
                                : '将在播放器中读取',
                          ),
                          const Divider(height: 1, indent: 56),
                          _MetadataTile(
                            icon: Icons.storage_rounded,
                            label: '大小',
                            value: _formatFileSize(draft.file.sizeBytes),
                          ),
                          const Divider(height: 1, indent: 56),
                          _MetadataTile(
                            icon: Icons.source_outlined,
                            label: '来源',
                            value: draft.origin == LocalVideoPickOrigin.gallery
                                ? '系统相册'
                                : '系统文件',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined, color: colors.primary),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '保存时会把视频移入 GuitarPal 的私有目录；不会修改或删除相册、下载目录中的原文件。',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage case final message?) ...[
                      const SizedBox(height: 14),
                      Text(message, style: TextStyle(color: colors.error)),
                    ],
                    if (_isSaving) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text('正在把视频保存到 GuitarPal…'),
                    ],
                    const SizedBox(height: 22),
                    if (widget.returnToPlan)
                      FilledButton.icon(
                        key: const Key('save_local_video'),
                        onPressed: _isSaving
                            ? null
                            : () => _save(startNow: false),
                        icon: const Icon(Icons.add_task_rounded),
                        label: const Text('保存并加入计划'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('save_local_video'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _save(startNow: false),
                              child: const Text('保存到练习库'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('start_local_video'),
                              onPressed: _isSaving
                                  ? null
                                  : () => _save(startNow: true),
                              child: const Text('保存并开始'),
                            ),
                          ),
                        ],
                      ),
                    TextButton(
                      onPressed: _isSaving ? null : () => context.pop(),
                      child: const Text('重新选择'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataTile extends StatelessWidget {
  const _MetadataTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

class _MissingDraftView extends StatelessWidget {
  const _MissingDraftView({required this.returnToPlan});

  final bool returnToPlan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认本地视频')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_file_outlined, size: 52),
              const SizedBox(height: 16),
              Text('这个导入草稿已经失效', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('系统回收应用后，尚未保存的临时视频需要重新选择。'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go(
                  returnToPlan ? '/create?returnTo=plan' : '/create',
                ),
                child: const Text('重新选择视频'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _previewAspectRatio(LocalVideoDraft draft) {
  final width = draft.file.width;
  final height = draft.file.height;
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 16 / 9;
  }
  return (width / height).clamp(0.65, 2.2);
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kilobytes = bytes / 1024;
  if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
  final megabytes = kilobytes / 1024;
  if (megabytes < 1024) return '${megabytes.toStringAsFixed(1)} MB';
  return '${(megabytes / 1024).toStringAsFixed(2)} GB';
}
