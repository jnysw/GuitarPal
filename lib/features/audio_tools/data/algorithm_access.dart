import 'dart:convert';

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

  Future<bool> configured() async => (await token()) != null;
  Future<String?> token() async {
    try {
      final value = await storage.read(key: key);
      return value == null ? null : _validate(value);
    } on Object {
      throw const AlgorithmApiError(
        'credential_storage_unavailable',
        '无法读取内测凭据，请到「我的 → 算法服务」重新保存',
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

  Future<String> requireToken() async {
    final value = await token();
    if (value == null) {
      throw const AlgorithmApiError(
        'authorization_required',
        '请先到「我的 → 算法服务」设置个人内测凭据',
      );
    }
    return value;
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

String? algorithmAuthorizationMessage(int? status) =>
    status == 401 ? '内测凭据已过期、被撤销或无效，请到「我的 → 算法服务」更新后重新查询；不会重复上传' : null;
