import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../domain/practice_source/practice_source.dart';
import '../../media/adapters/online_video_links.dart';
import 'widgets/open_original_source_button.dart';

class InstagramPreviewScreen extends StatefulWidget {
  const InstagramPreviewScreen({
    required this.source,
    required this.post,
    super.key,
  });

  final PracticeSource source;
  final Uri post;

  @override
  State<InstagramPreviewScreen> createState() => _InstagramPreviewScreenState();
}

class _InstagramPreviewScreenState extends State<InstagramPreviewScreen> {
  static const _origin = 'https://melpal.com.cn/instagram-preview';
  final _client = http.Client();
  WebViewController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final platform = WebViewPlatform.instance;
    if (platform == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final response = await _client
          .get(
            Uri.https('graph.facebook.com', '/v27.0/instagram_oembed', {
              'url': widget.post.toString(),
              'omitscript': 'true',
              'hidecaption': 'true',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.length > 64 * 1024) {
        throw const FormatException('Invalid Instagram response');
      }
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> ||
          value['provider_name'] != 'Instagram' ||
          value['html'] is! String ||
          (value['html'] as String).isEmpty) {
        throw const FormatException('Instagram preview not available');
      }
      if (!mounted) return;
      final web = platform is WebKitWebViewPlatform
          ? WebViewController.fromPlatformCreationParams(
              WebKitWebViewControllerCreationParams(
                allowsInlineMediaPlayback: true,
              ),
            )
          : WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (request.url == _origin ||
                (!request.isMainFrame &&
                    uri != null &&
                    uri.scheme == 'https' &&
                    isInstagramHost(uri.host))) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _failed = true;
                _loading = false;
              });
            }
          },
        ),
      );
      if (!mounted) return;
      await web.loadHtmlString(
        _document(value['html'] as String),
        baseUrl: _origin,
      );
      if (mounted) {
        setState(() {
          _controller = web;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String _document(String html) =>
      '''
<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src https://www.instagram.com; frame-src https://www.instagram.com; style-src 'unsafe-inline'; img-src https: data:;">
<style>body { margin: 0; display: flex; justify-content: center; }</style>
$html
<script async src="https://www.instagram.com/embed.js"></script>
</html>''';

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Instagram 预览')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed || _controller == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '暂时无法预览此帖子，可打开原内容查看。',
                            textAlign: TextAlign.center,
                          ),
                          if (WebViewPlatform.instance != null)
                            TextButton(
                              onPressed: _load,
                              child: const Text('重试'),
                            ),
                        ],
                      ),
                    ),
                  )
                : WebViewWidget(controller: _controller!),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OpenOriginalSourceButton(
              source: widget.source,
              label: '打开 Instagram',
            ),
          ),
        ],
      ),
    ),
  );
}
