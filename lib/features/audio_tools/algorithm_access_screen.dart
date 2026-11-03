import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'algorithm_providers.dart';
import 'data/algorithm_access.dart';
import 'domain/legacy_algorithm_models.dart';

class AlgorithmAccessScreen extends ConsumerStatefulWidget {
  const AlgorithmAccessScreen({super.key});
  @override
  ConsumerState<AlgorithmAccessScreen> createState() => _AccessState();
}

class _AccessState extends ConsumerState<AlgorithmAccessScreen> {
  final _input = TextEditingController();
  bool _busy = true, _configured = false, _verified = false;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final configured = await ref.read(algorithmAccessProvider).configured();
      if (mounted) setState(() => _configured = configured);
    } on Object {
      if (mounted) setState(() => _message = '凭据读取失败，可重新保存或移除后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _verified = false;
      _message = null;
    });
    try {
      await ref.read(algorithmAccessProvider).save(_input.text);
      _input.clear();
      if (mounted) {
        setState(() {
          _configured = true;
          _message = '凭据已保存在此设备，可点击验证连接';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(
          () => _message = e is FormatException ? e.message : '凭据保存失败，请重试',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || !_configured) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _verified = false;
      _message = null;
    });
    final api = ref.read(algorithmApiFactoryProvider)(
      AlgorithmEndpoint(melpalAlgorithmOrigin, allowLocalHttp: false),
    );
    try {
      await api.ping();
      if (mounted) {
        setState(() {
          _verified = true;
          _message = '公网连接与内测凭据检查通过，可返回练习进行分析';
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(
          () =>
              _message = e is AlgorithmApiError ? e.message : '暂时无法验证连接，请稍后重试',
        );
      }
    } finally {
      api.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(algorithmAccessProvider).clear();
      _input.clear();
      if (mounted) {
        setState(() {
          _configured = false;
          _verified = false;
          _message = '已移除此设备的内测凭据，本地练习和缓存仍可使用';
        });
      }
    } on Object {
      if (mounted) setState(() => _message = '凭据移除失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('算法服务')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('MelPal 内测', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            '通过公网进行和弦分析与分轨，无需连接 Tailscale。每位测试者使用自己的内测凭据；它与应用账号登录分别管理。',
          ),
          const SizedBox(height: 16),
          Text(
            _verified
                ? '本次连接验证通过'
                : _configured
                ? '凭据已保存在此设备，尚未验证'
                : '尚未设置个人内测凭据',
          ),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          TextField(
            key: const Key('algorithm_access_input'),
            controller: _input,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            decoration: const InputDecoration(
              labelText: '个人内测令牌或凭据 JSON',
              helperText: '从管理员取得个人凭据；保存后清空输入，不回显令牌',
              helperMaxLines: 3,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('algorithm_access_save'),
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.lock_outline),
            label: const Text('保存个人凭据'),
          ),
          OutlinedButton(
            key: const Key('algorithm_access_verify'),
            onPressed: _busy || !_configured ? null : _verify,
            child: const Text('验证连接（不上传音频）'),
          ),
          if (_configured)
            TextButton(
              key: const Key('algorithm_access_clear'),
              onPressed: _busy ? null : _clear,
              child: const Text('移除此设备凭据'),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_message!),
            ),
          const SizedBox(height: 12),
          const Text(
            '过期或撤销后可替换凭据，再对已有任务点“重新查询”，无需重新上传。旧私网任务继续使用原地址，本地已下载内容保留。',
          ),
        ],
      ),
    ),
  );
}
