library;

/// Error raised when a business rule is violated.
///
/// The [message] is written in Spanish because it is shown to the user as is.
class DomainException implements Exception {
  final String message;
  const DomainException(this.message);
  @override
  String toString() => message;
}

/// Probability returned by a recognition model, always within 0 and 1.
class Confidence {
  final double value;
  const Confidence._(this.value);
  /// Creates a confidence value, clamping [raw] to the 0..1 range and mapping
  /// NaN to 0 so that invalid model outputs never propagate.
  factory Confidence(double raw) =>
      Confidence._(raw.isNaN ? 0 : raw.clamp(0.0, 1.0));
  double get percent => value * 100;
}
