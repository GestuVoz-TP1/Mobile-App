library;

import 'dart:typed_data';

import 'shared.dart';

/// Camera image, in its native format, analyzed by the recognizer.
class GestureFrame {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime capturedAt;

  final Uint8List? uPlane;
  final Uint8List? vPlane;

  final int yRowStride;
  final int uvRowStride;
  final int uvPixelStride;

  final int rotation;

  const GestureFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.capturedAt,
    this.uPlane,
    this.vPlane,
    this.yRowStride = 0,
    this.uvRowStride = 0,
    this.uvPixelStride = 1,
    this.rotation = 0,
  });

  bool get hasColor => uPlane != null && vPlane != null;
}

/// Consecutive frames analyzed together in a single recognition.
class GestureSequence {
  final List<GestureFrame> frames;
  const GestureSequence(this.frames);
  bool get isEmpty => frames.isEmpty;
}

/// Description of the active recognizer shown in the capture screen.
class RecognizerInfo {
  final String name;

  final bool isRealModel;
  final String notes;

  const RecognizerInfo({
    required this.name,
    required this.isRealModel,
    this.notes = '',
  });
}

/// Outcome of a recognition attempt and the time it took.
class GestureRecognitionResult {
  final String? recognitionClass;

  final Confidence? confidence;

  final int latencyMs;

  const GestureRecognitionResult({
    required this.recognitionClass,
    this.confidence,
    this.latencyMs = 0,
  });

  const GestureRecognitionResult.notRecognized({this.latencyMs = 0})
      : recognitionClass = null,
        confidence = null;

  bool get recognized => recognitionClass != null;
}

/// Recognizer that classifies a sequence of frames into one gesture.
abstract interface class GestureRecognitionService {
  RecognizerInfo get info;
  bool get isLoaded;
  Future<void> load();

  /// Recognizes the gesture of [sequence], restricted to [candidateClasses]
  /// so that gestures disabled for the profile are never reported.
  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  });

  Future<void> dispose();
}

/// Recognizer that receives frames one by one while the camera is running.
abstract interface class ContinuousGestureRecognition {
  void reset();

  /// Adds [frame] to the sliding window and returns a result only when a gesture
  /// has been accepted; returns null while more frames are needed.
  Future<GestureRecognitionResult?> addFrame(
    GestureFrame frame, {
    required List<String> candidateClasses,
  });
}

/// Recognizer whose result can be forced, used in automated tests and demos.
abstract interface class TestOutcomeRecognition {
  void setTestOutcome(String? recognitionClass);
}
