import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../application/profile_service.dart';
import '../../../domain/child.dart';
import '../../controllers/session_controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';

/// Formulario del perfil infantil: crear o actualizar. Campos del modelo: NINO
/// (nombre, fecha de nacimiento, genero) y PERFIL_NINO (nivel de apoyo).
class ChildEditScreen extends StatefulWidget {
  /// null = crear un perfil nuevo.
  final ChildProfile? profile;
  const ChildEditScreen({super.key, this.profile});

  @override
  State<ChildEditScreen> createState() => _ChildEditScreenState();
}

class _ChildEditScreenState extends State<ChildEditScreen> {
  late final TextEditingController _name;
  DateTime? _birth;
  String? _gender;
  String? _support;
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.profile == null;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p?.child.name ?? '');
    _support = p?.supportLevel;
    _birth = p?.child.birthDate;
    _gender = p?.child.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 6, now.month, now.day),
      firstDate: DateTime(now.year - 18),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked != null) setState(() => _birth = picked);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final form = ProfileForm(
      name: _name.text,
      birthDate: _birth,
      gender: _gender,
      supportLevel: _support,
    );
    try {
      if (_isNew) {
        await session.createProfile(form);
        // Vuelve a la raiz: el router muestra el consentimiento.
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      } else {
        await session.updateProfile(widget.profile!, form);
        if (mounted) Navigator.of(context).pop();
      }
    } on DomainException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'No se pudo guardar el perfil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isNew ? 'Nuevo perfil' : 'Editar perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Insets.lg),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del niño *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: Insets.md),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha de nacimiento *',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _birth == null ? 'Seleccionar fecha' : formatDate(_birth!),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String>(
              initialValue: kGenderOptions.contains(_gender) ? _gender : null,
              decoration: const InputDecoration(
                labelText: 'Género (opcional)',
                prefixIcon: Icon(Icons.wc_rounded),
              ),
              items: [
                for (final g in kGenderOptions)
                  DropdownMenuItem(value: g, child: Text(g)),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: Insets.md),
            DropdownButtonFormField<String?>(
              initialValue: _support,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Nivel de apoyo (opcional)',
                helperText: 'Según la evaluación de un especialista. Si no lo '
                    'sabes, déjalo sin especificar.',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.support_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin especificar')),
                for (final level in kSupportLevelOptions)
                  DropdownMenuItem(value: level, child: Text(level)),
                // Un texto escrito antes de existir la lista se conserva.
                if (_support != null && !kSupportLevelOptions.contains(_support))
                  DropdownMenuItem(value: _support, child: Text(_support!)),
              ],
              onChanged: (v) => setState(() => _support = v),
            ),
            const SizedBox(height: Insets.sm),
            Text('* Campos obligatorios',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (_error != null) ...[
              const SizedBox(height: Insets.md),
              StatusNote(_error!, kind: NoteKind.error),
            ],
            const SizedBox(height: Insets.lg),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isNew ? 'Crear perfil' : 'Guardar cambios'),
            ),
            if (_isNew) ...[
              const SizedBox(height: Insets.sm),
              Text(
                'Después te pediremos tu decisión sobre el tratamiento de '
                'los datos del niño.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
