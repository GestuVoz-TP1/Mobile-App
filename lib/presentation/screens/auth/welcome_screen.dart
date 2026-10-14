import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/brand.dart';
import 'login_screen.dart';
import 'register_screen.dart';

/// Bienvenida (mockup 1): iniciar sesion o crear cuenta de padre o tutor.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.all(Insets.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: Insets.md),
                          const GestuVozBrand(),
                          const SizedBox(height: Insets.lg),
                          Container(
                            height: 210,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🤟', style: TextStyle(fontSize: 72)),
                                const SizedBox(height: Insets.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.record_voice_over_rounded,
                                          size: 20,
                                          color: AppColors.primaryDark),
                                      SizedBox(width: 6),
                                      Text('Cada gesto tiene voz',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryDark)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Insets.lg),
                          const Text(
                            'Comunicarnos nos acerca',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: Insets.xs),
                          Text(
                            'Una herramienta simple y segura para acompañar '
                            'la comunicación de tu niño.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: Insets.lg),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen())),
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('Iniciar sesión'),
                              ),
                            ),
                            const SizedBox(height: Insets.sm),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen())),
                                icon: const Icon(
                                    Icons.person_add_alt_1_outlined),
                                label: const Text('Crear cuenta de padre o tutor'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
