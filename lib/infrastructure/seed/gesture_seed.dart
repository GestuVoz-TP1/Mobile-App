/// Gestos DEMO (D10).
///
/// IMPORTANTE: NO son el repertorio oficial del proyecto. Los documentos aun no
/// definen el conjunto de gestos; estos cuatro existen solo para probar el
/// flujo completo de reconocimiento (camara -> gesto -> intencion ->
/// pictograma -> voz -> interaccion) con el reconocedor DEMO.
///
/// - `clase_reconocimiento` usa el prefijo `demo_`.
/// - `instrucciones` inicia vacio y es editable por el tutor.
/// - Cada gesto se enlaza a un pictograma semilla existente ([pictogramKey]),
///   cuya frase es el mensaje de la intencion.
///
/// Para cargar el repertorio oficial: reemplazar esta lista (o insertar las
/// filas en GESTO / INTENCION_COMUNICATIVA) con las clases que devuelva el
/// modelo TensorFlow Lite. El resto de la app no cambia.
library;

class SeedGesture {
  final String name;
  final String description;
  final String visual;
  final String recognitionClass;
  final String intentionName;
  final String pictogramKey;

  const SeedGesture({
    required this.name,
    required this.description,
    required this.visual,
    required this.recognitionClass,
    required this.intentionName,
    required this.pictogramKey,
  });
}

const String kDemoLabel = 'DEMO';

const List<SeedGesture> kDemoGestures = [
  SeedGesture(
    name: 'Hola',
    description: 'Gesto DEMO (no oficial) para probar el reconocimiento.',
    visual: '👋',
    recognitionClass: 'demo_hola',
    intentionName: 'Saludar (DEMO)',
    pictogramKey: 'r_hola',
  ),
  SeedGesture(
    name: 'Agua',
    description: 'Gesto DEMO (no oficial) para probar el reconocimiento.',
    visual: '💧',
    recognitionClass: 'demo_agua',
    intentionName: 'Pedir agua (DEMO)',
    pictogramKey: 'b_agua',
  ),
  SeedGesture(
    name: 'Ayuda',
    description: 'Gesto DEMO (no oficial) para probar el reconocimiento.',
    visual: '🆘',
    recognitionClass: 'demo_ayuda',
    intentionName: 'Pedir ayuda (DEMO)',
    pictogramKey: 'b_ayuda',
  ),
  SeedGesture(
    name: 'Parar',
    description: 'Gesto DEMO (no oficial) para probar el reconocimiento.',
    visual: '✋',
    recognitionClass: 'demo_parar',
    intentionName: 'Pedir que pare (DEMO)',
    pictogramKey: 'r_parar',
  ),
];
