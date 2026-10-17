import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/auth.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';

/// Inicio de sesion con correo y contrasena (HU019).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<SessionController>().login(_email.text, _pass.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar sesión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// HU020: envia el correo de restablecimiento de Firebase Authentication.
  /// Criterio 2: valida el correo antes de continuar.
  Future<void> _recover() async {
    final session = context.read<SessionController>();
    final email = await showTextInputDialog(
      context,
      title: 'Recuperar contraseña',
      message: 'Te enviaremos un enlace para crear una nueva contraseña.',
      label: 'Correo electrónico',
      initialValue: _email.text,
      confirmLabel: 'Enviar',
      keyboardType: TextInputType.emailAddress,
      validate: (v) async {
        try {
          await session.sendPasswordReset(v);
          return null;
        } on DomainException catch (e) {
          return e.message;
        } catch (_) {
          return 'No se pudo enviar el correo. Revisa tu conexión.';
        }
      },
    );
    if (email == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c2) => AlertDialog(
        title: const Text('Revisa tu correo'),
        content: Text(
            'Si existe una cuenta con $email, recibirás un enlace para '
            'restablecer tu contraseña. Revisa también la carpeta de spam.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Insets.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: GestuVozBrand()),
                    const SizedBox(height: Insets.lg),
                    const Text('Inicia sesión',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                    Text('Accede a los perfiles que administras.',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                    const SizedBox(height: Insets.lg),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    TextField(
                      controller: _pass,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _recover,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    if (_error != null) ...[
                      StatusNote(_error!, kind: NoteKind.error),
                      const SizedBox(height: Insets.md),
                    ],
                    FilledButton.icon(
                      onPressed: _busy ? null : _submit,
                      icon: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login_rounded),
                      label: const Text('Iniciar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
