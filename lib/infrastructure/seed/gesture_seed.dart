/// Gestos iniciales.
///
/// Los documentos aun no definen el repertorio oficial de gestos. Estos
/// cuatro permiten usar el flujo completo de reconocimiento (camara -> gesto
/// -> intencion -> pictograma -> voz -> interaccion) mientras tanto.
///
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
  final String visual;
  final String recognitionClass;
  final String intentionName;
  final String pictogramKey;

  const SeedGesture({
    required this.name,
    required this.visual,
    required this.recognitionClass,
    required this.intentionName,
    required this.pictogramKey,
  });
}

const List<SeedGesture> kSeedGestures = [
  SeedGesture(
    name: 'Hola',
    visual: '👋',
    recognitionClass: 'gesto_hola',
    intentionName: 'Saludar',
    pictogramKey: 'r_hola',
  ),
  SeedGesture(
    name: 'Agua',
    visual: '💧',
    recognitionClass: 'gesto_agua',
    intentionName: 'Pedir agua',
    pictogramKey: 'b_agua',
  ),
  SeedGesture(
    name: 'Ayuda',
    visual: '🆘',
    recognitionClass: 'gesto_ayuda',
    intentionName: 'Pedir ayuda',
    pictogramKey: 'b_ayuda',
  ),
  SeedGesture(
    name: 'Parar',
    visual: '✋',
    recognitionClass: 'gesto_parar',
    intentionName: 'Pedir que pare',
    pictogramKey: 'r_parar',
  ),
];
