import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/gesture_service.dart';
import '../../application/interaction_service.dart';
import '../../domain/gesture.dart';
import '../../domain/ml.dart';
import '../../infrastructure/camera/camera_service.dart';
import '../../infrastructure/tts/tts_service.dart';
import 'session_controller.dart';

enum GesturePhase {
  loading,
  unavailable,
  preparation,
  startingCamera,
  cameraIssue,
  capturing,
  choosingTestResult,
  analyzing,
  recognized,
  notRecognized,
}

enum GestureUnavailableReason { disabled, noConsent, noGestures, error }

class CaptureController extends ChangeNotifier {
  CaptureController({
    required CameraService camera,
    required GestureService gestures,
    required InteractionService interactions,
    required SessionController session,
    required TtsService tts,
  })  : camera = camera,
        _gestures = gestures,
        _interactions = interactions,
        _session = session,
        _tts = tts;

  final CameraService camera;
  final GestureService _gestures;
  final InteractionService _interactions;
  final SessionController _session;
  final TtsService _tts;

  GesturePhase _phase = GesturePhase.loading;
  GesturePhase get phase => _phase;

  GestureUnavailableReason? _reason;
  GestureUnavailableReason? get unavailableReason => _reason;

  List<Gesture> _enabled = const [];
  List<Gesture> get enabledGestures => _enabled;

  GestureOutcome? _outcome;
  GestureOutcome? get outcome => _outcome;

  bool _voiceFailed = false;
  bool get voiceFailed => _voiceFailed;

  bool get testModeAvailable => kDebugMode && _gestures.supportsTestOutcome;
  RecognizerInfo get recognizerInfo => _gestures.recognizerInfo;

  GestureSequence _lastSequence = const GestureSequence([]);
  bool _disposed = false;

  static const searchTimeout = Duration(seconds: 10);
  Completer<GestureOutcome?>? _search;

  void _stopSearch() {
    final s = _search;
    if (s != null && !s.isCompleted) s.complete(null);
  }

  void _set(GesturePhase p) {
    _phase = p;
    if (!_disposed) notifyListeners();
  }

  Future<void> open() async {
    _outcome = null;
    _reason = null;
    _set(GesturePhase.loading);
    final profile = _session.activeProfile;
    if (profile == null) return;
    try {
      if (!profile.preferences.gesturesEnabled) {
        _reason = GestureUnavailableReason.disabled;
      } else if (!_session.consentAllowsProcessing) {
        _reason = GestureUnavailableReason.noConsent;
      } else {
        _enabled = await _gestures.enabledFor(profile);
        if (_enabled.isEmpty) _reason = GestureUnavailableReason.noGestures;
      }
      if (_reason == null) await _gestures.ensureLoaded();
    } catch (_) {
      _reason = GestureUnavailableReason.error;
    }
    _set(_reason == null ? GesturePhase.preparation : GesturePhase.unavailable);
  }

  Future<void> start() async {
    _set(GesturePhase.startingCamera);
    if (!camera.isReady) {
      await camera.discover();
      await camera.start();
    }
    if (_disposed) return;
    if (!camera.isReady) {
      _set(GesturePhase.cameraIssue);
      return;
    }
    await _capture();
  }

  Future<void> retry() async {
    _outcome = null;
    _voiceFailed = false;
    if (!camera.isReady) return start();
    await _capture();
  }

  Future<void> _capture() async {
    _outcome = null;
    _set(GesturePhase.capturing);
    if (!testModeAvailable && _gestures.supportsContinuous) {
      return _captureContinuous();
    }
    final seq = await camera.captureSequence();
    if (_disposed || _phase != GesturePhase.capturing) return;
    _lastSequence = seq;
    if (testModeAvailable) {
      _set(GesturePhase.choosingTestResult);
    } else {
      await _recognize();
    }
  }

  Future<void> chooseTestResult(String? recognitionClass) async {
    _gestures.setTestOutcome(recognitionClass);
    await _recognize();
  }

  Future<void> _captureContinuous() async {
    _gestures.resetContinuous();
    final search = _search = Completer<GestureOutcome?>();
    final profileId = _session.activeProfile?.id;
    final timer = Timer(searchTimeout, _stopSearch);
    var busy = false;
    final started = await camera.startFrames((frame) async {
      if (busy || search.isCompleted || profileId == null) return;
      busy = true;
      try {
        final out =
            await _gestures.addFrame(frame, _enabled, profileId: profileId);
        if (out != null && !search.isCompleted) search.complete(out);
      } catch (e) {
        debugPrint('Error al reconocer el fotograma: $e');
      } finally {
        busy = false;
      }
    });
    if (!started) _stopSearch();
    final out = await search.future;
    timer.cancel();
    _search = null;
    await camera.stopFrames();
    if (_disposed || _phase != GesturePhase.capturing) return;
    await _finish(out);
  }

  Future<void> _recognize() async {
    _set(GesturePhase.analyzing);
    GestureOutcome? out;
    try {
      final profileId = _session.activeProfile?.id;
      out = profileId == null
          ? null
          : await _gestures.recognize(_lastSequence, _enabled,
              profileId: profileId);
    } catch (_) {
      out = null;
    }
    _lastSequence = const GestureSequence([]);
    await _finish(out);
  }

  Future<void> _finish(GestureOutcome? out) async {
    final profile = _session.activeProfile;
    if (_disposed) return;
    if (out == null || profile == null) {
      _set(GesturePhase.notRecognized);
      return;
    }
    _outcome = out;
    _set(GesturePhase.recognized);
    if (_session.voice?.voiceEnabled ?? true) {
      _voiceFailed = !await _tts.speak(out.intention.message);
      if (!_disposed) notifyListeners();
    }
    await _interactions.recordGesture(
      profile.id!,
      gesture: out.gesture,
      intention: out.intention,
      pictogram: out.pictogram,
    );
  }

  Future<void> speakAgain() async {
    final o = _outcome;
    if (o == null) return;
    _voiceFailed = !await _tts.speak(o.intention.message);
    notifyListeners();
  }

  void backToPreparation() {
    _stopSearch();
    _outcome = null;
    _set(GesturePhase.preparation);
  }

  Future<void> releaseCamera() async {
    _stopSearch();
    await camera.dispose();
    if (_phase == GesturePhase.capturing ||
        _phase == GesturePhase.startingCamera) {
      _set(GesturePhase.preparation);
    }
  }

  Future<void> close() async {
    _stopSearch();
    await camera.dispose();
    _outcome = null;
    _lastSequence = const GestureSequence([]);
    _phase = GesturePhase.loading;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopSearch();
    camera.dispose();
    super.dispose();
  }
}
