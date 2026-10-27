/// Gestos iniciales.
///
/// Los cuatro primeros son los gestos iniciales del prototipo. Los siguientes
/// son los que reconoce el modelo entrenado con HaGRIDv2 (repositorio ML,
/// `config/gestos.json`, pendiente de validacion por el especialista). Agua
/// no tiene todavia datos de entrenamiento, por lo que el modelo no la
/// reconoce. El orden importa: define los identificadores `gesto-<id>` y
/// `intencion-<id>` que comparte el backend.
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
  SeedGesture(
    name: 'Sí',
    visual: '👍',
    recognitionClass: 'gesto_si',
    intentionName: 'Decir que sí',
    pictogramKey: 'r_si',
  ),
  SeedGesture(
    name: 'No',
    visual: '👎',
    recognitionClass: 'gesto_no',
    intentionName: 'Decir que no',
    pictogramKey: 'r_no',
  ),
  SeedGesture(
    name: 'Por favor',
    visual: '🙏',
    recognitionClass: 'gesto_porfavor',
    intentionName: 'Pedir por favor',
    pictogramKey: 'r_porfavor',
  ),
  SeedGesture(
    name: 'Terminé',
    visual: '🙅',
    recognitionClass: 'gesto_termine',
    intentionName: 'Avisar que terminó',
    pictogramKey: 'r_termine',
  ),
  SeedGesture(
    name: 'Silencio',
    visual: '🤫',
    recognitionClass: 'gesto_silencio',
    intentionName: 'Pedir silencio',
    pictogramKey: 'b_silencio',
  ),
  SeedGesture(
    name: 'Descanso',
    visual: '⏸️',
    recognitionClass: 'gesto_descanso',
    intentionName: 'Pedir un descanso',
    pictogramKey: 'b_descanso',
  ),
  SeedGesture(
    name: 'Abrazo',
    visual: '🫶',
    recognitionClass: 'gesto_abrazo',
    intentionName: 'Pedir un abrazo',
    pictogramKey: 'b_abrazo',
  ),
];
