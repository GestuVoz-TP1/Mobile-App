import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../application/gesture_service.dart';
import '../../application/interaction_service.dart';
import '../../domain/gesture.dart';
import '../../domain/ml.dart';
import '../../infrastructure/camera/camera_service.dart';
import '../../infrastructure/metrics/recognition_metrics.dart';
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
    RecognitionMetricsStore? metrics,
  })  : camera = camera,
        _gestures = gestures,
        _interactions = interactions,
        _session = session,
        _tts = tts,
        _metrics = metrics;

  final RecognitionMetricsStore? _metrics;
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
  static const confirmDelay = Duration(seconds: 2);
  Completer<GestureOutcome?>? _search;
  Future<void>? _running;
  Timer? _confirmTimer;

  bool _confirming = false;
  bool get confirming => _confirming;

  void _cancelConfirmation() {
    _confirmTimer?.cancel();
    _confirmTimer = null;
    _confirming = false;
  }

  bool get canSwitchCamera =>
      camera.hasMultiple && _phase == GesturePhase.capturing;

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
    _cancelConfirmation();
    _outcome = null;
    _voiceFailed = false;
    if (!camera.isReady) return start();
    await _capture();
  }

  Future<void> _capture() async {
    _outcome = null;
    _set(GesturePhase.capturing);
    if (!testModeAvailable && _gestures.supportsContinuous) {
      return _running = _captureContinuous();
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

  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    _set(GesturePhase.startingCamera);
    _stopSearch();
    await _running;
    await camera.switchCamera();
    if (_disposed || _phase != GesturePhase.startingCamera) return;
    if (!camera.isReady) {
      _set(GesturePhase.cameraIssue);
      return;
    }
    await _capture();
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
    final elapsed = Stopwatch()..start();
    final frameMs = <int>[];
    var busy = false;
    final started = await camera.startFrames((frame) async {
      if (busy || search.isCompleted || profileId == null) return;
      busy = true;
      final watch = Stopwatch()..start();
      try {
        final out =
            await _gestures.addFrame(frame, _enabled, profileId: profileId);
        frameMs.add(watch.elapsedMilliseconds);
        if (out != null && !search.isCompleted) search.complete(out);
      } catch (e) {
        debugPrint('Error al reconocer el fotograma: $e');
      } finally {
        busy = false;
      }
    });
    if (!started) _stopSearch();
    final out = await search.future;
    final responseMs = elapsed.elapsedMilliseconds;
    timer.cancel();
    _search = null;
    await camera.stopFrames();
    if (_disposed || _phase != GesturePhase.capturing) return;
    _recordAttempt(out, responseMs, frameMs);
    await _finish(out);
  }

  void _recordAttempt(GestureOutcome? out, int responseMs, List<int> frameMs) {
    final store = _metrics;
    final profileId = _session.activeProfile?.id;
    if (store == null || profileId == null) return;
    final mean = frameMs.isEmpty
        ? null
        : frameMs.reduce((a, b) => a + b) / frameMs.length;
    final max = frameMs.isEmpty ? null : frameMs.reduce((a, b) => a > b ? a : b);
    unawaited(_saveEvent(store, (session) => RecognitionEvent(
          at: DateTime.now(),
          session: session,
          profileId: profileId,
          type: out == null
              ? RecognitionEventType.notRecognized
              : RecognitionEventType.detected,
          gesture: out?.gesture.recognitionClass,
          confidence: out?.result.confidence?.value,
          responseMs: responseMs,
          meanFrameMs: mean,
          maxFrameMs: max,
          frames: frameMs.length,
        )));
  }

  void _recordTutorDecision(GestureOutcome out, RecognitionEventType type) {
    final store = _metrics;
    final profileId = _session.activeProfile?.id;
    if (store == null || profileId == null) return;
    unawaited(_saveEvent(store, (session) => RecognitionEvent(
          at: DateTime.now(),
          session: session,
          profileId: profileId,
          type: type,
          gesture: out.gesture.recognitionClass,
          confidence: out.result.confidence?.value,
        )));
  }

  Future<void> _saveEvent(RecognitionMetricsStore store,
      RecognitionEvent Function(String session) build) async {
    try {
      await store.record(build(await store.currentSession()));
    } catch (e) {
      debugPrint('No se pudo registrar la métrica: $e');
    }
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
    final latency = out?.result.latencyMs;
    _recordAttempt(out, latency ?? 0, [?latency]);
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
    _voiceFailed = false;
    _confirming = true;
    _set(GesturePhase.recognized);
    _confirmTimer = Timer(confirmDelay, () {
      if (_confirming && _outcome == out) {
        _recordTutorDecision(out, RecognitionEventType.spokenAutomatically);
      }
      _deliver(profile.id!, out);
    });
  }

  Future<void> confirmNow() async {
    final o = _outcome;
    final profile = _session.activeProfile;
    if (!_confirming || o == null || profile == null) return;
    _recordTutorDecision(o, RecognitionEventType.confirmedByTutor);
    await _deliver(profile.id!, o);
  }

  Future<void> rejectOutcome() {
    final o = _outcome;
    if (_confirming && o != null) {
      _recordTutorDecision(o, RecognitionEventType.rejectedByTutor);
    }
    return retry();
  }

  Future<void> _deliver(int profileId, GestureOutcome out) async {
    if (_disposed || !_confirming || _outcome != out) return;
    _cancelConfirmation();
    notifyListeners();
    if (_session.voice?.voiceEnabled ?? true) {
      _voiceFailed = !await _tts.speak(out.intention.message);
      if (!_disposed) notifyListeners();
    }
    await _interactions.recordGesture(
      profileId,
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
    _cancelConfirmation();
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
    _cancelConfirmation();
    _stopSearch();
    await camera.dispose();
    _outcome = null;
    _lastSequence = const GestureSequence([]);
    _phase = GesturePhase.loading;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelConfirmation();
    _stopSearch();
    camera.dispose();
    super.dispose();
  }
}
