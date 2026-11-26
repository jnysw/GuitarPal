import 'dart:typed_data';

import '../domain/account_profile.dart';

abstract interface class AccountProfileRepository {
  Future<AccountProfile> load(String userId);

  Future<Uint8List> downloadAvatar(String path);

  Future<void> save(
    AccountProfile original, {
    required String handle,
    Uint8List? avatar,
    bool removeAvatar = false,
  });
}

class AccountProfileException implements Exception {
  const AccountProfileException(this.message, {this.handleTaken = false});

  final String message;
  final bool handleTaken;
}
