import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/consent.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_profile_screen.dart';
import 'consent_screen.dart';
import 'gestures_catalog_screen.dart';
import 'profiles_screen.dart';
import 'vocabulary_screen.dart';
import 'voice_settings_screen.dart';

/// Pestana "Ajustes" del panel del tutor.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _go(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        const Text('Ajustes',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        Text(session.account?.email.value ?? '',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SectionTitle('Perfiles'),
        MenuRow(
          icon: Icons.people_outline_rounded,
          iconBg: AppColors.mint,
          title: 'Perfiles infantiles',
          subtitle: 'Crear, cambiar o eliminar perfiles',
          onTap: () => _go(context, const ProfilesScreen()),
        ),
        MenuRow(
          icon: Icons.person_outline_rounded,
          iconBg: AppColors.mint,
          title: 'Perfil del niño',
          subtitle: 'Datos, preferencias y gestos',
          onTap: () => _go(context, const ChildProfileScreen()),
        ),
        const SectionTitle('Comunicación'),
        MenuRow(
          icon: Icons.record_voice_over_outlined,
          iconBg: AppColors.lilac,
          title: 'Voz y reproducción',
          subtitle: 'Voz, velocidad y volumen',
          onTap: () => _go(context, const VoiceSettingsScreen()),
        ),
        MenuRow(
          icon: Icons.grid_view_rounded,
          iconBg: AppColors.yellow,
          title: 'Pictogramas',
          subtitle: 'Consulta, crea y organiza',
          onTap: () => _go(context, const VocabularyScreen()),
        ),
        MenuRow(
          icon: Icons.back_hand_outlined,
          iconBg: AppColors.peach,
          title: 'Gestos disponibles',
          subtitle: 'Catálogo e instrucciones',
          onTap: () => _go(context, const GesturesCatalogScreen()),
        ),
        const SectionTitle('Privacidad'),
        MenuRow(
          icon: Icons.shield_outlined,
          iconBg: AppColors.blue,
          title: 'Privacidad y consentimiento',
          subtitle: session.consent?.state.label ?? 'Sin decisión',
          onTap: () => _go(context, const ConsentScreen()),
        ),
        const SizedBox(height: Insets.md),
        OutlinedButton.icon(
          onPressed: session.backToModeSelection,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Cambiar de panel'),
        ),
        const SizedBox(height: Insets.sm),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral),
          onPressed: session.logout, // HU026
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}
