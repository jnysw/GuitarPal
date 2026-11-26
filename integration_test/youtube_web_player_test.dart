import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:guitar_pal/core/database/app_database.dart';
import 'package:guitar_pal/core/database/database_providers.dart';
import 'package:guitar_pal/domain/practice_source/practice_source.dart' as domain;
import 'package:guitar_pal/features/library/data/drift_practice_source_repository.dart';
import 'package:guitar_pal/features/player/practice_player_screen.dart';
import 'package:guitar_pal/features/segments/presentation/practice_segment_progress_slider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const live = bool.fromEnvironment('YOUTUBE_LIVE_TEST');
  testWidgets(
    live
        ? 'official YouTube embed plays and loops'
        : 'YouTube WebView bridge plays and loops',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      try {
        final now = DateTime.now();
        final source = domain.PracticeSource(
          id: 'youtube-demo',
          platform: domain.SourcePlatform.youtube,
          kind: domain.SourceKind.webReference,
          title: 'YouTube IFrame API demo',
          canonicalUri: Uri.parse(
            'https://www.youtube.com/watch?v=M7lc1UVf-VE',
          ),
          createdAt: now,
          updatedAt: now,
        );
        await DriftPracticeSourceRepository(database).save(source);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(database)],
            child: MaterialApp(home: PracticePlayerScreen(source: source)),
          ),
        );

        if (!live) {
          final view = find.byType(WebViewWidget);
          await _wait(tester, () => view.evaluate().isNotEmpty);
          final web = tester
              .widget<WebViewWidget>(view)
              .platform
              .params
              .controller;
          for (var i = 0; i < 30; i++) {
            final loaded = await web.runJavaScriptReturningResult(
              "typeof window.onYouTubeIframeAPIReady === 'function'",
            );
            if (loaded.toString() == 'true') break;
            await tester.pump(const Duration(milliseconds: 100));
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          await web.runJavaScript(_iframeApiFixture);
        }

        final play = find.byTooltip('播放');
        await _wait(tester, () => play.hitTestable().evaluate().isNotEmpty);
        await tester.tap(play);
        final pause = find.byTooltip('暂停');
        await _wait(tester, () => pause.hitTestable().evaluate().isNotEmpty);
        await tester.tap(pause);
        await _wait(tester, () => play.hitTestable().evaluate().isNotEmpty);
        final speedControl = find.byKey(const Key('youtube_playback_speed'));
        await _wait(
          tester,
          () =>
              tester.widget<DropdownButton<double>>(speedControl).onChanged !=
              null,
        );
        tester.widget<DropdownButton<double>>(speedControl).onChanged!(.75);
        await _wait(
          tester,
          () =>
              tester.widget<DropdownButton<double>>(speedControl).value == .75,
        );

        final progress = find.byType(PracticeSegmentProgressSlider);
        PracticeSegmentProgressSlider slider() =>
            tester.widget<PracticeSegmentProgressSlider>(progress);
        Future<void> seekTo(int milliseconds) async {
          slider().onChangeEnd!(milliseconds.toDouble());
          await _wait(
            tester,
            () =>
                (slider().position.inMilliseconds - milliseconds).abs() < 1800,
          );
        }

        await seekTo(5000);
        final a = find.widgetWithText(OutlinedButton, 'A 未设置');
        await tester.ensureVisible(a);
        await tester.tap(a);
        await seekTo(10000);
        final b = find.widgetWithText(OutlinedButton, 'B 未设置');
        await tester.ensureVisible(b);
        await tester.tap(b);
        final loop = find.widgetWithText(SwitchListTile, 'A-B 循环');
        await _wait(tester, () => tester.widget<SwitchListTile>(loop).value);
        await tester.ensureVisible(play);
        await tester.tap(play);
        await _wait(tester, () => slider().position.inMilliseconds < 8000);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 400));
        await database.close();
      }
    },
  );
}

const _iframeApiFixture = '''
window.YT = {
  Player: class {
    constructor(element, options) {
      this.state = 2;
      this.position = 0;
      this.rate = 1;
      this.events = options.events;
      setTimeout(() => this.events.onReady(), 0);
    }
    getPlayerState() { return this.state; }
    getDuration() { return 60; }
    getCurrentTime() {
      if (this.state === 1) this.position += 0.5 * this.rate;
      return this.position;
    }
    getPlaybackRate() { return this.rate; }
    getAvailablePlaybackRates() { return [0.75, 1, 1.25]; }
    playVideo() { this.state = 1; this.events.onStateChange(); }
    pauseVideo() { this.state = 2; this.events.onStateChange(); }
    seekTo(seconds) { this.position = seconds; }
    setPlaybackRate(rate) { this.rate = rate; this.events.onPlaybackRateChange(); }
  }
};
window.onYouTubeIframeAPIReady();
''';

Future<void> _wait(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  fail(
    'YouTube player did not reach the requested state. Visible labels: '
    '${tester.widgetList<Text>(find.byType(Text)).map((widget) => widget.data).whereType<String>().join(' · ')}',
  );
}
