import 'package:flutter/material.dart';

import '../theme.dart';

/// Avatar con las iniciales del nino (D6: el modelo no tiene avatar).
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double radius;
  const InitialsAvatar(this.initials, {super.key, this.radius = 28});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.yellow,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.75,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
      );
}

enum NoteKind { info, success, warning, error }

/// Mensaje de estado con icono + texto (nunca solo color, RNF-04).
class StatusNote extends StatelessWidget {
  final NoteKind kind;
  final String text;
  final Widget? action;

  const StatusNote(this.text,
      {super.key, this.kind = NoteKind.info, this.action});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (kind) {
      NoteKind.info => (AppColors.primarySoft, AppColors.primaryDark,
          Icons.info_outline_rounded),
      NoteKind.success => (AppColors.successSoft, AppColors.success,
          Icons.check_circle_outline_rounded),
      NoteKind.warning => (AppColors.amberSoft, AppColors.amberInk,
          Icons.lightbulb_outline_rounded),
      NoteKind.error => (AppColors.coralSoft, const Color(0xFF9A2E22),
          Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: kind == NoteKind.error,
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: TextStyle(
                          color: fg,
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600)),
                  if (action != null) ...[
                    const SizedBox(height: Insets.xs),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta "DEMO" para contenido no oficial (D7, D10).
class DemoBadge extends StatelessWidget {
  final String text;
  const DemoBadge({super.key, this.text = 'DEMO'});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.amberSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.yellowAccent),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.amberInk,
                letterSpacing: 0.4)),
      );
}

/// Titulo de seccion.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, Insets.md, 4, Insets.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w700)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Fila de menu del tutor (mockup 3, "Administrar").
class MenuRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const MenuRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Insets.sm),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Radii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: iconBg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: AppColors.primaryDark),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Pantalla de "algo salio mal" con reintento (HU003/HU029/HU033 crit. 2).
class RetryPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const RetryPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Volver a intentar',
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusNote(message, kind: NoteKind.error),
              const SizedBox(height: Insets.md),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ),
        ),
      );
}

/// Estado vacio con icono y texto.
class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: Insets.sm),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              if (message != null) ...[
                const SizedBox(height: Insets.xs),
                Text(message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
              if (action != null) ...[
                const SizedBox(height: Insets.md),
                action!,
              ],
            ],
          ),
        ),
      );
}

/// Confirmacion generica (HU025, HU028: confirmar / cancelar).
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.coral)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Dialogo con un campo de texto. El dialogo es dueno de su controlador y lo
/// libera en su propio dispose (cuando termina la animacion de cierre), lo
/// que evita usar un controlador ya destruido.
///
/// [validate] devuelve un mensaje de error o null si el valor es correcto.
/// Devuelve el texto aceptado, o null si se cancela.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String label,
  String initialValue = '',
  String confirmLabel = 'Aceptar',
  bool obscure = false,
  TextInputType? keyboardType,
  Future<String?> Function(String value)? validate,
}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextInputDialog(
        title: title,
        message: message,
        label: label,
        initialValue: initialValue,
        confirmLabel: confirmLabel,
        obscure: obscure,
        keyboardType: keyboardType,
        validate: validate,
      ),
    );

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String label;
  final String initialValue;
  final String confirmLabel;
  final bool obscure;
  final TextInputType? keyboardType;
  final Future<String?> Function(String value)? validate;

  const _TextInputDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.initialValue,
    required this.confirmLabel,
    required this.obscure,
    required this.keyboardType,
    required this.validate,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialValue);
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.validate?.call(_ctrl.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.message != null) ...[
              Text(widget.message!),
              const SizedBox(height: Insets.md),
            ],
            TextField(
              controller: _ctrl,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: widget.label,
                errorText: _error,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
