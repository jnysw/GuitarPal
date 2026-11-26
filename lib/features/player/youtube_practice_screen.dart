import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../domain/practice_segment/practice_segment.dart';
import '../../domain/practice_source/practice_source.dart';
import '../../media/adapters/online_video_links.dart';
import '../../media/playback/loop_controller.dart';
import '../../media/playback/youtube_playback_controller.dart';
import '../../media/playback/youtube_player_document.dart';
import '../library/practice_source_providers.dart';
import '../plans/application/practice_playback_session_recorder.dart';
import '../plans/practice_plan_providers.dart';
import '../segments/practice_segment_providers.dart';
import '../segments/presentation/practice_segment_editor_sheet.dart';
import '../segments/presentation/practice_segment_progress_slider.dart';
import '../segments/presentation/practice_segment_timecode.dart';
import 'widgets/online_practice_segments.dart';
import 'widgets/open_original_source_button.dart';
import 'widgets/precise_playback_speed_control.dart';

class YouTubePracticeScreen extends ConsumerStatefulWidget {
  const YouTubePracticeScreen({
    required this.source,
    required this.videoId,
    required this.defaultPlaybackSpeed,
    this.initialSegment,
    this.planId,
    super.key,
  });

  final PracticeSource source;
  final String videoId;
  final double defaultPlaybackSpeed;
  final PracticeSegment? initialSegment;
  final String? planId;

  @override
  ConsumerState<YouTubePracticeScreen> createState() => _YouTubePracticeState();
}

class _YouTubePracticeState extends ConsumerState<YouTubePracticeScreen>
    with WidgetsBindingObserver {
  static const _display = MethodChannel('com.guitarpal/playback_display');
  late final PracticePlaybackSessionRecorder _session;
  WebViewController? _web;
  YouTubePlaybackController? _player;
  Timer? _loadTimeout;
  bool _appliedInitialSettings = false;
  bool _persistedDuration = false;
  bool _foreground = true;
  int _loadRevision = 0;
  int _displayRevision = 0;
  bool _fullscreen = false;

  Uri get _origin => Uri.https(
    defaultTargetPlatform == TargetPlatform.iOS
        ? 'com.guitarpal.guitarpal'
        : 'com.guitarpal.guitar_pal',
    '/youtube-practice',
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ref
        .read(practiceSessionServiceProvider)
        .trackPlayback(
          sourceId: widget.source.id,
          planId: widget.planId,
          segmentId: widget.initialSegment?.id,
        );
    final platform = WebViewPlatform.instance;
    if (platform == null) return;
    final controller = platform is WebKitWebViewPlatform
        ? WebViewController.fromPlatformCreationParams(
            WebKitWebViewControllerCreationParams(
              allowsInlineMediaPlayback: true,
              mediaTypesRequiringUserAction: const {},
            ),
          )
        : WebViewController();
    _web = controller;
    _player = YouTubePlaybackController(controller.runJavaScript)
      ..addListener(_observe);
    unawaited(_load());
  }

  Future<void> _load() async {
    final web = _web!;
    final player = _player!;
    final revision = ++_loadRevision;
    _appliedInitialSettings = false;
    player.reset();
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 16), () {
      if (mounted && !player.ready) player.fail('YouTube 播放器连接超时');
    });
    try {
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setBackgroundColor(Colors.black);
      if (revision == 1) {
        await web.addJavaScriptChannel(
          'MelPalYouTube',
          onMessageReceived: (message) {
            player.onMessage(message.message);
          },
        );
        final platform = web.platform;
        if (platform is AndroidWebViewController) {
          await platform.setMediaPlaybackRequiresUserGesture(false);
        }
      }
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == _origin ||
                (!request.isMainFrame &&
                    uri != null &&
                    uri.scheme == 'https' &&
                    uri.userInfo.isEmpty &&
                    isYouTubeHost(uri.host))) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            // WebKit also reports an intentionally cancelled navigation as an error.
            if (error.errorCode == -999) return;
            if (error.isForMainFrame == true &&
                mounted &&
                revision == _loadRevision) {
              player.fail('暂时无法连接 YouTube');
            }
          },
        ),
      );
      if (!mounted || revision != _loadRevision) return;
      await web.loadHtmlString(
        youtubePlayerDocument(
          videoId: widget.videoId,
          origin: _origin,
          startSeconds: widget.initialSegment == null
              ? widget.source.youtubeStartSeconds
              : 0,
        ),
        baseUrl: _origin.toString(),
      );
    } on Object {
      if (mounted && revision == _loadRevision) {
        player.fail('暂时无法加载 YouTube 播放器');
      }
    }
  }

  void _observe() {
    final player = _player!;
    _session.observe(
      isPlaying: _foreground && player.isPlaying,
      completedLoops: player.loop.totalCompletedLoops,
    );
    if (player.ready || player.error != null) _loadTimeout?.cancel();
    if (!player.canSeek) return;
    if (!_persistedDuration) {
      _persistedDuration = true;
      unawaited(_recordDuration(player.duration));
    }
    if (_appliedInitialSettings) return;
    _appliedInitialSettings = true;
    final segment = widget.initialSegment;
    if (segment != null) {
      unawaited(_activate(segment));
    } else {
      unawaited(player.setSpeed(widget.defaultPlaybackSpeed));
    }
  }

  Future<void> _recordDuration(Duration duration) async {
    try {
      await ref
          .read(practiceLibraryServiceProvider)
          .recordDuration(widget.source, duration);
      if (mounted) ref.invalidate(practiceSourceByIdProvider(widget.source.id));
    } on Object {
      // Duration is optional metadata for online sources.
    }
  }

  Future<void> _activate(PracticeSegment segment) async {
    final player = _player!;
    final applied = await player.activateRange(
      LoopRange(start: segment.start, end: segment.end),
    );
    if (!mounted) return;
    if (applied) {
      await player.setSpeed(segment.preferredSpeed);
    } else {
      _message('这个片段超出了当前视频时长');
    }
  }

  Future<void> _toggleFullscreen() async {
    setState(() => _fullscreen = !_fullscreen);
    await _syncDisplay(_fullscreen);
  }

  Future<void> _syncDisplay(bool fullscreen) async {
    final revision = ++_displayRevision;
    try {
      await SystemChrome.setPreferredOrientations(
        fullscreen
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [],
      );
      if (_displayRevision != revision) return;
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _display.invokeMethod<void>('setFullscreen', fullscreen);
      } else {
        await SystemChrome.setEnabledSystemUIMode(
          fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
        );
      }
    } on Object {
      // The layout still expands on devices that manage orientation themselves.
    }
  }

  Future<void> _showSpeed(YouTubePlaybackController player) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ListenableBuilder(
              listenable: player,
              builder: (_, _) => _speed(player),
            ),
          ),
        ),
      );

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _session.resume();
    } else {
      _session.suspend();
      unawaited(_player?.pause());
      unawaited(_saveSession(finish: false));
    }
  }

  Future<void> _saveSession({required bool finish}) async {
    try {
      if (finish) {
        await _session.finish();
      } else {
        await _session.checkpoint();
      }
    } on Object {
      // A failed practice record should not block leaving the player.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadTimeout?.cancel();
    if (_fullscreen) unawaited(_syncDisplay(false));
    _player?.dispose();
    unawaited(_saveSession(finish: true));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    final segments =
        ref.watch(practiceSegmentsProvider(widget.source.id)).asData?.value ??
        const [];
    return PopScope(
      canPop: !_fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _fullscreen) unawaited(_toggleFullscreen());
      },
      child: Scaffold(
        backgroundColor: _fullscreen ? Colors.black : null,
        appBar: _fullscreen
            ? null
            : AppBar(
                title: Text(
                  widget.source.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (player != null)
                    IconButton(
                      key: const Key('youtube_app_fullscreen'),
                      onPressed: _toggleFullscreen,
                      tooltip: '全屏练习',
                      icon: const Icon(Icons.fullscreen_rounded),
                    ),
                ],
              ),
        body: SafeArea(
          child: player == null
              ? Center(child: OpenOriginalSourceButton(source: widget.source))
              : LayoutBuilder(
                  builder: (_, constraints) {
                    final normalHeight = (constraints.maxWidth * 9 / 16).clamp(
                      200.0,
                      420.0,
                    );
                    final footerHeight = (constraints.maxHeight - 200).clamp(
                      48.0,
                      104.0,
                    );
                    final playerHeight = _fullscreen
                        ? math.max(0.0, constraints.maxHeight - footerHeight)
                        : math.min(normalHeight, constraints.maxHeight);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: playerHeight,
                          child: WebViewWidget(
                            key: const Key('youtube_web_surface'),
                            controller: _web!,
                          ),
                        ),
                        Positioned(
                          top: playerHeight,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ListenableBuilder(
                            listenable: player,
                            builder: (_, _) => _fullscreen
                                ? _fullscreenControls(player, segments)
                                : ListView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      24,
                                    ),
                                    children: [_controls(player, segments)],
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _fullscreenControls(
    YouTubePlaybackController player,
    List<PracticeSegment> segments,
  ) {
    return Theme(
      data: ThemeData.dark(),
      child: Material(
        color: const Color(0xff171717),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              Row(
                children: [
                  _playPause(player),
                  Expanded(
                    child: Text(
                      _timeLine(player),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: player.loop.enabled ? '暂停 A-B 循环' : '开启 A-B 循环',
                    isSelected: player.loop.enabled,
                    icon: const Icon(Icons.repeat_rounded),
                    selectedIcon: const Icon(Icons.repeat_on_rounded),
                    onPressed: player.canSeek && player.loop.range != null
                        ? () => player.toggleLoop(!player.loop.enabled)
                        : null,
                  ),
                  TextButton(
                    onPressed: player.ready ? () => _showSpeed(player) : null,
                    child: Text('${player.speed.toStringAsFixed(2)}x'),
                  ),
                  IconButton(
                    key: const Key('youtube_exit_fullscreen'),
                    onPressed: _toggleFullscreen,
                    tooltip: '退出全屏',
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                ],
              ),
              _progress(player, segments, fullscreen: true),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLine(YouTubePlaybackController player) =>
      '${formatPracticeTimecode(player.position)} / ${formatPracticeTimecode(player.duration)}';

  Widget _playPause(YouTubePlaybackController player) => IconButton(
    onPressed: player.ready ? player.playPause : null,
    tooltip: player.isPlaying ? '暂停' : '播放',
    icon: Icon(
      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
    ),
  );

  Widget _progress(
    YouTubePlaybackController player,
    List<PracticeSegment> segments, {
    bool fullscreen = false,
  }) => PracticeSegmentProgressSlider(
    duration: player.duration,
    position: player.position,
    segments: segments,
    enabled: player.canSeek,
    onChanged: (_) {},
    onChangeEnd: (value) =>
        unawaited(player.seek(Duration(milliseconds: value.round()))),
    onSegmentTap: _activate,
    sliderKey: Key(
      fullscreen
          ? 'youtube_fullscreen_position_slider'
          : 'youtube_position_slider',
    ),
    semanticLabel: fullscreen ? '全屏播放进度' : '播放进度',
  );

  Widget _speed(YouTubePlaybackController player) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      PrecisePlaybackSpeedControl(
        key: const Key('youtube_playback_speed'),
        value: player.speed,
        enabled: player.ready,
        availableRates: player.rates,
        onChanged: (_) {},
        onChangeEnd: (value) => unawaited(player.setSpeed(value)),
      ),
      Text(
        player.rates.length > 1 ? '按此视频提供的倍速档位调节' : '此视频当前只提供一个倍速档位',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  Widget _controls(
    YouTubePlaybackController player,
    List<PracticeSegment> segments,
  ) {
    String marker(Duration? value) =>
        value == null ? '未设置' : formatPracticeTimecode(value);
    final loop = player.loop;
    final range = loop.range;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (player.error case final error?) ...[
          Text(error),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _load, child: const Text('重试加载')),
          ),
        ] else if (!player.ready)
          const LinearProgressIndicator()
        else ...[
          Row(
            children: [
              _playPause(player),
              Expanded(child: Text(_timeLine(player))),
            ],
          ),
          _progress(player, segments),
          _speed(player),
          const Divider(height: 24),
          Text('A-B 循环', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                onPressed: player.canSeek ? player.setA : null,
                child: Text('A ${marker(loop.start)}'),
              ),
              OutlinedButton(
                onPressed: player.canSeek && loop.start != null
                    ? () {
                        if (!player.setB()) _message('B 点必须晚于 A 点');
                      }
                    : null,
                child: Text('B ${marker(loop.end)}'),
              ),
              IconButton(
                tooltip: '清除循环区间',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: loop.start == null ? null : player.clearLoop,
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('循环播放区间'),
            subtitle: Text('已完成 ${loop.completedLoops} 次'),
            value: loop.enabled,
            onChanged: range == null ? null : player.toggleLoop,
          ),
        ],
        const Divider(height: 24),
        OnlinePracticeSegments(
          source: widget.source,
          duration: player.duration,
          initialValue: range == null
              ? null
              : PracticeSegmentEditorResult(
                  title: '片段 ${marker(range.start)}–${marker(range.end)}',
                  start: range.start,
                  end: range.end,
                  preferredSpeed: player.speed,
                ),
          onBeforeEdit: player.pause,
          onActivate: player.canSeek ? _activate : null,
        ),
        OpenOriginalSourceButton(source: widget.source),
      ],
    );
  }
}
