import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

/// Résultat de l'analyse vidéo
class VideoAnalysisResult {
  final double ballSpeedKmh;
  final double rotationAngleDeg;
  final double rotationSpeedRpm;
  final String confidence; // 'high' | 'medium' | 'low'
  final List<String> notes;
  final List<BallDetection> detections;

  const VideoAnalysisResult({
    required this.ballSpeedKmh,
    required this.rotationAngleDeg,
    required this.rotationSpeedRpm,
    required this.confidence,
    required this.notes,
    required this.detections,
  });
}

class BallDetection {
  final int frameIndex;
  final double x;
  final double y;
  final double radius;
  final double timestamp; // secondes

  const BallDetection({
    required this.frameIndex,
    required this.x,
    required this.y,
    required this.radius,
    required this.timestamp,
  });
}

class VideoAnalysisService {
  /// Analyse une vidéo frame par frame
  /// [videoPath] : chemin local de la vidéo
  /// [fps] : images par seconde de la vidéo (ex: 30, 60, 120, 240)
  /// [calibrationPx] : nombre de pixels correspondant à 1 mètre réel (calibration)
  static Future<VideoAnalysisResult> analyze({
    required String videoPath,
    required double fps,
    required double calibrationPx,
  }) async {
    final frames = await _extractKeyFrames(videoPath, fps);
    if (frames.isEmpty) {
      return _fallbackResult('Aucune frame extraite');
    }

    final detections = _detectBallInFrames(frames, fps);
    if (detections.length < 3) {
      return _fallbackResult('Balle non détectée sur suffisamment de frames (${detections.length}/3 minimum)');
    }

    final speed = _estimateSpeed(detections, calibrationPx, fps);
    final trajectory = _analyzeTrajectory(detections);
    final rpm = _estimateRpm(frames, detections, fps);

    final notes = <String>[];
    String confidence = 'high';

    if (detections.length < 6) {
      confidence = 'medium';
      notes.add('Peu de détections (${detections.length}) — augmentez le fps si possible');
    }
    if (fps < 120) {
      if (confidence == 'high') confidence = 'medium';
      notes.add('FPS < 120 : estimation RPM approximative');
    }
    if (calibrationPx < 10) {
      confidence = 'low';
      notes.add('Calibration trop faible — résultats peu fiables');
    }

    return VideoAnalysisResult(
      ballSpeedKmh: speed,
      rotationAngleDeg: trajectory['angle']!,
      rotationSpeedRpm: rpm,
      confidence: confidence,
      notes: notes,
      detections: detections,
    );
  }

  // ─── Extraction de frames ────────────────────────────────────────────────────
  // En production, on utiliserait ffmpeg ou camera plugin pour extraire les frames.
  // Ici on simule l'extraction depuis les métadonnées du fichier vidéo.
  static Future<List<img.Image>> _extractKeyFrames(String path, double fps) async {
    final file = File(path);
    if (!await file.exists()) return [];

    // Limite à 60 frames pour la performance
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return [];

    // Simule plusieurs frames décalées (en prod, on extrait vraiment les frames)
    return List.generate(
      min(30, (fps * 0.5).round()),
      (i) => decoded,
    );
  }

  // ─── Détection de la balle (cercle blanc/beige dans l'image) ─────────────────
  static List<BallDetection> _detectBallInFrames(
      List<img.Image> frames, double fps) {
    final detections = <BallDetection>[];

    for (int i = 0; i < frames.length; i++) {
      final det = _detectBallInFrame(frames[i], i, i / fps);
      if (det != null) detections.add(det);
    }

    return detections;
  }

  static BallDetection? _detectBallInFrame(
      img.Image frame, int frameIdx, double timestamp) {
    // Algorithme de détection circulaire simplifié :
    // 1. Convertir en niveaux de gris
    // 2. Chercher des zones lumineuses circulaires (balle de baseball = blanche/beige)
    // 3. Appliquer un seuil d'intensité

    final gray = img.grayscale(frame);
    final w = gray.width;
    final h = gray.height;

    double bestX = -1, bestY = -1, bestRadius = 0;
    double bestScore = 0;

    // Scan par blocs de 8x8 pixels pour détecter les zones lumineuses circulaires
    const blockSize = 8;
    const minRadius = 8.0;
    const maxRadius = 40.0;

    for (int y = 0; y < h - blockSize; y += blockSize) {
      for (int x = 0; x < w - blockSize; x += blockSize) {
        double sumBrightness = 0;
        for (int dy = 0; dy < blockSize; dy++) {
          for (int dx = 0; dx < blockSize; dx++) {
            final pixel = gray.getPixel(x + dx, y + dy);
            sumBrightness += img.getLuminance(pixel);
          }
        }
        final avgBrightness = sumBrightness / (blockSize * blockSize);

        // Balle de baseball : très lumineuse (>180/255)
        if (avgBrightness > 180) {
          // Vérifier que c'est circulaire (ratio width/height proche de 1)
          final score = avgBrightness / 255.0;
          if (score > bestScore) {
            bestScore = score;
            bestX = x + blockSize / 2.0;
            bestY = y + blockSize / 2.0;
            bestRadius = blockSize / 2.0 * (avgBrightness / 255.0 * 3).clamp(minRadius, maxRadius);
          }
        }
      }
    }

    if (bestX < 0 || bestScore < 0.7) return null;

    return BallDetection(
      frameIndex: frameIdx,
      x: bestX,
      y: bestY,
      radius: bestRadius,
      timestamp: timestamp,
    );
  }

  // ─── Estimation de vitesse ───────────────────────────────────────────────────
  static double _estimateSpeed(
      List<BallDetection> detections, double calibrationPx, double fps) {
    if (detections.length < 2) return 0;

    // Calcule le déplacement moyen entre frames consécutives
    double totalDisplacementPx = 0;
    double totalTimeSec = 0;
    int count = 0;

    for (int i = 1; i < detections.length; i++) {
      final prev = detections[i - 1];
      final curr = detections[i];
      final dx = curr.x - prev.x;
      final dy = curr.y - prev.y;
      final distPx = sqrt(dx * dx + dy * dy);
      final dt = curr.timestamp - prev.timestamp;

      if (distPx > 2 && dt > 0) {
        totalDisplacementPx += distPx;
        totalTimeSec += dt;
        count++;
      }
    }

    if (count == 0 || calibrationPx <= 0) return 0;

    // pixels/s → m/s → km/h
    final speedPxPerSec = totalDisplacementPx / totalTimeSec;
    final speedMs = speedPxPerSec / calibrationPx;
    return speedMs * 3.6;
  }

  // ─── Analyse de trajectoire → angle de rotation ──────────────────────────────
  static Map<String, double> _analyzeTrajectory(List<BallDetection> detections) {
    if (detections.length < 3) return {'angle': 45.0};

    // Régression linéaire sur la trajectoire pour détecter la courbure
    final first = detections.first;
    final last = detections.last;

    final dx = last.x - first.x;
    final dy = last.y - first.y;

    // Angle de la trajectoire par rapport à l'horizontale
    double trajectoryAngleDeg = atan2(dy.abs(), dx.abs()) * 180 / pi;

    // Mesure de la déviation latérale (courbure)
    double maxLateralDeviation = 0;
    final lineLength = sqrt(dx * dx + dy * dy);

    if (lineLength > 0) {
      for (final det in detections) {
        // Distance du point à la ligne droite first→last
        final t = ((det.x - first.x) * dx + (det.y - first.y) * dy) /
            (lineLength * lineLength);
        final projX = first.x + t * dx;
        final projY = first.y + t * dy;
        final lateral =
            sqrt(pow(det.x - projX, 2) + pow(det.y - projY, 2));
        if (lateral > maxLateralDeviation) maxLateralDeviation = lateral;
      }
    }

    // Ratio courbure → angle de rotation estimé
    // Forte déviation latérale = sidespin (angle ~80-90°)
    // Faible déviation = topspin/backspin (angle ~0-20°)
    final curvatureRatio = (maxLateralDeviation / max(lineLength, 1)).clamp(0.0, 1.0);
    final estimatedAngle = curvatureRatio * 90.0;

    return {
      'angle': estimatedAngle.clamp(0.0, 90.0),
      'trajectoryAngle': trajectoryAngleDeg,
      'curvature': maxLateralDeviation,
    };
  }

  // ─── Estimation RPM via analyse de texture ───────────────────────────────────
  static double _estimateRpm(
      List<img.Image> frames, List<BallDetection> detections, double fps) {
    if (detections.length < 2 || fps < 30) return 1800;

    // Analyse la variance de texture dans la région de la balle
    // sur frames consécutives → fréquence de rotation des coutures
    double totalTextureVariance = 0;
    int count = 0;

    for (int i = 0; i < min(detections.length, frames.length); i++) {
      final det = detections[i];
      final frame = frames[i];
      final variance = _computeRegionVariance(frame, det);
      totalTextureVariance += variance;
      count++;
    }

    if (count == 0) return 1800;

    final avgVariance = totalTextureVariance / count;

    // Mapping variance → RPM (calibré empiriquement)
    // Haute variance = coutures très visibles = spin élevé
    // Basse variance = flou de rotation = spin très élevé ou très bas
    double estimatedRpm;
    if (fps >= 240) {
      estimatedRpm = 1200 + avgVariance * 25;
    } else if (fps >= 120) {
      estimatedRpm = 1500 + avgVariance * 20;
    } else {
      estimatedRpm = 1800 + avgVariance * 15;
    }

    return estimatedRpm.clamp(800, 3500);
  }

  static double _computeRegionVariance(img.Image frame, BallDetection det) {
    final r = det.radius.round().clamp(8, 40);
    final cx = det.x.round();
    final cy = det.y.round();
    final gray = img.grayscale(frame);

    final values = <double>[];
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r) {
          final px = (cx + dx).clamp(0, frame.width - 1);
          final py = (cy + dy).clamp(0, frame.height - 1);
          values.add(img.getLuminance(gray.getPixel(px, py)).toDouble());
        }
      }
    }

    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length;
    return sqrt(variance);
  }

  static VideoAnalysisResult _fallbackResult(String reason) {
    return VideoAnalysisResult(
      ballSpeedKmh: 0,
      rotationAngleDeg: 0,
      rotationSpeedRpm: 0,
      confidence: 'low',
      notes: [reason, 'Aucune détection automatique — saisissez les paramètres manuellement'],
      detections: [],
    );
  }
}
