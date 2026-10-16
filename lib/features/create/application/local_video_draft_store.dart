import 'package:uuid/uuid.dart';

import '../../../core/platform/local_video_gateway.dart';
import '../domain/local_video_draft.dart';

class LocalVideoDraftStore {
  LocalVideoDraftStore({Uuid? uuid, DateTime Function()? clock})
    : _uuid = uuid ?? const Uuid(),
      _clock = clock ?? DateTime.now;

  final Uuid _uuid;
  final DateTime Function() _clock;
  final Map<String, LocalVideoDraft> _drafts = {};

  LocalVideoDraft create({
    required LocalVideoPickOrigin origin,
    required LocalVideoFileInfo file,
  }) {
    final draft = LocalVideoDraft(
      id: _uuid.v4(),
      origin: origin,
      file: file,
      createdAt: _clock().toUtc(),
    );
    _drafts[draft.id] = draft;
    return draft;
  }

  LocalVideoDraft? getById(String id) => _drafts[id];

  LocalVideoDraft? remove(String id) => _drafts.remove(id);
}
