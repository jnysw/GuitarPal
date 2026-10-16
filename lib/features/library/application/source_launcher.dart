import 'package:url_launcher/url_launcher.dart';

import '../../../domain/practice_source/practice_source.dart';

abstract interface class SourceLauncher {
  Future<bool> open(PracticeSource source);
}

final class ExternalSourceLauncher implements SourceLauncher {
  const ExternalSourceLauncher();

  @override
  Future<bool> open(PracticeSource source) async {
    final uri = source.canonicalUri ?? source.originalUri;
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return false;
    }
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
