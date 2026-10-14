import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'di.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final di = await Di.build();
  runApp(
    MultiProvider(
      providers: di.providers,
      child: const GestuVozApp(),
    ),
  );
}
