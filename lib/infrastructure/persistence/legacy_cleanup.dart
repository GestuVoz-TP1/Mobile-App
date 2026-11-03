import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

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
