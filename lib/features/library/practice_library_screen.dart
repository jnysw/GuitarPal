import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/practice_source/practice_source.dart';
import '../plans/practice_plan_providers.dart';
import 'domain/practice_library_filter.dart';
import 'presentation/source_artwork.dart';
import 'practice_source_providers.dart';

class PracticeLibraryScreen extends ConsumerStatefulWidget {
  const PracticeLibraryScreen({super.key});

  @override
  ConsumerState<PracticeLibraryScreen> createState() =>
      _PracticeLibraryScreenState();
}

class _PracticeLibraryScreenState extends ConsumerState<PracticeLibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  PracticeLibraryFilter _filter = const PracticeLibraryFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSource(PracticeSource source) async {
    try {
      final opened = await ref.read(sourceLauncherProvider).open(source);
      if (!opened && mounted) _showMessage('暂时无法打开该来源');
    } on Object {
      if (mounted) _showMessage('打开失败，请检查系统中是否安装了对应应用');
    }
  }

  Future<void> _renameSource(PracticeSource source) async {
    final requestedTitle = await showDialog<String>(
      context: context,
      builder: (context) => _RenameSourceDialog(initialTitle: source.title),
    );
    if (requestedTitle == null || !mounted) return;

    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .rename(source, requestedTitle);
      if (mounted) _showMessage('已更新练习名称');
    } on FormatException catch (error) {
      if (mounted) _showMessage(error.message);
    } on Object {
      if (mounted) _showMessage('重命名失败，请稍后重试');
    }
  }

  Future<void> _deleteSource(PracticeSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除练习来源？'),
        content: Text('「${source.title}」将从练习库中移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('library_confirm_delete'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(practiceLibraryServiceProvider).delete(source);
      if (mounted) _showMessage('已删除「${source.title}」');
    } on Object {
      if (mounted) _showMessage('删除失败，请稍后重试');
    }
  }

  Future<void> _setSourceCompleted(
    PracticeSource source,
    bool completed,
  ) async {
    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .setCompleted(source, completed);
      ref.invalidate(practiceSourcesProvider);
      if (mounted) {
        _showMessage(
          completed ? '已将「${source.title}」标记为完成' : '已将「${source.title}」移回待练',
        );
      }
    } on Object {
      if (mounted) _showMessage('更新完成状态失败，请稍后重试');
    }
  }

  Future<void> _showFilters() async {
    final selected = await showModalBottomSheet<PracticeLibraryFilter>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LibraryFilterSheet(initialValue: _filter),
    );
    if (selected != null && mounted) setState(() => _filter = selected);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(practiceSourcesProvider);
    final plans = ref.watch(practicePlansProvider);
    final plannedSourceIds = switch (plans) {
      AsyncData(:final value) => value.map((plan) => plan.sourceId).toSet(),
      _ => <String>{},
    };
    return Scaffold(
      appBar: AppBar(title: const Text('我的练习库')),
      body: SafeArea(
        child: sources.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const _LibraryMessage(
            icon: Icons.error_outline_rounded,
            title: '暂时无法读取练习库',
            message: '请稍后重试。',
          ),
          data: (items) => _buildContent(items, plannedSourceIds),
        ),
      ),
    );
  }

  Widget _buildContent(
    List<PracticeSource> items,
    Set<String> plannedSourceIds,
  ) {
    final query = _query.trim().toLowerCase();
    final filtered = items
        .where((source) {
          final matchesQuery =
              query.isEmpty ||
              source.title.toLowerCase().contains(query) ||
              _platformLabel(source.platform).toLowerCase().contains(query) ||
              (source.externalId?.toLowerCase().contains(query) ?? false) ||
              (source.note?.toLowerCase().contains(query) ?? false);
          return matchesQuery &&
              _filter.matches(
                source,
                hasPlan: plannedSourceIds.contains(source.id),
              );
        })
        .toList(growable: false);
    final isNarrowed = query.isNotEmpty || _filter.isActive;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: TextField(
            key: const Key('library_search_field'),
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索名称、来源、内容 ID 或笔记',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  !isNarrowed
                      ? '共 ${items.length} 个练习来源'
                      : '找到 ${filtered.length} 项',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('library_filter_button'),
                onPressed: _showFilters,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  _filter.isActive ? '筛选 ${_filter.activeCount}' : '筛选',
                ),
              ),
            ],
          ),
        ),
        if (_filter.isActive)
          _ActiveLibraryFilters(
            filter: _filter,
            onChanged: (value) => setState(() => _filter = value),
          ),
        const SizedBox(height: 4),
        Expanded(
          child: filtered.isEmpty
              ? _LibraryMessage(
                  icon: !isNarrowed
                      ? Icons.library_music_outlined
                      : Icons.search_off_rounded,
                  title: !isNarrowed ? '练习库还是空的' : '没有找到匹配内容',
                  message: !isNarrowed
                      ? '导入本地视频，或从 B站、抖音、小红书、YouTube 分享内容到 GuitarPal。'
                      : '调整关键词或筛选条件后再试。',
                  action: !isNarrowed
                      ? FilledButton.icon(
                          key: const Key('library_empty_create'),
                          onPressed: () => context.push('/create'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('新建练习'),
                        )
                      : TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _query = '';
                              _filter = const PracticeLibraryFilter();
                            });
                          },
                          icon: const Icon(Icons.filter_alt_off_rounded),
                          label: const Text('清除搜索和筛选'),
                        ),
                )
              : ListView.separated(
                  key: const Key('library_source_list'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final source = filtered[index];
                    return _LibrarySourceCard(
                      key: ValueKey('library_source_${source.id}'),
                      source: source,
                      hasPlan: plannedSourceIds.contains(source.id),
                      onView: () => context.push(
                        '/library/source/${Uri.encodeComponent(source.id)}',
                      ),
                      onOpen: () => _openSource(source),
                      onToggleCompleted: () =>
                          _setSourceCompleted(source, !source.isCompleted),
                      onRename: () => _renameSource(source),
                      onDelete: () => _deleteSource(source),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RenameSourceDialog extends StatefulWidget {
  const _RenameSourceDialog({required this.initialTitle});

  final String initialTitle;

  @override
  State<_RenameSourceDialog> createState() => _RenameSourceDialogState();
}

class _RenameSourceDialogState extends State<_RenameSourceDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重命名练习来源'),
      content: TextField(
        key: const Key('library_rename_field'),
        controller: _controller,
        autofocus: true,
        maxLength: 300,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          labelText: '练习名称',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const Key('library_confirm_rename'),
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _LibrarySourceCard extends StatelessWidget {
  const _LibrarySourceCard({
    required this.source,
    required this.hasPlan,
    required this.onView,
    required this.onOpen,
    required this.onToggleCompleted,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final PracticeSource source;
  final bool hasPlan;
  final VoidCallback onView;
  final VoidCallback onOpen;
  final VoidCallback onToggleCompleted;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 56,
              child: SourceArtwork(
                platform: source.platform,
                thumbnailUri: source.thumbnailUri,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onView,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_platformLabel(source.platform)} · '
                        '${_canPracticeInApp(source) ? '可在 App 内练习' : '引用模式'}',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SourceStateBadge(
                            icon: source.isCompleted
                                ? Icons.check_circle_rounded
                                : Icons.pending_outlined,
                            label: source.isCompleted ? '已完成' : '待练',
                            highlighted: source.isCompleted,
                          ),
                          if (hasPlan)
                            const _SourceStateBadge(
                              icon: Icons.event_note_rounded,
                              label: '有计划',
                            ),
                          if (source.note != null)
                            const _SourceStateBadge(
                              icon: Icons.sticky_note_2_outlined,
                              label: '曲目笔记',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (source.platform != SourcePlatform.local)
              IconButton(
                tooltip: '打开原内容',
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            PopupMenuButton<_SourceAction>(
              tooltip: '更多操作',
              onSelected: (action) {
                switch (action) {
                  case _SourceAction.toggleCompleted:
                    onToggleCompleted();
                  case _SourceAction.rename:
                    onRename();
                  case _SourceAction.delete:
                    onDelete();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: ValueKey('library_toggle_completed_${source.id}'),
                  value: _SourceAction.toggleCompleted,
                  child: ListTile(
                    leading: Icon(
                      source.isCompleted
                          ? Icons.replay_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                    title: Text(source.isCompleted ? '移回待练' : '标记为完成'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _SourceAction.rename,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('重命名'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: _SourceAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('删除'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceStateBadge extends StatelessWidget {
  const _SourceStateBadge({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = highlighted ? colors.primary : colors.onSurfaceVariant;
    final background = highlighted
        ? colors.primaryContainer.withValues(alpha: 0.65)
        : colors.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ActiveLibraryFilters extends StatelessWidget {
  const _ActiveLibraryFilters({required this.filter, required this.onChanged});

  final PracticeLibraryFilter filter;
  final ValueChanged<PracticeLibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          if (filter.platform case final platform?) ...[
            InputChip(
              label: Text(_platformLabel(platform)),
              onDeleted: () => onChanged(
                PracticeLibraryFilter(
                  completion: filter.completion,
                  plan: filter.plan,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (filter.completion != LibraryCompletionFilter.all) ...[
            InputChip(
              label: Text(_completionFilterLabel(filter.completion)),
              onDeleted: () => onChanged(
                PracticeLibraryFilter(
                  platform: filter.platform,
                  plan: filter.plan,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (filter.plan != LibraryPlanFilter.all)
            InputChip(
              label: Text(_planFilterLabel(filter.plan)),
              onDeleted: () => onChanged(
                PracticeLibraryFilter(
                  platform: filter.platform,
                  completion: filter.completion,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LibraryFilterSheet extends StatefulWidget {
  const _LibraryFilterSheet({required this.initialValue});

  final PracticeLibraryFilter initialValue;

  @override
  State<_LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends State<_LibraryFilterSheet> {
  late SourcePlatform? _platform = widget.initialValue.platform;
  late LibraryCompletionFilter _completion = widget.initialValue.completion;
  late LibraryPlanFilter _plan = widget.initialValue.plan;

  PracticeLibraryFilter get _value => PracticeLibraryFilter(
    platform: _platform,
    completion: _completion,
    plan: _plan,
  );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '筛选练习库',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            const _FilterSectionTitle('来源平台'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('library_filter_platform_all'),
                  label: const Text('全部'),
                  selected: _platform == null,
                  onSelected: (_) => setState(() => _platform = null),
                ),
                for (final platform in SourcePlatform.values)
                  ChoiceChip(
                    key: ValueKey('library_filter_platform_${platform.name}'),
                    label: Text(_platformLabel(platform)),
                    selected: _platform == platform,
                    onSelected: (_) => setState(() => _platform = platform),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _FilterSectionTitle('完成状态'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in LibraryCompletionFilter.values)
                  ChoiceChip(
                    key: ValueKey('library_filter_completion_${value.name}'),
                    label: Text(_completionFilterLabel(value)),
                    selected: _completion == value,
                    onSelected: (_) => setState(() => _completion = value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _FilterSectionTitle('计划状态'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in LibraryPlanFilter.values)
                  ChoiceChip(
                    key: ValueKey('library_filter_plan_${value.name}'),
                    label: Text(_planFilterLabel(value)),
                    selected: _plan == value,
                    onSelected: (_) => setState(() => _plan = value),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('library_clear_filters'),
                    onPressed: () => setState(() {
                      _platform = null;
                      _completion = LibraryCompletionFilter.all;
                      _plan = LibraryPlanFilter.all;
                    }),
                    child: const Text('重置'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('library_apply_filters'),
                    onPressed: () => Navigator.pop(context, _value),
                    child: const Text('应用筛选'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _LibraryMessage extends StatelessWidget {
  const _LibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (action case final action?) ...[
              const SizedBox(height: 18),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

enum _SourceAction { toggleCompleted, rename, delete }

bool _canPracticeInApp(PracticeSource source) {
  return (source.platform == SourcePlatform.bilibili &&
          source.externalId != null) ||
      (source.platform == SourcePlatform.local &&
          source.kind == SourceKind.video &&
          source.canonicalUri?.scheme == 'file');
}

String _platformLabel(SourcePlatform platform) {
  return switch (platform) {
    SourcePlatform.local => '本地视频',
    SourcePlatform.youtube => 'YouTube',
    SourcePlatform.bilibili => 'Bilibili',
    SourcePlatform.douyin => '抖音',
    SourcePlatform.xiaohongshu => '小红书',
    SourcePlatform.genericWeb => '网页',
  };
}

String _completionFilterLabel(LibraryCompletionFilter value) {
  return switch (value) {
    LibraryCompletionFilter.all => '全部',
    LibraryCompletionFilter.pending => '待练',
    LibraryCompletionFilter.completed => '已完成',
  };
}

String _planFilterLabel(LibraryPlanFilter value) {
  return switch (value) {
    LibraryPlanFilter.all => '全部',
    LibraryPlanFilter.planned => '有计划',
    LibraryPlanFilter.unplanned => '无计划',
  };
}
