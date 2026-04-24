import 'dart:math';

/// Résultat du calcul physique d'un lancer
class PitchResult {
  final String pitchType;
  final double curveEstimateCm;
  final double dropEstimateCm;
  final String description;

  const PitchResult({
    required this.pitchType,
    required this.curveEstimateCm,
    required this.dropEstimateCm,
    required this.description,
  });
}

/// Calcul basé sur l'effet Magnus
/// Paramètres :
///   rotationAngleDeg : angle d'inclinaison de l'axe de rotation (0° = topspin pur, 90° = sidespin pur)
///   rotationSpeedRpm : vitesse de rotation en tours/min
///   ballSpeedKmh     : vitesse de la balle en km/h
class PhysicsService {
  static const double _ballMassKg = 0.145;       // masse d'une balle de baseball
  static const double _ballRadiusM = 0.037;      // rayon ≈ 3,7 cm
  static const double _airDensity = 1.225;       // kg/m³
  static const double _distancePlate = 18.44;    // distance du monticule au marbre (m)
  static const double _magnusCoeff = 1.0;        // coefficient ajustable

  static PitchResult calculate({
    required double rotationAngleDeg,
    required double rotationSpeedRpm,
    required double ballSpeedKmh,
  }) {
    final double vMs = ballSpeedKmh / 3.6;
    final double omega = rotationSpeedRpm * 2 * pi / 60; // rad/s

    // Surface de la balle
    final double area = pi * _ballRadiusM * _ballRadiusM;

    // Coefficient de portance Magnus: Cl = (omega * r) / v
    final double spinParameter = (omega * _ballRadiusM) / vMs;
    final double cl = _magnusCoeff * spinParameter;

    // Force Magnus totale
    final double magnusForce = 0.5 * _airDensity * area * cl * vMs * vMs;

    // Temps de vol estimé
    final double flightTime = _distancePlate / vMs;

    // Décomposition selon l'angle :
    // 0° → force vers le bas/haut (topspin/backspin)
    // 90° → force latérale (sidespin)
    final double angleRad = rotationAngleDeg * pi / 180;
    final double lateralForce = magnusForce * sin(angleRad);
    final double verticalForce = magnusForce * cos(angleRad);

    // Accélération résultante
    final double latAccel = lateralForce / _ballMassKg;
    final double vertAccel = verticalForce / _ballMassKg;

    // Déviation = ½ * a * t²
    final double curveCm = 0.5 * latAccel * flightTime * flightTime * 100;
    final double dropCm = 0.5 * vertAccel * flightTime * flightTime * 100;

    final String type = _classifyPitch(
      rotationAngleDeg: rotationAngleDeg,
      rotationSpeedRpm: rotationSpeedRpm,
      ballSpeedKmh: ballSpeedKmh,
    );

    return PitchResult(
      pitchType: type,
      curveEstimateCm: curveCm,
      dropEstimateCm: dropCm,
      description: _describe(type, curveCm, dropCm),
    );
  }

  static String _classifyPitch({
    required double rotationAngleDeg,
    required double rotationSpeedRpm,
    required double ballSpeedKmh,
  }) {
    final bool fast = ballSpeedKmh >= 120;
    final bool highSpin = rotationSpeedRpm >= 2000;
    final bool lateral = rotationAngleDeg > 45;
    final bool topspin = rotationAngleDeg < 20;

    if (fast && highSpin && topspin) return 'Fastball (4-coutures)';
    if (fast && highSpin && lateral) return 'Slider';
    if (!fast && highSpin && lateral) return 'Curveball';
    if (fast && !highSpin) return 'Changeup';
    if (lateral && !highSpin) return 'Sinker';
    if (highSpin && !lateral && !topspin) return 'Cutter';
    return 'Lancer mixte';
  }

  static String _describe(String type, double curveCm, double dropCm) {
    final String lateralDir = curveCm >= 0 ? 'droite' : 'gauche';
    final String vertDir = dropCm >= 0 ? 'bas' : 'haut';
    return '$type — déviation latérale : ${curveCm.abs().toStringAsFixed(1)} cm vers la $lateralDir'
        ', chute : ${dropCm.abs().toStringAsFixed(1)} cm vers le $vertDir';
  }
}
