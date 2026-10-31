import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/practice_source/practice_source.dart';
import '../../../media/playback/local_video_playback_controller.dart';
import '../../../media/playback/loop_controller.dart';
import '../../audio_tools/algorithm_providers.dart';
import '../../audio_tools/data/algorithm_audio_import.dart';
import '../../audio_tools/data/algorithm_stem_store.dart';
import '../../audio_tools/domain/algorithm_task.dart';
import '../../audio_tools/domain/legacy_algorithm_models.dart';
import '../../audio_tools/domain/video_analysis_binding.dart';
import '../../audio_tools/domain/video_mix_selection.dart';
import '../../audio_tools/domain/video_stem_choice.dart';
import '../../audio_tools/domain/video_chord_playback.dart';
import '../../audio_tools/domain/stem_mix_settings.dart';
import '../../audio_tools/data/video_mix_preferences.dart';
import 'video_analysis_timeline.dart';
import 'video_stem_mixer.dart';
import 'separation_processing_details.dart';
import 'video_stem_picker.dart';

/// In-place tools for the current video. This never starts another practice session.
class VideoAnalysisPanel extends ConsumerStatefulWidget {
  const VideoAnalysisPanel({
    required this.source,
    required this.path,
    required this.controller,
    this.planId,
    this.enabled = true,
    this.requestedOperation,
    this.requestRevision = 0,
    this.onSaveLoop,
    this.recordingActive = false,
    super.key,
  });
  final PracticeSource source;
  final String path;
  final LocalVideoPlaybackController controller;
  final String? planId;
  final bool enabled;
  final AlgorithmOperation? requestedOperation;
  final int requestRevision;
  final VoidCallback? onSaveLoop;
  final bool recordingActive;
  @override
  ConsumerState<VideoAnalysisPanel> createState() => _VideoAnalysisPanelState();
}

class _VideoAnalysisPanelState extends ConsumerState<VideoAnalysisPanel>
    with WidgetsBindingObserver {
  bool _expanded = false,
      _busy = false,
      _polling = false,
      _foreground = true,
      _useRange = false;
  bool _confirming = false;
  bool _choosingStems = false;
  final _expansion = ExpansibleController();
  AlgorithmOperation _operation = AlgorithmOperation.chords;
  String _endpoint = '', _stage = '';
  Future<void>? _configurationFuture;
  String? _serviceNotice;
  double? _progress;
  Timer? _timer;
  List<AlgorithmTaskRecord> _tasks = [];
  Map<String, double> _volumes = {}, _pans = {};
  final Set<String> _muted = {}, _solo = {};
  late final VideoMixPreferences _preferences;
  VideoMixSelection? _saved;
  AlgorithmTaskRecord? _pendingRestore, _rememberedTask;
  String? _loadedTaskId, _restoreNotice;
  bool _loadingStems = false, _saveFailed = false, _userNavigated = false;
  int _generation = 0;
  StemDownloadCancellation? _downloadCancellation;
  bool _networkDownload = false;
  String? _downloadNotice;
  @override
  void initState() {
    super.initState();
    _endpoint = ref.read(algorithmEndpointProvider).trim();
    if (_endpoint.trim().isEmpty) {
      _configurationFuture = _resolveConfiguration();
    }
    _preferences = ref.read(videoMixPreferencesProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      ref
          .read(algorithmTaskServiceProvider)
          .initialize()
          .catchError((Object _) {}),
    );
    unawaited(_restoreSelection());
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  @override
  void didUpdateWidget(covariant VideoAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _downloadCancellation?.cancel();
      _downloadCancellation = null;
      _networkDownload = false;
      _generation++;
      _loadedTaskId = null;
      _pendingRestore = null;
      _busy = _loadingStems = false;
      unawaited(_restoreSelection());
    }
    if (widget.recordingActive && !oldWidget.recordingActive) {
      _cancelStemLoad(_saved == null ? '录音期间使用视频原声' : '录音期间使用视频原声，分轨设置已保留');
    }
    if (widget.enabled && _pendingRestore != null && !widget.recordingActive) {
      final task = _pendingRestore!;
      _pendingRestore = null;
      unawaited(_loadStems(task, restoring: true));
    }
    if (widget.requestRevision != oldWidget.requestRevision &&
        widget.requestedOperation != null &&
        !_busy) {
      _operation = widget.requestedOperation!;
      _userNavigated = true;
      _open(true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _expansion.expand();
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  Future<void> _restoreSelection() async {
    final token = _generation;
    final repository = ref.read(algorithmTaskRepositoryProvider);
    try {
      final saved = await _preferences.load(widget.source.id);
      if (!mounted || token != _generation || saved == null) return;
      final task = await repository.get(saved.taskId);
      if (!mounted || token != _generation) return;
      if (task == null ||
          task.state != AlgorithmTaskState.completed ||
          task.linkedSourceId != widget.source.id ||
          task.operation != AlgorithmOperation.separation ||
          task.resultJson == null ||
          task.mediaBindingJson == null) {
        throw const FormatException('上次分轨记录已不存在，请重新选择分析结果');
      }
      final binding = _binding(task);
      await _verify(binding);
      if (saved.inputSha256 != binding.inputSha256) {
        throw const FormatException('上次分轨的输入已变化，请重新选择');
      }
      if (!mounted || token != _generation) return;
      setState(() {
        _saved = saved;
        _rememberedTask = task;
        if (!_userNavigated) _operation = AlgorithmOperation.separation;
        _restoreNotice = saved.useStems ? null : '上次选择：视频原声，分轨音量设置已保留';
      });
      if (saved.useStems && !widget.recordingActive) {
        if (widget.enabled) {
          await _loadStems(task, restoring: true);
        } else {
          _pendingRestore = task;
        }
      }
    } on MissingPluginException {
      // Non-Android/widget-only hosts have no private media directory.
    } on Object catch (e) {
      if (mounted && token == _generation) {
        setState(() => _restoreNotice = _errorMessage(e, '无法读取上次分轨设置，可手动载入'));
      }
    }
  }

  void _cancelStemLoad(String notice) {
    _downloadCancellation?.cancel();
    _generation++;
    _pendingRestore = null;
    final shouldClear = _loadingStems || widget.controller.stemsLoaded;
    if (_loadingStems) _busy = false;
    _loadingStems = false;
    _networkDownload = false;
    _loadedTaskId = null;
    _restoreNotice = notice;
    if (shouldClear) {
      final token = _generation;
      final controller = widget.controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            token == _generation &&
            identical(widget.controller, controller)) {
          unawaited(controller.clearStems().catchError((Object _) {}));
        }
      });
    }
  }

  bool _canLoad(int token) =>
      mounted &&
      token == _generation &&
      widget.enabled &&
      !widget.recordingActive &&
      _foreground;

  Future<void> _persist(VideoMixSelection selection) async {
    _saved = selection;
    try {
      await _preferences.save(widget.source.id, selection);
      if (mounted && identical(_saved, selection)) {
        setState(() => _saveFailed = false);
      }
    } on Object {
      if (mounted && identical(_saved, selection)) {
        setState(() => _saveFailed = true);
      }
    }
  }

  VideoMixSelection _currentSelection() => VideoMixSelection(
    taskId: _rememberedTask!.id,
    inputSha256: _binding(_rememberedTask!).inputSha256,
    useStems: true,
    selectedTrackIds: _volumes.keys,
    controls: {
      if (_saved?.taskId == _rememberedTask!.id &&
          _saved?.inputSha256 == _binding(_rememberedTask!).inputSha256)
        ..._saved!.controls,
      for (final id in _volumes.keys)
        id: StemMixControl(
          volume: _volumes[id] ?? 1,
          muted: _muted.contains(id),
          solo: _solo.contains(id),
          pan: _pans[id] ?? 0,
        ),
    },
  );

  Future<void> _useOriginal() async {
    if (_busy || !widget.enabled) return;
    final token = ++_generation;
    _pendingRestore = null;
    try {
      await widget.controller.clearStems();
      if (!mounted || token != _generation) return;
      setState(() {
        _loadedTaskId = null;
        _restoreNotice = '已切回视频原声，分轨设置已保留';
      });
      if (_saved != null) await _persist(_saved!.withMode(false));
    } on Object {
      _message('切回原声失败，请重试');
    }
  }

  void _open(bool value) {
    if (_expanded == value) return;
    setState(() => _expanded = value);
    _timer?.cancel();
    if (value) {
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_refresh()),
      );
      unawaited(_refresh());
    }
  }

  Future<void> _refresh() async {
    if (_polling || !_expanded || !_foreground || !mounted) return;
    _polling = true;
    final service = ref.read(algorithmTaskServiceProvider);
    try {
      for (final task in _tasks.where((t) => t.shouldPoll).take(4)) {
        if (!mounted || !_foreground || !_expanded) break;
        await service.refresh(task.id);
      }
    } on Object {
      /* Task cards retain their last durable status. */
    } finally {
      _polling = false;
    }
  }

  Future<void> _resolveConfiguration() async {
    final configuration = ref.read(algorithmServiceConfigurationProvider);
    try {
      final value = await configuration.load();
      if (!mounted) return;
      final origin = AlgorithmEndpoint(
        value,
        allowLocalHttp: true,
      ).origin.toString();
      setState(() {
        _endpoint = origin;
        _serviceNotice = null;
      });
    } on Object {
      if (mounted) setState(() => _serviceNotice = '分析服务暂不可用，请稍后重试');
    }
  }

  Future<void> _retryConnection() async {
    if (_busy || _confirming || !widget.enabled) return;
    final service = ref.read(algorithmTaskServiceProvider);
    setState(() {
      _busy = true;
      _stage = '正在连接分析服务…';
      _progress = null;
    });
    try {
      if (_endpoint.trim().isEmpty) {
        await (_configurationFuture = _resolveConfiguration());
      }
      if (!mounted || _endpoint.trim().isEmpty) return;
      await service.checkConnection(_endpoint, operation: _operation);
      if (mounted) {
        setState(() => _serviceNotice = null);
        _message('分析服务已连接');
      }
    } on FormatException {
      if (mounted) setState(() => _serviceNotice = '分析服务暂不可用，请稍后重试');
    } on Object catch (e) {
      if (mounted) {
        setState(() => _serviceNotice = _errorMessage(e, '分析服务暂不可用，请稍后重试'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = '';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_busy || _confirming || !widget.enabled) return;
    _confirming = true;
    try {
      await _prepareAndSubmit();
    } finally {
      _confirming = false;
    }
  }

  Future<void> _prepareAndSubmit() async {
    if (_endpoint.isEmpty) {
      await (_configurationFuture ??= _resolveConfiguration());
      if (!mounted || _endpoint.isEmpty) return;
    }
    final controller = widget.controller;
    await controller.requestSnapshot();
    if (!mounted) return;
    final sourceDurationMs = controller.duration.inMilliseconds;
    if (!controller.isReady || sourceDurationMs <= 0) {
      _message('视频尚未就绪，请稍后再试');
      return;
    }
    final range = _useRange ? controller.loopController.range : null;
    if (_useRange && range == null) {
      _message('请先设置 A-B 区间，再开始分析');
      return;
    }
    final start = range?.start.inMilliseconds ?? 0;
    final end = range?.end.inMilliseconds ?? sourceDurationMs;
    if (end > sourceDurationMs) {
      _message('当前 A-B 超出视频时长，请调整区间后重试');
      return;
    }
    if (end - start < 2000 || end - start > 600000) {
      _message('请选择 2 秒至 10 分钟的视频或 A-B 区间');
      return;
    }
    late AlgorithmEndpoint endpoint;
    try {
      endpoint = AlgorithmEndpoint(_endpoint, allowLocalHttp: true);
    } on FormatException {
      setState(() => _serviceNotice = '分析服务暂不可用，请稍后重试');
      return;
    }
    await controller.pause();
    if (!mounted) return;
    if (_operation == AlgorithmOperation.separation) {
      final stat = await File(widget.path).stat();
      AlgorithmTaskRecord? existing;
      for (final task in _tasks) {
        if (task.operation != _operation ||
            task.resultJson == null ||
            task.mediaBindingJson == null) {
          continue;
        }
        try {
          final b = _binding(task);
          if (b.startMs == start &&
              b.endMs == end &&
              b.matches(widget.source.id, widget.path, stat)) {
            LegacySeparationResult.fromJson(
              algorithmObject(jsonDecode(task.resultJson!)),
              AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
            );
            existing = task;
            break;
          }
        } on FormatException {
          /* skip invalid old results */
        }
      }
      if (existing != null) {
        if (!mounted) return;
        final reuse = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('这个区间已经分过轨'),
            content: const Text('可直接使用已有结果，继续未完成的下载，不用再次等待算法计算。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('重新分析'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('使用已有结果'),
              ),
            ],
          ),
        );
        if (reuse == null || !mounted) return;
        if (reuse) {
          await _loadStems(existing);
          return;
        }
      }
    }
    if (!mounted) return;
    final previousUnknown = _tasks.any((t) {
      if (t.operation != _operation ||
          t.state != AlgorithmTaskState.submissionUnknown ||
          t.mediaBindingJson == null) {
        return false;
      }
      try {
        final b = _binding(t);
        return b.startMs == start && b.endMs == end;
      } on FormatException {
        return false;
      }
    });
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _operation == AlgorithmOperation.chords ? '分析当前视频的和弦？' : '分离当前视频的音轨？',
        ),
        content: Text(
          '「${widget.source.title}」\n${_time(start)}–${_time(end)}\n仅提取并上传此区间的音频用于分析，视频保留在本机。${_operation == AlgorithmOperation.separation && end - start > 60000 ? '\n长音频的计算与下载分别耗时。可取消并先设置较短 A-B，只分离需要练习的片段。' : ''}${previousUnknown ? '\n上次相同区间尚未确认接收状态，继续可能产生重复任务。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('video_analysis_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('开始分析'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final extractor = ref.read(videoAudioExtractorProvider);
    final importer = ref.read(algorithmAudioImportProvider);
    final service = ref.read(algorithmTaskServiceProvider);
    final repository = ref.read(algorithmTaskRepositoryProvider);
    final taskId = const Uuid().v4();
    AlgorithmAudioInput? input;
    bool handedOff = false;
    setState(() {
      _busy = true;
      _stage = '正在连接分析服务…';
      _serviceNotice = null;
      _progress = null;
    });
    try {
      await service.checkConnection(
        endpoint.origin.toString(),
        operation: _operation,
      );
      if (!mounted) return;
      setState(() => _stage = '正在提取当前视频音频…');
      final before = await File(widget.path).stat();
      final extracted = await extractor.extract(
        widget.path,
        start,
        end,
        sourceDurationMs: sourceDurationMs,
      );
      input = extracted.input;
      if (!mounted) return;
      final after = await File(widget.path).stat();
      if (before.size != after.size || before.modified != after.modified) {
        throw const FormatException('视频文件已变化，请重试');
      }
      final binding = VideoAnalysisBinding(
        sourceId: widget.source.id,
        path: widget.path,
        sourceBytes: before.size,
        modifiedMs: before.modified.millisecondsSinceEpoch,
        sourceDurationMs: sourceDurationMs,
        startMs: start,
        durationMs: end - start,
        inputSha256: extracted.sha256,
        waveform: extracted.waveform,
      );
      final now = DateTime.now().toUtc();
      setState(() => _stage = '正在上传音频…');
      await service.submit(
        AlgorithmTaskRecord(
          id: taskId,
          endpoint: endpoint.origin.toString(),
          inputPath: input.path,
          inputName: 'video-audio.wav',
          inputSizeBytes: input.sizeBytes,
          inputDurationMs: input.duration.inMilliseconds,
          ownsInput: true,
          state: AlgorithmTaskState.submitting,
          createdAt: now,
          updatedAt: now,
          failures: 0,
          operation: _operation,
          linkedSourceId: widget.source.id,
          linkedPlanId: widget.planId,
          mediaBindingJson: jsonEncode(binding.toJson()),
        ),
        onProgress: (sent, total) {
          if (mounted) {
            setState(() {
              _progress = sent / total;
              _stage = sent == total ? '音频已发送，等待服务器回执…' : '正在上传音频…';
            });
          }
        },
      );
      handedOff = true;
      unawaited(_refresh());
    } on Object catch (e) {
      try {
        handedOff = await repository.get(taskId) != null;
      } on Object {
        handedOff = true;
      }
      final message = _errorMessage(e, '分析准备失败，请稍后重试');
      if (mounted && e is AlgorithmApiError) {
        setState(() => _serviceNotice = message);
      }
      _message(message);
    } finally {
      if (input != null && !handedOff) {
        await importer.deleteInput(input.path).catchError((Object _) {});
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _stage = '';
          _progress = null;
        });
      }
    }
  }

  VideoAnalysisBinding _binding(AlgorithmTaskRecord task) =>
      VideoAnalysisBinding.fromJson(
        algorithmObject(jsonDecode(task.mediaBindingJson!)),
      );
  Future<void> _verify(VideoAnalysisBinding binding) async {
    if (!binding.matches(
      widget.source.id,
      widget.path,
      await File(widget.path).stat(),
    )) {
      throw const FormatException('视频文件已变化，此结果不能用于当前视频，请重新分析');
    }
  }

  Future<void> _loadStems(
    AlgorithmTaskRecord task, {
    bool restoring = false,
    Iterable<String>? trackIds,
    bool localOnly = false,
  }) async {
    if (_busy || !widget.enabled || widget.recordingActive) return;
    if (restoring && widget.controller.isPlaying) {
      setState(() => _restoreNotice = '视频已开始播放，保留原声；可手动恢复上次分轨');
      return;
    }
    final token = ++_generation;
    _pendingRestore = null;
    final controller = widget.controller;
    final store = ref.read(algorithmStemStoreProvider);
    final cancellation = StemDownloadCancellation();
    _downloadCancellation = cancellation;
    setState(() {
      _busy = _loadingStems = true;
      _networkDownload = !restoring && !localOnly;
      _downloadNotice = null;
      _stage = restoring ? '正在恢复本机分轨…' : '正在准备当前视频的音轨…';
    });
    try {
      if (!restoring) await controller.pause();
      final binding = _binding(task);
      await _verify(binding);
      if (!_canLoad(token)) return;
      final result = LegacySeparationResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
        AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
      );
      if ((result.duration.inMilliseconds - binding.durationMs).abs() > 100) {
        throw const FormatException('分轨时间轴与本视频区间不一致');
      }
      final previous =
          _saved?.taskId == task.id &&
              _saved?.inputSha256 == binding.inputSha256
          ? _saved
          : null;
      final chosen = videoStemSubset(
        result,
        trackIds ??
            previous?.selectedTrackIds ??
            result.mixStems.map((s) => s.id),
      );
      final paths = <String, String>{};
      if (restoring || localOnly) {
        for (final stem in chosen) {
          if (!_canLoad(token)) return;
          final file = await store.localFile(task.id, stem);
          if (file == null) {
            throw FormatException(
              restoring ? '本机分轨尚未完整，保留原声；点击继续下载，只补齐缺失部分' : '所选音轨已不在本机，请重新选择或下载',
            );
          }
          paths[stem.id] = file.path;
        }
      } else {
        paths.addAll(
          await store.downloadBatch(
            task.id,
            chosen,
            cancellation: cancellation,
            onProgress: (p) {
              if (!_canLoad(token)) return;
              setState(() {
                final speed = p.bytesPerSecond > 0
                    ? ' · ${_bytes(p.bytesPerSecond.round())}/s'
                    : '';
                final eta = p.remaining == null
                    ? ''
                    : ' · 约剩 ${p.remaining!.inSeconds} 秒';
                _stage =
                    '下载音轨 ${p.completedFiles}/${p.totalFiles} · ${_bytes(p.receivedBytes)}/${_bytes(p.totalBytes)}$speed$eta';
                _progress = p.fraction;
              });
            },
          ),
        );
      }
      if (!_canLoad(token)) return;
      setState(() {
        _networkDownload = false;
        _stage = '音轨已就绪，正在本机解码并载入混音…';
        _progress = null;
      });
      await _verify(binding);
      if (!_canLoad(token)) return;
      final selection =
          _saved?.taskId == task.id &&
              _saved?.inputSha256 == binding.inputSha256
          ? _saved!
                .withMode(true)
                .forTracks(
                  paths.keys,
                  availableIds: result.stems.map((s) => s.id),
                )
          : VideoMixSelection(
              taskId: task.id,
              inputSha256: binding.inputSha256,
              useStems: true,
              selectedTrackIds: paths.keys,
              controls: {
                for (final stem in result.stems)
                  stem.id: const StemMixControl(),
              },
            );
      await controller.loadStems(
        paths,
        binding.startMs,
        binding.durationMs,
        preservePosition: restoring,
        onlyIfPaused: restoring,
        initialGains: selection.gains,
      );
      if (!_canLoad(token)) return;
      if (controller.supportsStemPan) {
        await controller.setStemPans(selection.pans);
      }
      if (!_canLoad(token)) return;
      setState(() {
        _pans = selection.pans;
        _rememberedTask = task;
        _loadedTaskId = task.id;
        _volumes = {
          for (final id in paths.keys) id: selection.controls[id]!.volume,
        };
        _muted
          ..clear()
          ..addAll(
            selection.activeControls.entries
                .where((e) => e.value.muted)
                .map((e) => e.key),
          );
        _solo
          ..clear()
          ..addAll(
            selection.activeControls.entries
                .where((e) => e.value.solo)
                .map((e) => e.key),
          );
        _restoreNotice = restoring ? '已恢复上次分轨设置，点击播放即可练习' : null;
      });
      await _persist(selection);
    } on Object catch (e) {
      if (mounted && token == _generation) {
        final message = e is StemDownloadPaused
            ? e.toString()
            : _errorMessage(e, '分轨载入失败；已下载文件保留，可直接重试载入，无需重新分析');
        if (restoring) {
          setState(() => _restoreNotice = message);
        } else {
          setState(() => _downloadNotice = message);
          _message(message);
        }
      }
    } finally {
      if (mounted && token == _generation) {
        _downloadCancellation = null;
        setState(() {
          _busy = _loadingStems = false;
          _networkDownload = false;
          _stage = '';
          _progress = null;
        });
      }
    }
  }

  Future<void> _applyGains() async {
    if (_loadedTaskId == null || !widget.enabled || widget.recordingActive) {
      return;
    }
    final selection = _currentSelection();
    final saving = _persist(selection);
    try {
      await widget.controller.setStemGains(selection.gains);
      if (widget.controller.supportsStemPan) {
        await widget.controller.setStemPans(selection.pans);
      }
    } on Object {
      _message('音轨控制失败，请重新载入分轨');
    }
    await saving;
  }

  Future<void> _chooseStems(AlgorithmTaskRecord task) async {
    if (_busy || _choosingStems || !widget.enabled || widget.recordingActive) {
      return;
    }
    _choosingStems = true;
    try {
      final binding = _binding(task);
      await _verify(binding);
      if (!mounted) return;
      final result = LegacySeparationResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
        AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
      );
      final initial =
          _saved?.taskId == task.id &&
              _saved?.inputSha256 == binding.inputSha256
          ? _saved!.selectedTrackIds ?? result.mixStems.map((s) => s.id)
          : result.mixStems.map((s) => s.id);
      final choice = await showModalBottomSheet<VideoStemLoadChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => VideoStemPicker(
          taskId: task.id,
          result: result,
          store: ref.read(algorithmStemStoreProvider),
          initialIds: initial,
        ),
      );
      if (choice != null && mounted) {
        await _loadStems(
          task,
          trackIds: choice.ids,
          localOnly: choice.localOnly,
        );
      }
    } on Object catch (e) {
      _message(_errorMessage(e, '无法读取音轨，请稍后重试'));
    } finally {
      _choosingStems = false;
    }
  }

  Widget _mixer([StateSetter? refreshSheet]) => VideoStemMixer(
    controls: _currentSelection().activeControls,
    master: widget.controller.volume,
    supportsPan: widget.controller.supportsStemPan,
    enabled:
        widget.enabled &&
        !_busy &&
        !widget.recordingActive &&
        widget.controller.stemsLoaded,
    onMaster: (v) {
      unawaited(widget.controller.setVolume(v));
      refreshSheet?.call(() {});
    },
    onChange: (id, c) {
      setState(() {
        _volumes[id] = c.volume;
        _pans[id] = c.pan;
        c.muted ? _muted.add(id) : _muted.remove(id);
        c.solo ? _solo.add(id) : _solo.remove(id);
      });
      refreshSheet?.call(() {});
      unawaited(_applyGains());
    },
    onReset: () {
      setState(() {
        _volumes.updateAll((_, _) => 1);
        _pans.updateAll((_, _) => 0);
        _muted.clear();
        _solo.clear();
      });
      refreshSheet?.call(() {});
      unawaited(_applyGains());
    },
  );

  Future<void> _openMixer() async {
    final choose = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) => FractionallySizedBox(
            heightFactor: .85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _mixer(refresh),
                  TextButton.icon(
                    key: const Key('video_mixer_choose_stems'),
                    onPressed:
                        _busy || !widget.enabled || widget.recordingActive
                        ? null
                        : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('选择练习音轨'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (choose == true && mounted && _rememberedTask != null) {
      await _chooseStems(_rememberedTask!);
    }
  }

  Future<void> _recoverReceipt(AlgorithmTaskRecord task) async {
    if (_busy || !widget.enabled) return;
    final id = await showDialog<String>(
      context: context,
      builder: (_) => _AnalysisValueDialog(
        title: '找回已上传任务',
        label: '服务器任务编号（job_id）',
        initial: '',
        description: '从服务器任务记录取得编号后查询，不会再次上传音频。当前接口不支持按文件自动查找任务。',
        validate: (s) {
          try {
            algorithmId(s);
            return null;
          } on FormatException {
            return '请输入有效任务编号';
          }
        },
      ),
    );
    if (id == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(algorithmTaskServiceProvider)
          .recoverWithJobId(task.id, id.trim());
    } on Object catch (e) {
      _message(_errorMessage(e, '找回失败，请检查任务编号'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmNewSubmission(AlgorithmTaskRecord task) async {
    if (_busy || !widget.enabled) return;
    final retry = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新提交分析？'),
        content: const Text(
          '上次上传没有收到任务编号，服务器仍可能正在处理。重新提交可能产生重复任务。也可以先用服务器任务编号找回。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('仍然重新提交'),
          ),
        ],
      ),
    );
    if (retry != true || !mounted) return;
    setState(() => _operation = task.operation);
    await _submit();
  }

  Future<void> _seekVerified(VideoAnalysisBinding binding, int sourceMs) async {
    try {
      await _verify(binding);
      if (!mounted || !widget.enabled) return;
      await widget.controller.seek(Duration(milliseconds: sourceMs));
    } on Object catch (e) {
      _message(e is FormatException ? e.message : '无法定位当前视频');
    }
  }

  Future<void> _setLoopVerified(
    VideoAnalysisBinding binding,
    LoopRange range,
  ) async {
    try {
      await _verify(binding);
      if (!mounted || !widget.enabled) return;
      await widget.controller.activateLoopRange(range);
    } on Object catch (e) {
      _message(_errorMessage(e, '设置循环失败，请重试'));
    }
  }

  Future<void> _saveLoopVerified(VideoAnalysisBinding binding) async {
    try {
      await _verify(binding);
      if (mounted && widget.enabled) widget.onSaveLoop?.call();
    } on Object catch (e) {
      _message(_errorMessage(e, '无法保存练习片段'));
    }
  }

  Widget _timeline(AlgorithmTaskRecord task, VideoAnalysisBinding binding) {
    final zero = binding.manualChordZeroMs ?? binding.startMs;
    final chords = <VideoTimelineChord>[];
    if (task.operation == AlgorithmOperation.chords &&
        task.resultJson != null) {
      final result = LegacyChordResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
      );
      if (zero + result.duration.inMilliseconds > binding.endMs + 20) {
        if (binding.manualChordZeroMs != null) {
          throw const FormatException('人工校准超出分析区间');
        }
      }
      chords.addAll(
        result.segments.map(
          (s) => VideoTimelineChord(
            startMs: zero + s.start.inMilliseconds,
            endMs: zero + s.end.inMilliseconds,
            label: s.displayLabel,
          ),
        ),
      );
    }
    return VideoAnalysisTimeline(
      key: ValueKey('timeline_${task.id}'),
      startMs: binding.startMs,
      endMs: binding.endMs,
      waveform: binding.waveform,
      chords: chords,
      positionMs: widget.controller.position.inMilliseconds,
      loop: widget.controller.loopController.range,
      loopEnabled: widget.controller.loopController.enabled,
      enabled: widget.enabled && !_busy,
      onSeek: (ms) => unawaited(_seekVerified(binding, ms)),
      onLoop: (range) => unawaited(_setLoopVerified(binding, range)),
      onSaveLoop: widget.onSaveLoop == null
          ? null
          : () => unawaited(_saveLoopVerified(binding)),
    );
  }

  Future<void> _calibrate(AlgorithmTaskRecord task) async {
    final binding = _binding(task);
    final result = LegacyChordResult.fromJson(
      algorithmObject(jsonDecode(task.resultJson!)),
    );
    await widget.controller.pause();
    if (!mounted) return;
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _AnalysisValueDialog(
        title: '校准和弦时间',
        label: '分析 0 秒对应的视频时间（秒）',
        initial: binding.manualChordZeroMs == null
            ? ''
            : (binding.manualChordZeroMs! / 1000).toStringAsFixed(3),
        description:
            '服务裁剪了静音但未返回偏移。请对照视频确认位置；这是人工显示校准，不会改写算法结果。当前视频位置：${_time(widget.controller.position.inMilliseconds)}',
        validate: (text) {
          if (!RegExp(r'^\d+(\.\d{1,3})?$').hasMatch(text)) {
            return '请输入秒数，最多三位小数';
          }
          final seconds = double.tryParse(text);
          if (seconds == null || !seconds.isFinite) return '请输入有效秒数';
          final zero = (seconds * 1000).round();
          if (zero < binding.startMs ||
              zero + result.duration.inMilliseconds > binding.endMs + 20) {
            return '校准后的和弦必须位于本次分析区间内';
          }
          return null;
        },
      ),
    );
    if (value == null || !mounted) return;
    try {
      await _verify(binding);
      await ref
          .read(algorithmTaskRepositoryProvider)
          .updateMediaBinding(
            task.id,
            jsonEncode(
              binding
                  .withChordZero((double.parse(value) * 1000).round())
                  .toJson(),
            ),
          );
    } on Object catch (e) {
      _message(e is FormatException ? e.message : '校准保存失败');
    }
  }

  Future<void> _alignFirstChordHere(AlgorithmTaskRecord task) async {
    try {
      await widget.controller.pause();
      await widget.controller.requestSnapshot();
      final binding = _binding(task);
      final result = LegacyChordResult.fromJson(
        algorithmObject(jsonDecode(task.resultJson!)),
      );
      if (result.segments.isEmpty) throw const FormatException('没有可对齐的和弦');
      final zero =
          widget.controller.position.inMilliseconds -
          result.segments.first.start.inMilliseconds;
      if (zero < binding.startMs ||
          zero + result.duration.inMilliseconds > binding.endMs + 20) {
        throw const FormatException('当前位置无法容纳完整和弦结果，请使用时间校准');
      }
      await _verify(binding);
      await ref
          .read(algorithmTaskRepositoryProvider)
          .updateMediaBinding(
            task.id,
            jsonEncode(binding.withChordZero(zero).toJson()),
          );
      _message('已将首个和弦起点对齐到当前播放位置');
    } on Object catch (e) {
      _message(_errorMessage(e, '对齐失败，请重试'));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _loadingStems) {
      setState(() => _cancelStemLoad('恢复已暂停，可重新选择分轨；已下载文件保留'));
    }
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _expansion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_expanded) {
      return ExpansionTile(
        controller: _expansion,
        title: const Text('和弦与分轨'),
        trailing: widget.controller.stemsLoaded && _rememberedTask != null
            ? IconButton(
                tooltip: '打开混音台',
                onPressed: _busy || !widget.enabled ? null : _openMixer,
                icon: const Icon(Icons.tune),
              )
            : null,
        subtitle: Text(
          _saveFailed
              ? '设置保存失败，展开可重试'
              : widget.controller.stemsLoaded
              ? '已载入分轨，展开调整音量'
              : _restoreNotice ?? '直接分析当前视频，在这里练习',
        ),
        onExpansionChanged: _open,
      );
    }
    final tasks = ref.watch(algorithmTasksProvider);
    _tasks = (tasks.asData?.value ?? [])
        .where(
          (t) =>
              t.linkedSourceId == widget.source.id &&
              t.mediaBindingJson != null,
        )
        .toList();
    return ExpansionTile(
      controller: _expansion,
      initiallyExpanded: true,
      title: const Text('和弦与分轨'),
      onExpansionChanged: _open,
      childrenPadding: const EdgeInsets.only(bottom: 12),
      children: [
        const Text('共用当前视频、播放进度、倍速与 A-B；无需再次导入或关联曲目。'),
        const SizedBox(height: 8),
        SegmentedButton<AlgorithmOperation>(
          segments: const [
            ButtonSegment(value: AlgorithmOperation.chords, label: Text('扒和弦')),
            ButtonSegment(
              value: AlgorithmOperation.separation,
              label: Text('分轨'),
            ),
          ],
          selected: {_operation},
          onSelectionChanged: _busy
              ? null
              : (values) => setState(() {
                  _operation = values.single;
                  _userNavigated = true;
                }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('仅分析当前 A-B 区间'),
          value: _useRange,
          onChanged:
              _busy ||
                  (widget.controller.loopController.range == null && !_useRange)
              ? null
              : (v) => setState(() => _useRange = v),
        ),
        FilledButton.icon(
          key: const Key('video_analysis_submit'),
          onPressed: _busy || !widget.enabled ? null : _submit,
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            _operation == AlgorithmOperation.chords ? '分析当前视频和弦' : '分离当前视频音轨',
          ),
        ),
        if (_serviceNotice != null) ...[
          Text(_serviceNotice!),
          TextButton(
            key: const Key('video_analysis_retry_connection'),
            onPressed: _busy ? null : _retryConnection,
            child: const Text('重试连接'),
          ),
        ],
        if (_busy) ...[Text(_stage), LinearProgressIndicator(value: _progress)],
        if (_networkDownload && _downloadCancellation != null)
          TextButton.icon(
            key: const Key('video_pause_stem_download'),
            onPressed: () => _downloadCancellation?.cancel(),
            icon: const Icon(Icons.pause),
            label: const Text('暂停下载，保留进度'),
          ),
        if (_downloadNotice != null) Text(_downloadNotice!),
        if (_restoreNotice != null) Text(_restoreNotice!),
        if (_rememberedTask != null && !widget.controller.stemsLoaded)
          TextButton(
            key: const Key('video_mix_restore'),
            onPressed: _busy || !widget.enabled
                ? null
                : () => _loadStems(_rememberedTask!),
            child: const Text('恢复上次分轨'),
          ),
        if (_saveFailed) ...[
          const Text('声音设置保存失败，重新打开时可能无法恢复'),
          TextButton(
            key: const Key('video_mix_retry_save'),
            onPressed: _saved == null ? null : () => _persist(_saved!),
            child: const Text('重试保存设置'),
          ),
        ],
        if (widget.controller.stemsLoaded &&
            _rememberedTask != null &&
            _volumes.isNotEmpty) ...[
          const Divider(),
          Text(widget.controller.stemsActive ? '当前播放：分轨（原视频已静音）' : '当前区间外播放原声'),
          TextButton(
            key: const Key('video_mix_original'),
            onPressed: _busy || !widget.enabled ? null : _useOriginal,
            child: const Text('切回视频原声'),
          ),
          FilledButton.tonalIcon(
            key: const Key('video_open_mixer'),
            onPressed: _busy || !widget.enabled ? null : _openMixer,
            icon: const Icon(Icons.tune),
            label: const Text('打开混音台'),
          ),
          ExpansionTile(
            title: const Text('音轨音量、静音与独奏'),
            initiallyExpanded: true,
            children: [_mixer()],
          ),
        ],
        tasks.when(
          loading: () => const Text('正在读取本视频分析…'),
          error: (_, _) => const Text('分析记录读取失败，请稍后重新打开'),
          data: (_) => Column(
            children: [
              for (final task
                  in _tasks.where((t) => t.operation == _operation).take(5))
                _taskCard(task),
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskCard(AlgorithmTaskRecord task) {
    try {
      final binding = _binding(task);
      final separation =
          task.operation == AlgorithmOperation.separation &&
              task.resultJson != null
          ? LegacySeparationResult.fromJson(
              algorithmObject(jsonDecode(task.resultJson!)),
              AlgorithmEndpoint(task.endpoint, allowLocalHttp: true),
            )
          : null;
      if (!binding.matches(
        widget.source.id,
        widget.path,
        File(widget.path).statSync(),
      )) {
        return const Text('视频文件版本已变化，请重新分析；旧结果不会应用到新视频。');
      }
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_time(binding.startMs)}–${_time(binding.endMs)} · ${task.operation == AlgorithmOperation.chords ? '和弦' : '音轨'}',
              ),
              if (_loadedTaskId == task.id && widget.controller.stemsLoaded)
                const Text('当前使用的分轨'),
              if (binding.waveform.isNotEmpty) _timeline(task, binding),
              Text(task.message ?? task.state.name),
              if (task.operation == AlgorithmOperation.separation &&
                  task.shouldPoll)
                Text(
                  task.state == AlgorithmTaskState.queued
                      ? '等待服务器开始分轨；现在还没有下载音轨。'
                      : '服务器正在处理分轨 · 任务用时 ${DateTime.now().toUtc().difference(task.createdAt).inSeconds.clamp(0, 86400)} 秒。音频越长通常越耗时；结果就绪后才开始下载。',
                ),
              if (task.state == AlgorithmTaskState.submissionUnknown &&
                  task.remoteJobId == null)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: _busy || !widget.enabled
                          ? null
                          : () => _recoverReceipt(task),
                      child: const Text('用任务编号找回'),
                    ),
                    TextButton(
                      onPressed: _busy || !widget.enabled
                          ? null
                          : () => _confirmNewSubmission(task),
                      child: const Text('重新提交…'),
                    ),
                  ],
                ),
              if (task.shouldPoll)
                LinearProgressIndicator(
                  value: task.progress == null ? null : task.progress! / 100,
                ),
              if (task.resultJson != null &&
                  task.operation == AlgorithmOperation.chords)
                ..._chords(task),
              if (separation != null)
                Text(
                  '已分离：${separation.stems.map((s) => s.displayName).join('、')}。载入后可调节音量、静音、独奏及左右声像；合成伴奏不与原分轨重复叠加。',
                ),
              if (separation?.processing != null)
                SeparationProcessingDetails(info: separation!.processing!),
              if (task.resultJson != null &&
                  task.operation == AlgorithmOperation.separation)
                TextButton(
                  onPressed: _busy || !widget.enabled
                      ? null
                      : () => _loadStems(task),
                  child: const Text('在当前视频中使用分轨'),
                ),
              if (separation != null)
                TextButton.icon(
                  key: Key('video_choose_stems_${task.id}'),
                  onPressed: _busy || !widget.enabled || widget.recordingActive
                      ? null
                      : () => _chooseStems(task),
                  icon: const Icon(Icons.playlist_add_check),
                  label: const Text('选择音轨与下载'),
                ),
              if (task.remoteJobId != null && task.resultJson == null)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => ref
                            .read(algorithmTaskServiceProvider)
                            .refresh(task.id, force: true),
                  child: const Text('重新查询'),
                ),
            ],
          ),
        ),
      );
    } on Object {
      return const Text('本视频分析记录需要更新，请重新分析');
    }
  }

  List<Widget> _chords(AlgorithmTaskRecord task) {
    final result = LegacyChordResult.fromJson(
      algorithmObject(jsonDecode(task.resultJson!)),
    );
    final binding = _binding(task);
    final playback = VideoChordPlayback(result, binding);
    final position = widget.controller.position.inMilliseconds;
    final current = playback.current(position);
    final next = playback.next(position);
    return [
      if (result.keyEstimate.isNotEmpty) Text('调性参考：${result.keyEstimate}'),
      if (result.hasTailTimingDifference)
        const Text('结尾时长有轻微差异，保留原始和弦时间；定位仍需人工校准。'),
      Text(
        '当前：${current?.displayLabel ?? '—'}   下一个：${next?.displayLabel ?? '—'} · ${binding.manualChordZeroMs == null ? '按区间起点显示，待校准' : '人工校准'}',
      ),
      TextButton(
        onPressed: _busy || !widget.enabled ? null : () => _calibrate(task),
        child: Text(binding.manualChordZeroMs == null ? '与视频时间校准' : '调整人工校准'),
      ),
      if (result.segments.isNotEmpty)
        TextButton(
          onPressed: _busy || !widget.enabled
              ? null
              : () => _alignFirstChordHere(task),
          child: const Text('将首个和弦起点对齐到当前位置'),
        ),
    ];
  }
}

String _time(int ms) =>
    '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
String _bytes(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(bytes / 1024).toStringAsFixed(0)} KB';
String _errorMessage(Object error, String fallback) {
  if (error is AlgorithmApiError) return error.message;
  if (error is FormatException) return error.message;
  if (error is PlatformException && error.message != null) {
    return error.message!;
  }
  return fallback;
}

class _AnalysisValueDialog extends StatefulWidget {
  const _AnalysisValueDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.validate,
    this.description,
  });
  final String title, label, initial;
  final String? description;
  final String? Function(String) validate;
  @override
  State<_AnalysisValueDialog> createState() => _AnalysisValueDialogState();
}

class _AnalysisValueDialogState extends State<_AnalysisValueDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.description != null) Text(widget.description!),
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(labelText: widget.label),
            validator: (s) => widget.validate(s?.trim() ?? ''),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('确认'),
      ),
    ],
  );
}
