import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../category_style.dart';
import '../../controllers/communication_controller.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../capture/interaction_capture_screen.dart';
import 'communicator_screen.dart';

/// Experiencia del nino (mockup 5): Inicio · Hablar · Gestos.
/// Interfaz sencilla, sin opciones administrativas. Para salir se pide la
/// contrasena del tutor.
class ChildShell extends StatefulWidget {
  const ChildShell({super.key});

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> {
  int _tab = 0;
  int? _category;

  bool _gesturesOn(SessionController s) =>
      s.activeProfile?.preferences.gesturesEnabled ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<CommunicationController>().loadBoard());
  }

  void _openBoard([int? categoryId]) => setState(() {
        _category = categoryId;
        _tab = 1;
      });

  Future<void> _exit() async {
    final session = context.read<SessionController>();
    final password = await showTextInputDialog(
      context,
      title: 'Salir del panel del niño',
      message: 'Pide a tu padre, madre o tutor que ingrese su contraseña.',
      label: 'Contraseña del tutor',
      confirmLabel: 'Salir',
      obscure: true,
      validate: (v) async => await session.verifyTutorPassword(v)
          ? null
          : 'Contraseña incorrecta',
    );
    if (password == null || !mounted) return; // cancelado
    // Se cambia de pantalla cuando el dialogo ya termino de cerrarse.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) await session.leaveChildMode();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final gesturesOn = _gesturesOn(session);
    if (!gesturesOn && _tab == 2) _tab = 0;
    final destinations = [
      const NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio'),
      const NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Hablar'),
      if (gesturesOn)
        const NavigationDestination(
            icon: Icon(Icons.back_hand_outlined),
            selectedIcon: Icon(Icons.back_hand_rounded),
            label: 'Gestos'),
    ];
    final body = switch (_tab) {
      0 => _ChildHome(
          onCategory: _openBoard,
          onGestures: gesturesOn ? () => setState(() => _tab = 2) : null,
          onExit: _exit,
        ),
      1 => CommunicatorScreen(
          key: ValueKey(_category),
          initialCategoryId: _category,
          onBack: () => setState(() => _tab = 0),
        ),
      _ => GestureRecognitionScreen(onUsePictograms: () => _openBoard()),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          _exit();
        }
      },
      child: Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          height: 76,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() {
            if (i == 1) _category = null;
            _tab = i;
          }),
          destinations: destinations,
        ),
      ),
    );
  }
}

/// Inicio del nino (mockup 5): saludo, "Usar mis gestos" y "Mis palabras".
class _ChildHome extends StatelessWidget {
  final ValueChanged<int> onCategory;
  final VoidCallback? onGestures;
  final VoidCallback onExit;

  const _ChildHome({
    required this.onCategory,
    required this.onGestures,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final comm = context.watch<CommunicationController>();
    final profile = session.activeProfile!;
    final board = comm.board;
    final categories = board == null
        ? const []
        : board.categories
            .where((c) => (board.byCategory[c.id] ?? const []).isNotEmpty)
            .toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(Insets.md),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Hola, ${profile.child.name.split(' ').first}! 👋',
                        style: const TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                    const Text('¿Qué quieres decir?',
                        style: TextStyle(
                            fontSize: 18, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Salir del panel del niño',
                child: GestureDetector(
                  onTap: onExit,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      InitialsAvatar(profile.child.initials, radius: 30),
                      const CircleAvatar(
                        radius: 11,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.lock_outline_rounded,
                            size: 14, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          if (onGestures != null)
            Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: onGestures,
                child: Padding(
                  padding: const EdgeInsets.all(Insets.md),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        alignment: Alignment.center,
                        child:
                            const Text('🤟', style: TextStyle(fontSize: 42)),
                      ),
                      const SizedBox(width: Insets.md),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Usar mis gestos',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800)),
                            Text('La cámara te ayudará a hablar',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 15)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 30),
                    ],
                  ),
                ),
              ),
            ),
          const SectionTitle('Mis palabras'),
          if (board == null)
            const Padding(
              padding: EdgeInsets.all(Insets.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (board.isEmpty)
            // HU007, criterio 2
            const EmptyState(
              emoji: '🗂️',
              title: 'Todavía no hay pictogramas disponibles',
              message: 'Pide a tu tutor que agregue pictogramas.',
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Insets.md,
              crossAxisSpacing: Insets.md,
              childAspectRatio: 1.25,
              children: [
                for (final c in categories)
                  _CategoryCard(
                    name: c.name,
                    style: CategoryStyle.of(c.id),
                    onTap: () => onCategory(c.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String name;
  final CategoryStyle style;
  final VoidCallback onTap;

  const _CategoryCard(
      {required this.name, required this.style, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: name,
        child: Material(
          color: style.background,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.tile),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(style.emoji, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: Insets.xs),
                  Text(name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      );
}
