import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/session_controller.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/caregiver/caregiver_hub.dart';
import 'screens/caregiver/consent_screen.dart';
import 'screens/caregiver/profiles_screen.dart';
import 'screens/child/child_shell.dart';
import 'screens/session/mode_selection_screen.dart';
import 'theme.dart';

class GestuVozApp extends StatelessWidget {
  const GestuVozApp({super.key});

  @override
  Widget build(BuildContext context) {
    final highContrast = context.select<SessionController, bool>(
        (s) => s.ready && s.highContrast);
    return MaterialApp(
      title: 'GestuVoz',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(highContrast: highContrast),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final scale = (mq.textScaler.scale(1) * 1.04).clamp(1.0, 1.5);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        );
      },
      home: const _Router(),
    );
  }
}

/// Navegacion principal (OB2, Fig. 8):
/// acceso -> perfil -> consentimiento -> panel del nino / panel del tutor.
class _Router extends StatelessWidget {
  const _Router();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionController>();
    if (!s.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!s.isLoggedIn) return const WelcomeScreen();
    // HU023: sin perfil activo se elige o se crea el primero.
    if (s.activeProfile == null) return const ProfilesScreen(isRoot: true);
    // D3: el consentimiento se registra al crear el perfil.
    if (s.consent == null) return const ConsentScreen(onboarding: true);
    return switch (s.mode) {
      AppMode.child => const ChildShell(),
      AppMode.caregiver => const CaregiverHub(),
      AppMode.none => const ModeSelectionScreen(),
    };
  }
}
