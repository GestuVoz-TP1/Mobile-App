import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/auth_service.dart';
import '../../../domain/auth.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pass.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_email, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final navigator = Navigator.of(context);
      final signedIn =
          await context.read<SessionController>().register(RegistrationForm(
                email: _email.text,
                password: _pass.text,
                passwordConfirm: _pass2.text,
              ));
      if (!mounted) return;
      if (signedIn) {
        navigator.popUntil((r) => r.isFirst);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, size: 40),
          title: const Text('Confirma tu correo'),
          content: Text(
              'Te enviamos un enlace a ${_email.text.trim()}. Ábrelo para '
              'activar tu cuenta y luego inicia sesión. Si no lo ves, revisa '
              'la carpeta de spam.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()));
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo crear la cuenta.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Crea tu cuenta'),
            Text('Datos del adulto responsable',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(Insets.lg),
              children: [
                const StatusNote(
                  'Tus datos se usan solo para administrar el perfil y '
                  'acompañar la comunicación del niño.',
                ),
                const SizedBox(height: Insets.lg),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
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
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.sm),
                _PasswordRules(_pass.text),
                const SizedBox(height: Insets.md),
                TextField(
                  controller: _pass2,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: Insets.md),
                  StatusNote(_error!, kind: NoteKind.error),
                ],
                const SizedBox(height: Insets.lg),
                FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRules extends StatelessWidget {
  final String password;
  const _PasswordRules(this.password);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Requisitos de la contraseña',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, ok) in PasswordPolicy.check(password))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                      ok
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: ok ? AppColors.success : muted),
                  const SizedBox(width: Insets.xs),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: ok ? AppColors.success : muted,
                          fontWeight: ok ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
