import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/legacy_algorithm_models.dart';

const melpalAlgorithmOrigin = 'https://api.melpal.com.cn';

bool isMelpalAlgorithm(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host.toLowerCase() == 'api.melpal.com.cn' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

/// Per-device beta credentials, separate from Supabase login. Never part of a
/// build define, task row, cache receipt, URI or log message.
class AlgorithmAccess {
  const AlgorithmAccess([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  static const key = 'guitarpal.algorithm.melpal.access.v1';
  static const guestKey = 'guitarpal.algorithm.melpal.guest.v1';
  static Future<String>? _creatingGuest;

  Future<bool> configured() async => (await token()) != null;
  Future<String?> token() async {
    try {
      final value = await storage.read(key: key);
      return value == null ? null : _validate(value);
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '无法读取此设备的分析会话，请重新打开应用后重试',
      );
    }
  }

  Future<void> save(String input) async {
    var value = input.trim();
    if (value.startsWith('{')) {
      try {
        final json = jsonDecode(value);
        if (json is! Map ||
            json['base_url'] != melpalAlgorithmOrigin ||
            json['access_token'] is! String) {
          throw const FormatException();
        }
        value = json['access_token'] as String;
      } on Object {
        throw const FormatException('请选择本服务的有效内测凭据，内容不会显示或上传');
      }
    }
    final valid = _validate(value);
    try {
      await storage.write(key: key, value: valid);
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '内测凭据未能保存，请重试',
      );
    }
  }

  String _validate(String value) {
    if (!RegExp(r'^mp_[A-Za-z0-9_-]{32,180}$').hasMatch(value)) {
      throw const FormatException('内测令牌格式无效，请检查后重新输入');
    }
    return value;
  }

  Future<void> clear() async {
    try {
      await storage.delete(key: key);
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '内测凭据未能移除，请重试',
      );
    }
  }

  Future<String> requireToken() async =>
      await _readGuest() ?? await token() ?? await useGuest();

  Future<String?> _readGuest() async {
    try {
      final value = await storage.read(key: guestKey);
      if (value != null && !RegExp(r'^mg_[0-9a-f]{64}$').hasMatch(value)) {
        throw const FormatException();
      }
      return value;
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '无法读取此设备的分析会话，请重新打开应用后重试',
      );
    }
  }

  /// Serialize first use across preflight, uploads and downloads in this app.
  Future<String> useGuest() async {
    final current = _creatingGuest;
    if (current != null) return current;
    final creation = _createGuest();
    _creatingGuest = creation;
    try {
      return await creation;
    } finally {
      _creatingGuest = null;
    }
  }

  Future<String> _createGuest() async {
    final existing = await _readGuest();
    if (existing != null) return existing;
    try {
      final random = Random.secure();
      final bytes = List.generate(32, (_) => random.nextInt(256));
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final guest = 'mg_$hex';
      await storage.write(key: guestKey, value: guest);
      return guest;
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '暂时无法建立设备的分析会话，请稍后重试',
      );
    }
  }
}

/// Exact-origin bearer authentication shared by upload, polls and resumable
/// downloads. Redirects never forward a beta secret to a second origin.
class MelpalHttpClient extends http.BaseClient {
  MelpalHttpClient(this.inner, {this.access = const AlgorithmAccess()});
  final http.Client inner;
  final AlgorithmAccess access;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (isMelpalAlgorithm(request.url) &&
        request.url.path.startsWith('/api/v1/')) {
      request.followRedirects = false;
      request.headers['Authorization'] =
          'Bearer ${await access.requireToken()}';
    }
    return inner.send(request);
  }

  @override
  void close() => inner.close();
}

String? algorithmHttpMessage(int? status) => switch (status) {
  401 => '当前分析会话无法验证，请稍后重试或在「我的 → 算法服务」检查连接',
  530 => '分析服务暂时离线，请稍后重试；本地练习和已下载内容仍可使用',
  _ => null,
};
