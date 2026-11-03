library;

class DomainException implements Exception {
  final String message;
  const DomainException(this.message);
  @override
  String toString() => message;
}

class Confidence {
  final double value;
  const Confidence._(this.value);
  factory Confidence(double raw) =>
      Confidence._(raw.isNaN ? 0 : raw.clamp(0.0, 1.0));
  double get percent => value * 100;
}
