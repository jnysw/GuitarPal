import '../../domain/practice_source/practice_source.dart';

class BilibiliPlayerUriBuilder {
  const BilibiliPlayerUriBuilder();

  Uri? build(PracticeSource source, {Duration? startAt}) {
    if (source.platform != SourcePlatform.bilibili) return null;
    final externalId = source.externalId;
    if (externalId == null || externalId.isEmpty) return null;

    final query = <String, String>{
      'autoplay': '0',
      'danmaku': '0',
      'poster': '1',
    };
    if (externalId.startsWith('BV')) {
      query['bvid'] = externalId;
    } else if (externalId.startsWith('av')) {
      final aid = externalId.substring(2);
      if (int.tryParse(aid) == null) return null;
      query['aid'] = aid;
    } else {
      return null;
    }
    if (startAt != null && startAt > Duration.zero) {
      query['t'] = '${startAt.inSeconds}';
    }

    return Uri.https('player.bilibili.com', '/player.html', query);
  }
}
