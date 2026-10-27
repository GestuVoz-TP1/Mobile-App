/// Gestos iniciales.
///
/// Los cuatro primeros son los gestos iniciales del prototipo. Los siguientes
/// son los que reconoce el modelo entrenado con HaGRIDv2 (repositorio ML,
/// `config/gestos.json`, pendiente de validacion por el especialista). Agua
/// no tiene todavia datos de entrenamiento, por lo que el modelo no la
/// reconoce. El orden importa: define los identificadores `gesto-<id>` y
/// `intencion-<id>` que comparte el backend.
///
/// - `instrucciones`: pasos sugeridos (una linea por paso), editables por el
///   tutor. Describen la forma de la mano con la que se entreno el modelo.
/// - `visual`: emoji con la forma de la mano del gesto.
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
  final String? instructions;

  const SeedGesture({
    required this.name,
    required this.visual,
    required this.recognitionClass,
    required this.intentionName,
    required this.pictogramKey,
    this.instructions,
  });
}

const List<SeedGesture> kSeedGestures = [
  SeedGesture(
    name: 'Hola',
    visual: '🖐️',
    recognitionClass: 'gesto_hola',
    intentionName: 'Saludar',
    pictogramKey: 'r_hola',
    instructions: 'Muestra la mano abierta a la cámara.\n'
        'Separa bien los dedos.',
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
    visual: '☝️',
    recognitionClass: 'gesto_ayuda',
    intentionName: 'Pedir ayuda',
    pictogramKey: 'b_ayuda',
    instructions: 'Levanta solo el dedo índice.\n'
        'Dobla los otros dedos.',
  ),
  SeedGesture(
    name: 'Parar',
    visual: '✋',
    recognitionClass: 'gesto_parar',
    intentionName: 'Pedir que pare',
    pictogramKey: 'r_parar',
    instructions: 'Levanta la mano con la palma hacia la cámara.\n'
        'Junta los dedos, como diciendo «alto».',
  ),
  SeedGesture(
    name: 'Sí',
    visual: '👍',
    recognitionClass: 'gesto_si',
    intentionName: 'Decir que sí',
    pictogramKey: 'r_si',
    instructions: 'Cierra la mano.\n'
        'Levanta el pulgar hacia arriba.',
  ),
  SeedGesture(
    name: 'No',
    visual: '👎',
    recognitionClass: 'gesto_no',
    intentionName: 'Decir que no',
    pictogramKey: 'r_no',
    instructions: 'Cierra la mano.\n'
        'Apunta el pulgar hacia abajo.',
  ),
  SeedGesture(
    name: 'Por favor',
    visual: '🙏',
    recognitionClass: 'gesto_porfavor',
    intentionName: 'Pedir por favor',
    pictogramKey: 'r_porfavor',
    instructions: 'Junta las palmas de las dos manos.\n'
        'Los dedos miran hacia arriba, frente al pecho.',
  ),
  SeedGesture(
    name: 'Terminé',
    visual: '🙅',
    recognitionClass: 'gesto_termine',
    intentionName: 'Avisar que terminó',
    pictogramKey: 'r_termine',
    instructions: 'Cruza los brazos frente al pecho formando una X.\n'
        'Las manos quedan abiertas.',
  ),
  SeedGesture(
    name: 'Silencio',
    visual: '🤫',
    recognitionClass: 'gesto_silencio',
    intentionName: 'Pedir silencio',
    pictogramKey: 'b_silencio',
    instructions: 'Pon el dedo índice sobre los labios.',
  ),
  SeedGesture(
    name: 'Descanso',
    visual: '⏸️',
    recognitionClass: 'gesto_descanso',
    intentionName: 'Pedir un descanso',
    pictogramKey: 'b_descanso',
    instructions: 'Pon una mano plana y horizontal.\n'
        'Con la otra mano, toca su palma con la punta de los dedos: '
        'forma una T.',
  ),
  SeedGesture(
    name: 'Abrazo',
    visual: '🫶',
    recognitionClass: 'gesto_abrazo',
    intentionName: 'Pedir un abrazo',
    pictogramKey: 'b_abrazo',
    instructions: 'Junta las dos manos formando un corazón.\n'
        'Los pulgares abajo y los dedos curvos arriba.',
  ),
];
