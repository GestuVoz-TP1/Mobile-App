import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../infrastructure/sync/sync_service.dart';
import '../theme.dart';
import 'common.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.read<SyncService>();
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: sync.status,
      builder: (context, s, _) {
        if (s.online && (s.pending == 0 || s.syncing)) {
          return const SizedBox.shrink();
        }
        final pending = s.pending == 1
            ? '1 cambio pendiente'
            : '${s.pending} cambios pendientes';
        return Padding(
          padding: const EdgeInsets.only(bottom: Insets.md),
          child: StatusNote(
            s.online
                ? 'Hay datos que todavía no llegan al servidor ($pending). '
                    'Por eso pueden no verse en otros dispositivos.'
                : 'Sin conexión con el servidor. Los cambios se guardan en el '
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
