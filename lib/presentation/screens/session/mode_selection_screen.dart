import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../caregiver/profiles_screen.dart';

/// Tras iniciar sesion: panel del nino o panel del padre/tutor (OB2, Fig. 8
/// "¿Panel seleccionado?").
class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.activeProfile!;
    return Scaffold(
      appBar: AppBar(
        title: const GestuVozBrand(size: 36),
        actions: [
          TextButton.icon(
            onPressed: session.logout, // HU026
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                const Text('¿Quién usará la app ahora?',
                    style:
                        TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: Insets.md),
                _ModeCard(
                  leading: InitialsAvatar(profile.child.initials, radius: 34),
                  title: 'Panel de ${profile.child.name.split(' ').first}',
                  subtitle: 'Pictogramas y gestos para comunicarse',
                  color: AppColors.primary,
                  dark: true,
                  onTap: () {
                    context.read<CommunicationController>().invalidate();
                    session.enterChildMode();
                  },
                ),
                const SizedBox(height: Insets.md),
                _ModeCard(
                  leading: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.admin_panel_settings_outlined,
                        size: 34, color: AppColors.primaryDark),
                  ),
                  title: 'Panel del padre o tutor',
                  subtitle: 'Perfiles, pictogramas, configuración e historial',
                  color: Colors.white,
                  onTap: session.enterCaregiverMode,
                ),
                const SizedBox(height: Insets.lg),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ProfilesScreen())),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Cambiar de perfil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color color;
  final bool dark;
  final VoidCallback onTap;

  const _ModeCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: dark
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.outline),
                ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: fg)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14, color: fg.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
