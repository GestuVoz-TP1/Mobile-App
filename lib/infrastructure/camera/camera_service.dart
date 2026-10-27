import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../../domain/ml.dart';

/// Problema que impide usar la camara (HU002, criterio 2).
enum CameraIssue { none, noCamera, permissionDenied, failure }

extension CameraIssueX on CameraIssue {
  /// Que debe solucionarse antes de usar la modalidad de gestos.
  String get howToFix => switch (this) {
        CameraIssue.none => '',
        CameraIssue.noCamera =>
          'Este dispositivo no tiene una cámara disponible. La comunicación '
              'mediante gestos necesita una cámara.',
        CameraIssue.permissionDenied =>
          'El permiso de cámara fue denegado. Actívalo en Ajustes del teléfono '
              '> Aplicaciones > GestuVoz > Permisos > Cámara y vuelve a intentarlo.',
        CameraIssue.failure =>
          'No se pudo iniciar la cámara. Cierra otras aplicaciones que la estén '
              'usando y vuelve a intentarlo.',
      };
}

/// Envuelve el plugin `camera`. Usa la camara frontal (el nino mira la
/// pantalla) y entrega SECUENCIAS de fotogramas en memoria para el
/// reconocimiento de gestos (RF-01). Ninguna imagen se guarda en disco
/// (RNF-02).
class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  bool _initializing = false;

  bool get isAvailable => _cameras.isNotEmpty;
  bool get hasMultiple => _cameras.length > 1;
  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get isFront =>
      _cameras.isNotEmpty &&
      _cameras[_index].lensDirection == CameraLensDirection.front;
  CameraController? get controller => _controller;

  CameraIssue issue = CameraIssue.none;

  Future<void> discover() async {
    try {
      _cameras = await availableCameras();
      final front = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _index = front >= 0 ? front : 0;
      issue = _cameras.isEmpty ? CameraIssue.noCamera : CameraIssue.none;
    } on CameraException catch (e) {
      _cameras = const [];
      issue = _classify(e);
    } catch (_) {
      _cameras = const [];
      issue = CameraIssue.failure;
    }
  }

  /// Inicia la camara. Al inicializar, el plugin solicita el permiso de
  /// camara si aun no se otorgo.
  Future<void> start() async {
    if (_initializing) return;
    if (_cameras.isEmpty) {
      if (issue == CameraIssue.none) issue = CameraIssue.noCamera;
      return;
    }
    _initializing = true;
    try {
      await _controller?.dispose();
      final c = CameraController(
        _cameras[_index],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = c;
      await c.initialize();
      issue = CameraIssue.none;
    } on CameraException catch (e) {
      issue = _classify(e);
      _controller = null;
    } catch (_) {
      issue = CameraIssue.failure;
      _controller = null;
    } finally {
      _initializing = false;
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _index = (_index + 1) % _cameras.length;
    await start();
  }

  /// Captura una secuencia de [frameCount] fotogramas durante como maximo
  /// [maxDuration]. Los fotogramas quedan solo en memoria.
  Future<GestureSequence> captureSequence({
    int frameCount = 16,
    Duration maxDuration = const Duration(seconds: 3),
  }) async {
    final frames = <GestureFrame>[];
    final done = Completer<void>();
    final started = await startFrames((f) {
      if (done.isCompleted) return;
      frames.add(f);
      if (frames.length >= frameCount) done.complete();
    }, step: maxDuration ~/ frameCount);
    if (!started) return const GestureSequence([]);
    await done.future
        .timeout(maxDuration + const Duration(seconds: 1), onTimeout: () {});
    await stopFrames();
    return GestureSequence(List.unmodifiable(frames));
  }

  /// Entrega un fotograma cada [step] (como maximo) hasta [stopFrames].
  /// Los fotogramas quedan solo en memoria. Devuelve false si la camara no
  /// esta lista.
  Future<bool> startFrames(
    void Function(GestureFrame frame) onFrame, {
    Duration step = const Duration(milliseconds: 150),
  }) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return false;
    var lastAt = DateTime.fromMillisecondsSinceEpoch(0);
    final rotation = _cameras[_index].sensorOrientation;
    try {
      await c.startImageStream((CameraImage img) {
        final now = DateTime.now();
        if (now.difference(lastAt) < step) return;
        lastAt = now;
        // Planos YUV copiados en memoria; el reconocedor hace su propio
        // preprocesamiento (OB2, 8.2).
        final p = img.planes;
        final color = p.length >= 3;
        onFrame(GestureFrame(
          bytes: Uint8List.fromList(p[0].bytes),
          width: img.width,
          height: img.height,
          capturedAt: now,
          uPlane: color ? Uint8List.fromList(p[1].bytes) : null,
          vPlane: color ? Uint8List.fromList(p[2].bytes) : null,
          yRowStride: p[0].bytesPerRow,
          uvRowStride: color ? p[1].bytesPerRow : 0,
          uvPixelStride: color ? (p[1].bytesPerPixel ?? 1) : 1,
          rotation: rotation,
        ));
      });
      return true;
    } catch (e) {
      debugPrint('No se pudo iniciar la captura: $e');
      return false;
    }
  }

  Future<void> stopFrames() async {
    try {
      final c = _controller;
      if (c != null && c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  static CameraIssue _classify(CameraException e) {
    final code = e.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('restricted') ||
        code.contains('permission')) {
      return CameraIssue.permissionDenied;
    }
    return CameraIssue.failure;
  }
}
