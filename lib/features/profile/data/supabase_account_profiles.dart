import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../application/account_profile_repository.dart';
import '../domain/account_profile.dart';

class SupabaseAccountProfiles implements AccountProfileRepository {
  const SupabaseAccountProfiles(this._client);

  final SupabaseClient _client;

  SupabaseQueryBuilder get _profiles => _client.from('account_profiles');
  StorageFileApi get _avatars => _client.storage.from('profile-avatars');

  @override
  Future<AccountProfile> load(String userId) async {
    _requireAccount(userId);
    final row = await _profiles
        .select('handle, avatar_path, revision')
        .eq('user_id', userId)
        .maybeSingle();
    return AccountProfile(
      userId: userId,
      handle: row?['handle'] as String?,
      avatarPath: row?['avatar_path'] as String?,
      revision: row?['revision'] as int?,
    );
  }

  @override
  Future<Uint8List> downloadAvatar(String path) {
    _requireAccount(path.split('/').first);
    return _avatars.download(path);
  }

  @override
  Future<void> save(
    AccountProfile original, {
    required String handle,
    Uint8List? avatar,
    bool removeAvatar = false,
  }) async {
    final userId = original.userId;
    _requireAccount(userId);
    final handleError = AccountProfile.validateHandle(handle);
    if (handleError != null) throw AccountProfileException(handleError);
    final normalized = AccountProfile.normalizeHandle(handle);
    final previousPath = original.avatarPath;
    final String? uploadedPath;
    if (avatar != null) {
      uploadedPath = '$userId/${const Uuid().v4()}.png';
      try {
        await _avatars.uploadBinary(
          uploadedPath,
          avatar,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );
      } on StorageException {
        throw const AccountProfileException('头像上传失败，请稍后重试');
      }
    } else {
      uploadedPath = null;
    }
    final avatarPath = uploadedPath ?? (removeAvatar ? null : previousPath);
    final revision = original.revision;
    final values = {
      'handle': normalized.isEmpty ? null : normalized,
      'avatar_path': avatarPath,
      'revision': (revision ?? 0) + 1,
    };
    try {
      _requireAccount(userId);
      if (revision == null) {
        await _profiles.insert({...values, 'user_id': userId});
      } else {
        final updated = await _profiles
            .update(values)
            .eq('user_id', userId)
            .eq('revision', revision)
            .select('revision')
            .maybeSingle();
        if (updated == null) {
          if (uploadedPath != null) unawaited(_removeAvatar(uploadedPath));
          throw _staleProfile;
        }
      }
    } on PostgrestException catch (error) {
      // A transport failure may arrive after the row already points to the new file.
      if (uploadedPath != null && error.code?.startsWith('23') == true) {
        unawaited(_removeAvatar(uploadedPath));
      }
      if (error.code == '23505') {
        if (error.message.contains('account_profiles_handle_key')) {
          throw const AccountProfileException('此用户 ID 已被使用', handleTaken: true);
        }
        throw _staleProfile;
      }
      rethrow;
    }
    if (previousPath != null && previousPath != avatarPath) {
      unawaited(_removeAvatar(previousPath));
    }
  }

  void _requireAccount(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const AccountProfileException('请重新登录后编辑资料');
    }
  }

  Future<void> _removeAvatar(String path) async {
    try {
      await _avatars.remove([path]);
    } on Exception {
      // An unavailable cleanup request should not affect the saved profile.
    }
  }
}

const _staleProfile = AccountProfileException('资料已在其他设备更新，请返回后重新打开编辑页');
