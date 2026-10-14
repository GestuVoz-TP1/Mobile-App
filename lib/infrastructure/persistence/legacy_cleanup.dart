import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Elimina las fotografias que guardaba el antiguo modulo de
/// "datos de entrenamiento" (expresion facial), retirado por estar fuera del
/// alcance aprobado (OB2, RNF-02).
///
/// Solo borra la carpeta `training_images/`. No toca ningun otro archivo
/// (por ejemplo `pictogram_images/`, recursos de la app u otros datos).
/// Una vez borrada, las siguientes ejecuciones no hacen nada.
Future<void> removeLegacyTrainingImages() async {
  try {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/training_images');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  } catch (e) {
    debugPrint('No se pudo limpiar training_images: $e');
  }
}
