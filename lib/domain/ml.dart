library;

import 'dart:typed_data';

import 'shared.dart';

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

class GestureSequence {
  final List<GestureFrame> frames;
  const GestureSequence(this.frames);
  bool get isEmpty => frames.isEmpty;
}

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

abstract interface class GestureRecognitionService {
  RecognizerInfo get info;
  bool get isLoaded;
  Future<void> load();

  Future<GestureRecognitionResult> recognize(
    GestureSequence sequence, {
    required List<String> candidateClasses,
  });

  Future<void> dispose();
}

abstract interface class ContinuousGestureRecognition {
  void reset();

  Future<GestureRecognitionResult?> addFrame(
    GestureFrame frame, {
    required List<String> candidateClasses,
  });
}

abstract interface class TestOutcomeRecognition {
  void setTestOutcome(String? recognitionClass);
}
