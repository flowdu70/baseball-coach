import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// FPS cible détecté pour l'appareil
class CameraCapability {
  final double fps;
  final ResolutionPreset preset;
  final bool isSlowMotion;
  final String label;

  const CameraCapability({
    required this.fps,
    required this.preset,
    required this.isSlowMotion,
    required this.label,
  });
}

class CameraCapabilityService {
  static const _channel = MethodChannel('com.example.baseball_coach/camera');

  /// Détecte automatiquement le FPS le plus élevé disponible
  /// Essaie dans l'ordre : 240fps, 120fps, 60fps, 30fps
  static Future<CameraCapability> detectBestCapability(
      CameraDescription camera) async {
    // Sur iOS et Android récents, on tente de lire les FPS supportés
    // via un channel natif si disponible, sinon on déduit depuis le device
    try {
      final supported = await _getSupportedFpsNative();
      if (supported != null && supported.isNotEmpty) {
        return _capabilityFromFps(supported.reduce((a, b) => a > b ? a : b));
      }
    } catch (_) {
      // channel natif absent → heuristique device
    }

    return _heuristicCapability();
  }

  /// Tente d'interroger le channel natif pour les FPS supportés
  static Future<List<double>?> _getSupportedFpsNative() async {
    try {
      final result =
          await _channel.invokeListMethod<double>('getSupportedFps');
      return result;
    } on MissingPluginException {
      return null;
    }
  }

  /// Heuristique basée sur l'OS et la génération du device
  static CameraCapability _heuristicCapability() {
    if (Platform.isIOS) {
      // iPhone 6s+ supporte 240fps, iPhone 5s+ 120fps
      // On essaie 240 en premier, le plugin lèvera une exception si non dispo
      return const CameraCapability(
        fps: 240,
        preset: ResolutionPreset.high,
        isSlowMotion: true,
        label: 'Ralenti 240 fps (iPhone)',
      );
    }

    if (Platform.isAndroid) {
      // Flagships récents (Pixel 6+, Samsung S21+) : 240fps
      // Mid-range : 120fps
      // On commence à 120 car 240 Android est souvent limité à 720p
      return const CameraCapability(
        fps: 120,
        preset: ResolutionPreset.medium,
        isSlowMotion: true,
        label: 'Ralenti 120 fps',
      );
    }

    return const CameraCapability(
      fps: 60,
      preset: ResolutionPreset.high,
      isSlowMotion: false,
      label: '60 fps',
    );
  }

  static CameraCapability _capabilityFromFps(double fps) {
    if (fps >= 240) {
      return CameraCapability(
        fps: 240,
        preset: ResolutionPreset.high,
        isSlowMotion: true,
        label: 'Ralenti 240 fps',
      );
    } else if (fps >= 120) {
      return CameraCapability(
        fps: 120,
        preset: ResolutionPreset.high,
        isSlowMotion: true,
        label: 'Ralenti 120 fps',
      );
    } else if (fps >= 60) {
      return CameraCapability(
        fps: 60,
        preset: ResolutionPreset.high,
        isSlowMotion: false,
        label: '60 fps',
      );
    } else {
      return CameraCapability(
        fps: 30,
        preset: ResolutionPreset.high,
        isSlowMotion: false,
        label: '30 fps (standard)',
      );
    }
  }

  /// Crée un CameraController configuré pour le FPS cible
  /// Descend automatiquement si le FPS demandé échoue
  static Future<({CameraController controller, CameraCapability capability})>
      buildController(CameraDescription camera, CameraCapability target) async {
    final candidates = _candidatesBelow(target.fps);

    for (final cap in candidates) {
      try {
        final ctrl = CameraController(
          camera,
          cap.preset,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
          fps: cap.fps.toInt(),          // camera 0.10.6+ accepte fps
        );
        await ctrl.initialize();
        return (controller: ctrl, capability: cap);
      } catch (_) {
        // Ce FPS n'est pas supporté → on essaie le suivant
        continue;
      }
    }

    // Fallback absolu : 30fps high
    final ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await ctrl.initialize();
    return (
      controller: ctrl,
      capability: const CameraCapability(
        fps: 30,
        preset: ResolutionPreset.high,
        isSlowMotion: false,
        label: '30 fps (fallback)',
      ),
    );
  }

  static List<CameraCapability> _candidatesBelow(double maxFps) {
    final all = [
      const CameraCapability(
          fps: 240,
          preset: ResolutionPreset.medium,
          isSlowMotion: true,
          label: 'Ralenti 240 fps'),
      const CameraCapability(
          fps: 120,
          preset: ResolutionPreset.high,
          isSlowMotion: true,
          label: 'Ralenti 120 fps'),
      const CameraCapability(
          fps: 60,
          preset: ResolutionPreset.high,
          isSlowMotion: false,
          label: '60 fps'),
      const CameraCapability(
          fps: 30,
          preset: ResolutionPreset.high,
          isSlowMotion: false,
          label: '30 fps'),
    ];
    return all.where((c) => c.fps <= maxFps).toList();
  }
}
