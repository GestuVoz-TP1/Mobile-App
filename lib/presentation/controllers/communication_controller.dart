import 'package:flutter/foundation.dart';

import '../../application/communication_service.dart';
import '../../application/interaction_service.dart';
import '../../domain/communication.dart';
import '../../infrastructure/tts/tts_service.dart';
import 'session_controller.dart';

class CommunicationController extends ChangeNotifier {
  CommunicationController({
    required CommunicationService communication,
    required InteractionService interactions,
    required SessionController session,
    required TtsService tts,
  })  : _service = communication,
        _interactions = interactions,
        _session = session,
        _tts = tts;

  final CommunicationService _service;
  final InteractionService _interactions;
  final SessionController _session;
  final TtsService _tts;

  Board? _board;
  Board? get board => _board;

  int? _boardProfileId;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Pictogram? _message;
  Pictogram? get message => _message;

  bool _voiceFailed = false;
  bool get voiceFailed => _voiceFailed;

  bool get voiceEnabled => _session.voice?.voiceEnabled ?? true;

  Future<void> loadBoard({bool force = false}) async {
    final profile = _session.activeProfile;
    if (profile == null) return;
    if (!force && _board != null && _boardProfileId == profile.id) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _board = await _service.buildBoard(profile.id!);
      _boardProfileId = profile.id;
      _message = null;
      _voiceFailed = false;
    } catch (_) {
      _error = 'No se pudieron cargar los pictogramas.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void invalidate() {
    _board = null;
    _boardProfileId = null;
    _message = null;
    notifyListeners();
  }

  Future<void> pick(Pictogram p) async {
    final profile = _session.activeProfile;
    if (profile == null) return;
    _message = p;
    _voiceFailed = false;
    notifyListeners();
    if (voiceEnabled) {
      _voiceFailed = !await _tts.speak(p.message);
      notifyListeners();
    }
    await _interactions.recordPictogram(profile.id!, p);
  }

  Future<void> speakMessage() async {
    final p = _message;
    if (p == null) return;
    _voiceFailed = !await _tts.speak(p.message);
    notifyListeners();
  }

  void clearMessage() {
    _message = null;
    _voiceFailed = false;
    _tts.stop();
    notifyListeners();
  }
}
