import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'algorithm_providers.dart';
import 'domain/legacy_algorithm_models.dart';

class AlgorithmAccessScreen extends ConsumerStatefulWidget {
  const AlgorithmAccessScreen({super.key});

  @override
  ConsumerState<AlgorithmAccessScreen> createState() => _AccessState();
}

class _AccessState extends ConsumerState<AlgorithmAccessScreen> {
  bool _busy = false;
  bool? _verified;
  String? _message;

  Future<void> _verify() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _verified = null;
      _message = null;
    });
    try {
      final configuredOrigin = ref.read(algorithmEndpointProvider).trim();
      final origin = configuredOrigin.isNotEmpty
          ? configuredOrigin
          : await ref.read(algorithmServiceConfigurationProvider).load();
      if (!mounted) return;
      final api = ref.read(algorithmApiFactoryProvider)(
        AlgorithmEndpoint(origin, allowLocalHttp: kDebugMode),
      );
      try {
        await api.ping();
      } finally {
        api.close();
      }
      if (mounted) {
        setState(() {
          _verified = true;
          _message = '连接正常，可回到练习页开始和弦分析或分轨';
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _verified = false;
          _message = error is AlgorithmApiError
              ? error.message
              : '暂时无法检查连接，请稍后重试';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('算法服务')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('和弦分析与分轨', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('在本地视频的练习页选择分析，应用会自动连接。遇到连接问题时，可以在这里检查。'),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('algorithm_access_verify'),
            onPressed: _busy ? null : _verify,
            icon: const Icon(Icons.wifi_find),
            label: Text(_busy ? '正在检查连接…' : '检查连接'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message case final message?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: _verified == false
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
