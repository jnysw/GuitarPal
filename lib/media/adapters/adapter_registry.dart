import 'practice_source_adapter.dart';

class AdapterRegistry {
  AdapterRegistry(List<PracticeSourceAdapter> adapters)
    : assert(adapters.isNotEmpty),
      _adapters = List.unmodifiable(adapters);

  final List<PracticeSourceAdapter> _adapters;

  PracticeSourceAdapter adapterFor(Uri uri) {
    return _adapters.firstWhere(
      (adapter) => adapter.canHandle(uri),
      orElse: () => throw StateError('No source adapter can handle $uri'),
    );
  }
}
