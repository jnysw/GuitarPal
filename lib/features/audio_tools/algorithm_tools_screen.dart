import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/practice_recording/practice_recording.dart';
import '../recordings/practice_recording_providers.dart';
import 'algorithm_providers.dart';
import 'data/algorithm_audio_import.dart';
import 'data/legacy_algorithm_api.dart';
import 'domain/algorithm_task.dart';
import 'domain/algorithm_configuration.dart';
import 'domain/legacy_algorithm_models.dart';
import 'separation_result_screen.dart';

class AlgorithmToolsScreen extends ConsumerStatefulWidget {
  const AlgorithmToolsScreen({super.key});
  @override
  ConsumerState<AlgorithmToolsScreen> createState() =>
      _AlgorithmToolsScreenState();
}

class _AlgorithmToolsScreenState extends ConsumerState<AlgorithmToolsScreen>
    with WidgetsBindingObserver {
  final _endpoint = TextEditingController(text: AlgorithmConfiguration.baseUrl);
  AlgorithmAudioInput? _input;
  Timer? _timer;
  bool _busy = false, _polling = false, _foreground = true;
  bool _inputInSubmission = false;
  bool _showingResult = false;
  late final AlgorithmAudioImport _importer;
  double? _uploadProgress;
  List<AlgorithmTaskRecord> _tasks = [];
  AlgorithmOperation _operation = AlgorithmOperation.chords;

  @override
  void initState() {
    super.initState();
    _importer = ref.read(algorithmAudioImportProvider);
    WidgetsBinding.instance.addObserver(this);
    if (kDebugMode) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await ref
        .read(algorithmTaskRepositoryProvider)
        .recoverInterruptedSubmissions();
    if (mounted) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!mounted || !_foreground || _showingResult) return;
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshPending()),
    );
    unawaited(_refreshPending());
  }

  Future<void> _refreshPending() async {
    if (_polling || !_foreground || _showingResult || !mounted) return;
    _polling = true;
    final service = ref.read(algorithmTaskServiceProvider);
    try {
      for (final task in _tasks.where((t) => t.shouldPoll).take(5).toList()) {
        if (!mounted || !_foreground || _showingResult) break;
        await service.refresh(task.id);
      }
    } finally {
      _polling = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _startPolling();
    } else {
      _timer?.cancel();
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _replaceInput(AlgorithmAudioInput? input) async {
    if (input == null) return;
    final previous = _input;
    if (mounted) setState(() => _input = input);
    if (previous?.owned == true) {
      await ref.read(algorithmAudioImportProvider).deleteInput(previous!.path);
    }
  }

  Future<void> _pickAudio() async {
    setState(() => _busy = true);
    final importer = ref.read(algorithmAudioImportProvider);
    try {
      final input = await importer.pickAudio();
      if (!mounted) {
        if (input?.owned == true) await importer.deleteInput(input!.path);
        return;
      }
      await _replaceInput(input);
    } on Object catch (error) {
      _message(error is FormatException ? error.message : '无法导入音频，请重新选择');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickRecording() async {
    setState(() => _busy = true);
    late final List<PracticeRecording> recordings;
    try {
      recordings = await ref.read(practiceRecordingsProvider.future);
    } on Object {
      _message('无法读取本机录音');
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (recordings.isEmpty) {
      _message('还没有可用录音，请先录制或选择音频文件');
      return;
    }
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('选择我的录音')),
            for (final recording in recordings)
              ListTile(
                title: Text(recording.title),
                subtitle: Text('${recording.duration.inSeconds} 秒'),
                onTap: () => Navigator.pop(context, recording.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final recording = recordings.firstWhere((r) => r.id == selected);
    setState(() => _busy = true);
    try {
      final path = await ref
          .read(practiceAudioRecorderProvider)
          .resolveAbsolutePath(recording.filePath);
      final length = await File(path).length();
      if (!mounted) return;
      await _replaceInput(
        AlgorithmAudioInput(
          path: path,
          name: '${recording.title}.m4a',
          sizeBytes: length,
          duration: recording.duration,
          owned: false,
          recordingId: recording.id,
        ),
      );
    } on Object {
      _message('录音文件已失效或无法读取');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final input = _input;
    if (_busy || input == null) return;
    late AlgorithmEndpoint endpoint;
    try {
      endpoint = AlgorithmEndpoint(_endpoint.text, allowLocalHttp: kDebugMode);
      if (input.sizeBytes <= 0 ||
          input.sizeBytes > LegacyAlgorithmApi.maximumInputBytes ||
          input.duration.inMilliseconds < 2000 ||
          input.duration.inMilliseconds > 600000) {
        throw const FormatException('请选择 2 秒至 10 分钟、非空且不超过 50 MiB 的音频');
      }
    } on FormatException catch (error) {
      _message(error.message);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _operation == AlgorithmOperation.chords ? '上传音频进行和弦分析？' : '上传音频进行分轨？',
        ),
        content: Text(
          '「${input.name}」\n${(input.sizeBytes / 1048576).toStringAsFixed(2)} MiB，${input.duration.inSeconds} 秒\n'
          '接收服务器：${endpoint.origin}\n\n仅本次所选音频会上传。当前测试服务无内置账号鉴权；'
          '${_operation == AlgorithmOperation.chords ? '旧版结果不能精确同步原曲，置信度不可用。' : '服务器音轨仅保留 24 小时，请及时下载到本机。'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('algorithm_confirm_upload'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('上传并分析'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final now = DateTime.now().toUtc();
    final task = AlgorithmTaskRecord(
      id: const Uuid().v4(),
      operation: _operation,
      endpoint: endpoint.origin.toString(),
      inputPath: input.path,
      inputName: input.name,
      inputSizeBytes: input.sizeBytes,
      inputDurationMs: input.duration.inMilliseconds,
      ownsInput: input.owned,
      recordingId: input.recordingId,
      state: AlgorithmTaskState.submitting,
      createdAt: now,
      updatedAt: now,
      failures: 0,
    );
    setState(() {
      _busy = true;
      _uploadProgress = 0;
    });
    _inputInSubmission = true;
    // Repository takes ownership before the network request; it also records an
    // uncertain receipt. Leaving the page must not delete that task's input.
    final service = ref.read(algorithmTaskServiceProvider);
    try {
      await service.submit(
        task,
        onProgress: (sent, total) {
          if (mounted) setState(() => _uploadProgress = sent / total);
        },
      );
      if (mounted) setState(() => _input = null);
      unawaited(_refreshPending());
    } on Object {
      if (!mounted && input.owned) {
        await _importer.deleteInput(input.path);
      }
      _message('无法保存分析任务，请稍后重试');
    } finally {
      _inputInSubmission = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _ping() async {
    if (_busy) return;
    setState(() => _busy = true);
    LegacyAlgorithmApi? api;
    try {
      api = LegacyAlgorithmApi(
        AlgorithmEndpoint(_endpoint.text, allowLocalHttp: kDebugMode),
      );
      await api.ping();
      _message('服务进程可连接；模型是否就绪需实际提交验证');
    } on Object catch (error) {
      _message(error is FormatException ? error.message : error.toString());
    } finally {
      api?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTask(AlgorithmTaskRecord task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除本机任务记录？'),
        content: const Text('移除本机分析结果、已下载音轨和为分析导入的音频副本，已有练习录音保留。服务器任务会继续执行。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (task.operation == AlgorithmOperation.separation) {
        await ref.read(algorithmStemStoreProvider).deleteTask(task.id);
      }
      if (task.ownsInput) {
        await ref
            .read(algorithmAudioImportProvider)
            .deleteInput(task.inputPath);
      }
      await ref.read(algorithmTaskRepositoryProvider).delete(task.id);
    } on Object {
      _message('无法清理本机任务，请重试');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _endpoint.dispose();
    final input = _input;
    if (input?.owned == true && !_inputInSubmission) {
      unawaited(_importer.deleteInput(input!.path).catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: Center(child: Text('此入口仅用于开发联调')));
    }
    final tasks = ref.watch(algorithmTasksProvider);
    tasks.whenData((values) {
      _tasks = values;
      if (_endpoint.text.isEmpty && values.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _endpoint.text.isEmpty) {
            _endpoint.text = values.first.endpoint;
          }
        });
      }
    });
    return Scaffold(
      appBar: AppBar(title: const Text('音频工具（实验）')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '音频分析测试',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('选择自有音频或练习录音，确认后上传到你的算法服务。视频区间提取仍在开发。'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('algorithm_endpoint'),
              controller: _endpoint,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: '算法服务地址',
                hintText: '填写 Tailscale HTTPS 服务源地址',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _ping,
                icon: const Icon(Icons.wifi_find),
                label: const Text('检查连接'),
              ),
            ),
            SegmentedButton<AlgorithmOperation>(
              segments: const [
                ButtonSegment(
                  value: AlgorithmOperation.chords,
                  label: Text('和弦分析'),
                  icon: Icon(Icons.music_note),
                ),
                ButtonSegment(
                  value: AlgorithmOperation.separation,
                  label: Text('分离音轨'),
                  icon: Icon(Icons.multitrack_audio),
                ),
              ],
              selected: {_operation},
              onSelectionChanged: _busy
                  ? null
                  : (values) => setState(() => _operation = values.single),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('algorithm_pick_audio'),
                  onPressed: _busy ? null : _pickAudio,
                  icon: const Icon(Icons.audio_file_outlined),
                  label: const Text('选择音频文件'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickRecording,
                  icon: const Icon(Icons.mic_none),
                  label: const Text('我的录音'),
                ),
              ],
            ),
            if (_input case final input?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(input.name),
                subtitle: Text(
                  '${input.duration.inSeconds} 秒 · ${(input.sizeBytes / 1048576).toStringAsFixed(2)} MiB',
                ),
              ),
            FilledButton.icon(
              key: const Key('algorithm_submit'),
              onPressed: _busy || _input == null ? null : _submit,
              icon: const Icon(Icons.music_note_outlined),
              label: Text(
                _operation == AlgorithmOperation.chords ? '分析和弦' : '开始分轨',
              ),
            ),
            if (_uploadProgress != null) ...[
              LinearProgressIndicator(value: _uploadProgress),
              const Text('上传字节进度；上传完成后仍需等待服务器分析'),
            ],
            const SizedBox(height: 20),
            if (_operation == AlgorithmOperation.separation)
              const Text('分离人声、鼓、贝斯、吉他、钢琴、其他，以及派生伴奏。完成后逐条下载，可离线试听。'),
            const Divider(),
            const Text(
              '分析任务',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('离开页面或进入后台会停止查询；重新进入可继续。停止查询不会取消服务器任务。'),
            tasks.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('任务记录暂时无法读取'),
              data: (values) => Column(
                children: [
                  if (values.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('还没有分析任务'),
                    ),
                  for (final task in values)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.inputName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(_taskLabel(task.state)),
                            Text(
                              task.operation == AlgorithmOperation.chords
                                  ? '和弦分析'
                                  : '分离音轨',
                            ),
                            if (task.message != null) Text(task.message!),
                            if (task.shouldPoll)
                              LinearProgressIndicator(
                                value: task.progress == null
                                    ? null
                                    : task.progress! / 100,
                              ),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (task.resultJson != null)
                                  TextButton(
                                    onPressed: () async {
                                      _showingResult = true;
                                      _timer?.cancel();
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              task.operation ==
                                                  AlgorithmOperation.chords
                                              ? _ChordResultScreen(task: task)
                                              : SeparationResultScreen(
                                                  task: task,
                                                ),
                                        ),
                                      );
                                      _showingResult = false;
                                      if (mounted && _foreground) {
                                        _startPolling();
                                      }
                                    },
                                    child: const Text('查看离线结果'),
                                  ),
                                if (task.remoteJobId != null &&
                                    task.resultJson == null &&
                                    task.state != AlgorithmTaskState.failed)
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => ref
                                              .read(
                                                algorithmTaskServiceProvider,
                                              )
                                              .refresh(task.id, force: true),
                                    child: const Text('重新查询'),
                                  ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _deleteTask(task),
                                  child: const Text('移除本机记录'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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

String _taskLabel(AlgorithmTaskState state) => switch (state) {
  AlgorithmTaskState.submitting => '正在上传',
  AlgorithmTaskState.submissionUnknown => '接收状态未知',
  AlgorithmTaskState.queued => '排队中',
  AlgorithmTaskState.processing => '正在分析',
  AlgorithmTaskState.completed => '已完成 · 可离线查看',
  AlgorithmTaskState.failed => '分析失败',
  AlgorithmTaskState.unavailable => '等待恢复连接',
  AlgorithmTaskState.lost => '服务器任务已失效',
  AlgorithmTaskState.invalidResult => '响应待修复',
};

class _ChordResultScreen extends StatelessWidget {
  const _ChordResultScreen({required this.task});
  final AlgorithmTaskRecord task;
  @override
  Widget build(BuildContext context) {
    try {
      final result = LegacyChordResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
      );
      return Scaffold(
        appBar: AppBar(title: const Text('和弦分析结果')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(task.inputName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('旧版服务使用裁剪静音后的分析时间轴。以下时间暂不用于原曲定位或 A-B；模型置信度不可用。'),
            if (result.keyEstimate.isNotEmpty)
              Text('调性（估计）：${result.keyEstimate}'),
            if (result.progression.isNotEmpty)
              Text('进行参考：${result.progression}'),
            if (result.segments.isEmpty) const Text('本次没有可展示的和弦片段'),
            for (final segment in result.segments)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(segment.displayLabel),
                subtitle: Text(
                  '${_time(segment.start)} – ${_time(segment.end)}${segment.roman.isEmpty ? '' : ' · ${segment.roman}'}',
                ),
                trailing: segment.rawLabel == segment.displayLabel
                    ? null
                    : Text(segment.rawLabel),
              ),
          ],
        ),
      );
    } on Object {
      return Scaffold(
        appBar: AppBar(title: const Text('和弦分析结果')),
        body: const Center(child: Text('本机结果无法解析，原始记录已保留')),
      );
    }
  }
}

String _time(Duration value) =>
    '${value.inMinutes}:${(value.inSeconds % 60).toString().padLeft(2, '0')}.${(value.inMilliseconds % 1000).toString().padLeft(3, '0')}';
