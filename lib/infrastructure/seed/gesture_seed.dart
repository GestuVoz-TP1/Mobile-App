library;

class SeedGesture {
  final String name;
  final String visual;
  final String recognitionClass;
  final String intentionName;
  final String pictogramKey;
  final String? instructions;
  final List<String> previousInstructions;

  const SeedGesture({
    required this.name,
    required this.visual,
    required this.recognitionClass,
    required this.intentionName,
    required this.pictogramKey,
    this.instructions,
    this.previousInstructions = const [],
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
    instructions: 'Forma una C con la mano, como sosteniendo un vaso.\n'
        'Llévala a la boca.',
  ),
  SeedGesture(
    name: 'Ayuda',
    visual: '☝️',
    recognitionClass: 'gesto_ayuda',
    intentionName: 'Pedir ayuda',
    pictogramKey: 'b_ayuda',
    instructions: 'Levanta el brazo y muestra solo el dedo índice hacia '
        'arriba.\n'
        'Dobla los otros dedos.',
    previousInstructions: [
      'Levanta solo el dedo índice.\n'
          'Dobla los otros dedos.',
    ],
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
  SeedGesture(
    name: 'Baño',
    visual: '✌️',
    recognitionClass: 'gesto_bano',
    intentionName: 'Pedir ir al baño',
    pictogramKey: 'b_bano',
    instructions: 'Levanta los dedos índice y medio en forma de V.\n'
        'Ponlos frente al pecho.',
  ),
  SeedGesture(
    name: 'Hambre',
    visual: '🍽️',
    recognitionClass: 'gesto_hambre',
    intentionName: 'Pedir comida',
    pictogramKey: 'b_hambre',
    instructions: 'Apoya la mano abierta en la barriga.\n'
        'Muévela en círculos dos o tres vueltas.',
  ),
  SeedGesture(
    name: 'Dormir',
    visual: '😴',
    recognitionClass: 'gesto_dormir',
    intentionName: 'Expresar sueño',
    pictogramKey: 'b_dormir',
    instructions: 'Pon la mano abierta debajo de la mejilla, como una almohada.\n'
        'Inclina la cabeza hacia la mano.',
  ),
];
