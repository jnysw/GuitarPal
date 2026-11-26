/// A single service origin. Legacy builds remain compatible during migration.
class AlgorithmConfiguration {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment('ALGORITHM_BASE_URL'),
  );
}
