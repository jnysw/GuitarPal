import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'widgets/open_original_source_button.dart';

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
  late final PracticePlaybackSessionRecorder _session;
  WebViewController? _web;
  YouTubePlaybackController? _player;
  Timer? _loadTimeout;
  bool _appliedInitialSettings = false;
  bool _persistedDuration = false;
  bool _foreground = true;
  int _loadRevision = 0;

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

  Future<void> _saveLoop() async {
    final player = _player!;
    final range = player.loop.range;
    if (range == null) return;
    await player.pause();
    if (!mounted) return;
    final draft = await showPracticeSegmentEditorSheet(
      context: context,
      mode: PracticeSegmentEditorMode.create,
      initialValue: PracticeSegmentEditorResult(
        title:
            '片段 ${formatPracticeTimecode(range.start)}–${formatPracticeTimecode(range.end)}',
        start: range.start,
        end: range.end,
        preferredSpeed: player.speed,
      ),
    );
    if (!mounted || draft == null) return;
    try {
      final saved = await ref
          .read(practiceSegmentServiceProvider)
          .create(
            sourceId: widget.source.id,
            title: draft.title,
            start: draft.start,
            end: draft.end,
            note: draft.note,
            preferredSpeed: draft.preferredSpeed,
            sourceDuration: player.duration,
          );
      if (!mounted) return;
      _message('片段已保存');
      await _activate(saved);
    } on FormatException catch (error) {
      if (mounted) _message(error.message);
    } on Object {
      if (mounted) _message('暂时无法保存片段');
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.source.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: player == null
            ? Center(child: OpenOriginalSourceButton(source: widget.source))
            : LayoutBuilder(
                builder: (context, constraints) => ListView(
                  children: [
                    SizedBox(
                      height: math.max(200, constraints.maxWidth * 9 / 16),
                      child: WebViewWidget(controller: _web!),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: ListenableBuilder(
                        listenable: player,
                        builder: (_, _) => _controls(player, segments),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _controls(
    YouTubePlaybackController player,
    List<PracticeSegment> segments,
  ) {
    String time(Duration? value) =>
        formatPracticeTimecode(value ?? Duration.zero);
    String marker(Duration? value) => value == null ? '未设置' : time(value);
    final loop = player.loop;
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
              IconButton(
                onPressed: player.playPause,
                tooltip: player.isPlaying ? '暂停' : '播放',
                icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
              ),
              Expanded(
                child: Text(
                  '${time(player.position)} / ${time(player.duration)}',
                ),
              ),
              DropdownButton<double>(
                key: const Key('youtube_playback_speed'),
                value: player.rates.contains(player.speed)
                    ? player.speed
                    : null,
                hint: Text('${player.speed}×'),
                onChanged: player.rates.length < 2
                    ? null
                    : (value) {
                        if (value != null) unawaited(player.setSpeed(value));
                      },
                items: [
                  for (final rate in player.rates)
                    DropdownMenuItem(
                      value: rate,
                      child: Text(
                        '${rate == rate.round() ? rate.toInt() : rate}×',
                      ),
                    ),
                ],
              ),
            ],
          ),
          PracticeSegmentProgressSlider(
            duration: player.duration,
            position: player.position,
            segments: segments,
            enabled: player.canSeek,
            onChanged: (value) {},
            onChangeEnd: (value) =>
                unawaited(player.seek(Duration(milliseconds: value.round()))),
            onSegmentTap: _activate,
            sliderKey: const Key('youtube_position_slider'),
          ),
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
                        if (!player.setB()) _message('请把 B 点设在 A 点之后');
                      }
                    : null,
                child: Text('B ${marker(loop.end)}'),
              ),
              if (loop.range != null)
                TextButton(onPressed: _saveLoop, child: const Text('保存片段')),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('A-B 循环'),
            value: loop.enabled,
            onChanged: loop.range == null ? null : player.toggleLoop,
          ),
          for (final segment in segments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: player.canSeek,
              title: Text(segment.title),
              subtitle: Text('${time(segment.start)}–${time(segment.end)}'),
              leading: const Icon(Icons.bookmark_outline),
              onTap: () => _activate(segment),
            ),
        ],
        OpenOriginalSourceButton(source: widget.source),
      ],
    );
  }
}
