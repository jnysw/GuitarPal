import 'dart:convert';

String youtubePlayerDocument({
  required String videoId,
  required Uri origin,
  int startSeconds = 0,
}) =>
    '''
<!doctype html>
<html lang="zh-CN">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="referrer" content="strict-origin-when-cross-origin">
<style>
  html, body { margin: 0; width: 100%; height: 100%; background: #000; }
  #player { display: block; width: 100%; height: 100%; border: 0; }
</style>
<div id="player"></div>
<script>
  let player;
  let failed = false;
  function send(value) {
    window.MelPalYouTube.postMessage(JSON.stringify(value));
  }
  function snapshot() {
    if (failed || !player || typeof player.getCurrentTime !== 'function') return;
    send({type: 'snapshot', position: player.getCurrentTime(),
      duration: player.getDuration(), state: player.getPlayerState(),
      rate: player.getPlaybackRate(), rates: player.getAvailablePlaybackRates()});
  }
  window.melpalYouTube = {
    play() { player.playVideo(); },
    pause() { player.pauseVideo(); },
    seek(seconds, resume) {
      player.seekTo(seconds, true);
      if (resume) player.playVideo();
    },
    speed(value) { player.setPlaybackRate(value); }
  };
  window.onYouTubeIframeAPIReady = function () {
    player = new YT.Player('player', {
      width: '100%', height: '100%', videoId: ${jsonEncode(videoId).replaceAll('<', r'\u003c')},
      playerVars: {origin: ${jsonEncode(origin.origin)}, playsinline: 1, fs: 0, rel: 0, start: $startSeconds},
      events: {
        onReady() { snapshot(); setInterval(snapshot, 160); },
        onStateChange: snapshot,
        onPlaybackRateChange: snapshot,
        onError(event) { failed = true; send({type: 'error', code: event.data}); }
      }
    });
  };
</script>
<script src="https://www.youtube.com/iframe_api"></script>
</html>
''';
