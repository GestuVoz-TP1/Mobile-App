import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/child.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_edit_screen.dart';

/// Perfiles infantiles del tutor: seleccionar (HU023), cambiar (HU024),
/// crear (HU021) y eliminar (HU025).
///
/// [isRoot] = se muestra como primera pantalla cuando aun no hay un perfil
/// activo (HU023, criterio 2).
class ProfilesScreen extends StatelessWidget {
  final bool isRoot;
  const ProfilesScreen({super.key, this.isRoot = false});

  Future<void> _select(BuildContext context, ChildProfile p) async {
    final session = context.read<SessionController>();
    await session.selectProfile(p);
    if (context.mounted) {
      context.read<CommunicationController>().invalidate();
      if (!isRoot) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _delete(BuildContext context, ChildProfile p) async {
    final ok = await confirmDialog(
      context,
      title: 'Eliminar perfil',
      message: 'Se eliminará el perfil de ${p.child.name} junto con su '
          'consentimiento, configuración de voz, selección de pictogramas, '
          'preferencias e historial de interacciones. Esta acción no se '
          'puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return; // HU025, criterio 2
    await context.read<SessionController>().deleteProfile(p);
    if (context.mounted) {
      context.read<CommunicationController>().invalidate();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perfil de ${p.child.name} eliminado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profiles = session.profiles;
    final active = session.activeProfile;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !isRoot,
        title: const Text('Perfiles'),
        actions: [
          if (isRoot)
            TextButton.icon(
              onPressed: session.logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Salir'),
            ),
        ],
      ),
      body: SafeArea(
        child: profiles.isEmpty
            ? EmptyState(
                emoji: '👧',
                title: 'Crea el primer perfil',
                message: 'Registra los datos del niño para cargar sus '
                    'pictogramas y preferencias de comunicación.',
                action: FilledButton.icon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Crear perfil'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(Insets.md),
                children: [
                  Text(
                    isRoot
                        ? 'Elige el perfil que utilizará la aplicación.'
                        : 'Toca un perfil para usarlo.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: Insets.sm),
                  for (final p in profiles)
                    _ProfileTile(
                      profile: p,
                      active: p.id == active?.id,
                      onTap: () => _select(context, p),
                      onDelete: () => _delete(context, p),
                    ),
                  const SizedBox(height: Insets.md),
                  OutlinedButton.icon(
                    onPressed: () => _create(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Crear perfil'),
                  ),
                ],
              ),
      ),
    );
  }

  void _create(BuildContext context) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChildEditScreen()));
}

class _ProfileTile extends StatelessWidget {
  final ChildProfile profile;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileTile({
    required this.profile,
    required this.active,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = profile.child;
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Material(
        color: active ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                InitialsAvatar(c.initials, radius: 26),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${c.age} años',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                      if (active)
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text('Perfil activo',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar perfil',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
