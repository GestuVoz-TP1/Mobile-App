import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/communication_service.dart';
import '../../../application/reporting_service.dart';
import '../../../domain/child.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'child_profile_screen.dart';
import 'consent_screen.dart';
import 'profiles_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'vocabulary_screen.dart';
import 'voice_settings_screen.dart';

/// Panel del padre o tutor (mockup 3) con navegacion inferior:
/// Inicio · Reportes · Ajustes.
class CaregiverHub extends StatefulWidget {
  const CaregiverHub({super.key});

  @override
  State<CaregiverHub> createState() => _CaregiverHubState();
}

class _CaregiverHubState extends State<CaregiverHub> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final body = switch (_tab) {
      0 => _HomeTab(onOpenHistory: () => setState(() => _tab = 1)),
      1 => const HistoryScreen(embedded: true),
      _ => const SettingsScreen(),
    };
    return Scaffold(
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Inicio'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Reportes'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Ajustes'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  final VoidCallback onOpenHistory;
  const _HomeTab({required this.onOpenHistory});

  void _go(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final profile = session.activeProfile!;
    final firstName = profile.child.name.split(' ').first;
    return ListView(
      padding: const EdgeInsets.all(Insets.md),
      children: [
        Text(session.account?.email.value ?? '',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text('Acompañemos a $firstName',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: Insets.md),
        _ActiveProfileCard(
          profile: profile,
          onTap: () => _go(context, const ProfilesScreen()),
        ),
        const SizedBox(height: Insets.md),
        _TodayStats(profileId: profile.id!),
        if (!session.consentAllowsProcessing) ...[
          const SizedBox(height: Insets.md),
          StatusNote(
            'El consentimiento de este perfil no está vigente: no se '
            'registran interacciones ni se usa la cámara de gestos.',
            kind: NoteKind.warning,
            action: TextButton(
              onPressed: () => _go(context, const ConsentScreen()),
              child: const Text('Revisar consentimiento'),
            ),
          ),
        ],
        const SectionTitle('Administrar'),
        MenuRow(
          icon: Icons.person_outline_rounded,
          iconBg: AppColors.mint,
          title: 'Perfil del niño',
          subtitle: 'Datos y preferencias',
          onTap: () => _go(context, const ChildProfileScreen()),
        ),
        _PictogramsRow(
          profileId: profile.id!,
          onTap: () => _go(context, const VocabularyScreen()),
        ),
        MenuRow(
          icon: Icons.tune_rounded,
          iconBg: AppColors.lilac,
          title: 'Configuración',
          subtitle: 'Voz y reproducción',
          onTap: () => _go(context, const VoiceSettingsScreen()),
        ),
        MenuRow(
          icon: Icons.history_rounded,
          iconBg: AppColors.blue,
          title: 'Historial',
          subtitle: 'Actividad reciente',
          onTap: onOpenHistory,
        ),
        const SizedBox(height: Insets.md),
        FilledButton.icon(
          onPressed: () {
            context.read<CommunicationController>().invalidate();
            session.enterChildMode();
          },
          icon: const Icon(Icons.child_care_rounded),
          label: Text('Abrir el panel de $firstName'),
        ),
      ],
    );
  }
}

class _ActiveProfileCard extends StatelessWidget {
  final ChildProfile profile;
  final VoidCallback onTap;
  const _ActiveProfileCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Insets.md),
          child: Row(
            children: [
              InitialsAvatar(profile.child.initials, radius: 30),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.child.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800)),
                    Text('${profile.child.age} años · Perfil activo',
                        style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const Tooltip(
                message: 'Cambiar de perfil',
                child: Icon(Icons.swap_horiz_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "interacciones hoy" y "gestos reconocidos" (mockup 3).
class _TodayStats extends StatelessWidget {
  final int profileId;
  const _TodayStats({required this.profileId});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return FutureBuilder(
      future: context.read<ReportingService>().records(profileId,
          from: today, to: today.add(const Duration(days: 1))),
      builder: (context, snap) {
        final records = snap.data ?? const [];
        final summary = context.read<ReportingService>().summarize(records);
        return Row(
          children: [
            Expanded(
              child: _Stat(
                value: snap.hasData ? '${summary.totalInteractions}' : '–',
                label: 'interacciones hoy',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: _Stat(
                value: snap.hasData ? '${summary.gestureInteractions}' : '–',
                label: 'gestos reconocidos hoy',
                color: AppColors.coral,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
}

class _PictogramsRow extends StatelessWidget {
  final int profileId;
  final VoidCallback onTap;
  const _PictogramsRow({required this.profileId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Se reconstruye cuando cambia el tablero (p. ej. tras editar).
    context.watch<CommunicationController>();
    return FutureBuilder<Board>(
      future: context.read<CommunicationService>().buildBoard(profileId),
      builder: (context, snap) => MenuRow(
        icon: Icons.grid_view_rounded,
        iconBg: AppColors.yellow,
        title: 'Pictogramas',
        subtitle: snap.hasData
            ? '${snap.data!.pictogramCount} disponibles'
            : 'Consulta, crea y organiza',
        onTap: onTap,
      ),
    );
  }
}
