import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'di.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configuracion tomada de android/app/google-services.json.
  await Firebase.initializeApp();
  final di = await Di.build();
  runApp(
    MultiProvider(
      providers: di.providers,
      child: const GestuVozApp(),
    ),
  );
}
