import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/auth_service.dart';
import '../../../domain/auth.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Registro de la cuenta del padre o tutor (HU018, mockup 2).
/// Solo correo y contrasena (modelo PADRE_TUTOR). El consentimiento se
/// registra al crear cada perfil infantil.
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
      await context.read<SessionController>().register(RegistrationForm(
            email: _email.text,
            password: _pass.text,
            passwordConfirm: _pass2.text,
          ));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on DomainException catch (e) {
      setState(() => _error = e.message); // HU018, criterio 2
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
                    helperText:
                        'Al menos ${AuthService.minPasswordLength} caracteres.',
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
