/// -------------------------------------------------------------------------
/// SHARED KERNEL del dominio
///
/// Tipos compartidos por varios bounded contexts. Se mantiene minimo a
/// proposito: solo lo que de verdad cruza fronteras.
/// -------------------------------------------------------------------------
library;

/// Error de regla de negocio. La capa de presentacion lo traduce a mensajes.
class DomainException implements Exception {
  final String message;
  const DomainException(this.message);
  @override
  String toString() => message;
}

/// Value object 0..1 para la confianza que reporta un modelo de
/// reconocimiento. Solo lo produce un modelo real; nunca se inventan valores
/// de confianza.
class Confidence {
  final double value;
  const Confidence._(this.value);
  factory Confidence(double raw) =>
      Confidence._(raw.isNaN ? 0 : raw.clamp(0.0, 1.0));
  double get percent => value * 100;
}
