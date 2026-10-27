import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../infrastructure/sync/sync_service.dart';
import '../theme.dart';
import 'common.dart';

/// Aviso de conexion con el servidor (RNF-05). Solo aparece si no hay
/// conexion; los cambios quedan guardados en el telefono.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.read<SyncService>();
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, s, _) {
        if (s.online) return const SizedBox.shrink();
        final pending = s.pending == 1
            ? '1 cambio pendiente'
            : '${s.pending} cambios pendientes';
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: StatusNote(
            'Sin conexión con el servidor. Los cambios se guardan en el '
            'teléfono y se enviarán al reconectar ($pending).',
            kind: NoteKind.warning,
            action: TextButton.icon(
              onPressed: s.syncing ? null : sync.pushPending,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Reintentar'),
            ),
          ),
        );
      },
    );
  }
}
