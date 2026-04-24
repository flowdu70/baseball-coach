import '../models/throw_record.dart';

class Advice {
  final String title;
  final String detail;
  final String emoji;

  const Advice({required this.title, required this.detail, required this.emoji});
}

/// Moteur de conseils basé sur des règles
class AdviceService {
  static List<Advice> generateAdvice(List<ThrowRecord> throws) {
    if (throws.isEmpty) return [];

    final List<Advice> advices = [];

    // Moyennes sur les 10 derniers lancers
    final recent = throws.take(10).toList();
    final avgSpeed =
        recent.map((t) => t.ballSpeedKmh).reduce((a, b) => a + b) / recent.length;
    final avgSpin =
        recent.map((t) => t.rotationSpeedRpm).reduce((a, b) => a + b) / recent.length;
    final avgAngle =
        recent.map((t) => t.rotationAngleDeg).reduce((a, b) => a + b) / recent.length;

    // Conseil vitesse
    if (avgSpeed < 100) {
      advices.add(const Advice(
        emoji: '⚡',
        title: 'Vitesse insuffisante',
        detail:
            'Moyenne sous 100 km/h. Travaillez la mécanique du bras et le transfert du poids pour gagner en vélocité.',
      ));
    } else if (avgSpeed > 145) {
      advices.add(const Advice(
        emoji: '🔥',
        title: 'Excellente vitesse',
        detail:
            'Vous maintenez une vitesse élite. Concentrez-vous sur la précision et la variation.',
      ));
    }

    // Conseil rotation
    if (avgSpin < 1500) {
      advices.add(const Advice(
        emoji: '🌀',
        title: 'Rotation trop faible',
        detail:
            'Moins de 1500 tr/min — l\'effet sur la balle est limité. Travaillez le placement des doigts et le snap du poignet.',
      ));
    } else if (avgSpin > 2800) {
      advices.add(const Advice(
        emoji: '✅',
        title: 'Spin élite',
        detail:
            'Au-dessus de 2800 tr/min. Vous avez les outils pour des lancers très déviants. Maîtrisez l\'angle pour maximiser l\'effet.',
      ));
    }

    // Conseil angle
    if (avgAngle < 10) {
      advices.add(const Advice(
        emoji: '📐',
        title: 'Axe trop plat (topspin)',
        detail:
            'Angle < 10° — vos lancers chutent mais dévient peu latéralement. Idéal pour le sinker, mais variez pour surprendre.',
      ));
    } else if (avgAngle > 80) {
      advices.add(const Advice(
        emoji: '↔️',
        title: 'Axe très latéral',
        detail:
            'Angle > 80° — fort sidespin. Vous créez un slider naturel, mais pensez à varier l\'axe pour casser la lecture du batteur.',
      ));
    }

    // Consistance
    final speedVariance = _variance(recent.map((t) => t.ballSpeedKmh).toList());
    if (speedVariance > 100) {
      advices.add(const Advice(
        emoji: '🎯',
        title: 'Manque de consistance',
        detail:
            'Grande variabilité de vitesse d\'un lancer à l\'autre. Travaillez la répétabilité mécanique de votre geste.',
      ));
    }

    if (advices.isEmpty) {
      advices.add(const Advice(
        emoji: '👌',
        title: 'Bonne régularité',
        detail:
            'Vos paramètres récents sont dans les normes. Continuez à accumuler des données pour un diagnostic plus précis.',
      ));
    }

    return advices;
  }

  static double _variance(List<double> values) {
    if (values.length < 2) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSq =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    return sumSq / values.length;
  }
}
