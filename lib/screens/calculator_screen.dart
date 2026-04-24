import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/physics_service.dart';
import '../models/throw_record.dart';
import '../providers/throw_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/trajectory_painter.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  double _angle = 45;
  double _spin = 2200;
  double _speed = 120;
  PitchResult? _result;

  void _calculate() {
    HapticFeedback.lightImpact();
    setState(() {
      _result = PhysicsService.calculate(
        rotationAngleDeg: _angle,
        rotationSpeedRpm: _spin,
        ballSpeedKmh: _speed,
      );
    });
  }

  Future<void> _saveThrow() async {
    final playerProv = context.read<PlayerProvider>();
    if (playerProv.selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sélectionnez un joueur dans l’onglet Joueurs'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Calculez d’abord un lancer'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    final record = ThrowRecord(
      id: const Uuid().v4(),
      playerId: playerProv.selectedPlayer!.id,
      rotationAngleDeg: _angle,
      rotationSpeedRpm: _spin,
      ballSpeedKmh: _speed,
      pitchType: _result!.pitchType,
      curveEstimateCm: _result!.curveEstimateCm,
      dropEstimateCm: _result!.dropEstimateCm,
      recordedAt: DateTime.now(),
    );
    await context.read<ThrowProvider>().addThrow(record);
    if (mounted) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Enregistré pour ${playerProv.selectedPlayer!.name}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerProvider>().selectedPlayer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculateur'),
        elevation: 0,
        actions: [
          if (player != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(player.name),
                backgroundColor: theme.colorScheme.secondaryContainer,
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── Sliders ──────────────────────────────
              _SliderCard(
                label: '⚡ Vitesse de la balle',
                value: _speed,
                unit: 'km/h',
                min: 60,
                max: 165,
                divisions: 105,
                color: theme.colorScheme.secondary,
                onChanged: (v) => setState(() => _speed = v),
              ),
              const SizedBox(height: 16),
              _SliderCard(
                label: '🌀 Vitesse de rotation',
                value: _spin,
                unit: 'tr/min',
                min: 500,
                max: 3500,
                divisions: 60,
                color: theme.colorScheme.primary,
                onChanged: (v) => setState(() => _spin = v),
              ),
              const SizedBox(height: 16),
              _SliderCard(
                label: '📐 Angle de rotation',
                value: _angle,
                unit: '°',
                min: 0,
                max: 90,
                divisions: 90,
                color: Colors.greenAccent,
                onChanged: (v) => setState(() => _angle = v),
              ),

              const SizedBox(height: 28),

              // ── Boutons ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.analytics),
                      label: const Text('Calculer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondary,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveThrow,
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),

              // ── Résultat ───────────────────────────────
              if (_result != null) ...[
                const SizedBox(height: 24),
                _ResultCard(theme: theme, result: _result!),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ThemeData theme;
  final PitchResult result;

  const _ResultCard({required this.theme, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.3),
            theme.colorScheme.secondaryContainer.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Type détecté',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white60,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result.pitchType,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.speed,
                    label: 'Vitesse',
                    value: '${result.curveEstimateCm.abs().toStringAsFixed(1)} cm',
                    color: Colors.orange,
                    iconBg: Colors.orange.withOpacity(0.15),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.arrow_downward,
                    label: 'Chute',
                    value: '${result.dropEstimateCm.abs().toStringAsFixed(1)} cm',
                    color: Colors.red,
                    iconBg: Colors.red.withOpacity(0.15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: TrajectoryPainter(
                  curveCm: result.curveEstimateCm,
                  dropCm: result.dropEstimateCm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color iconBg;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white60, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
                fontSize: 18,
              )),
        ],
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${value.toStringAsFixed(0)} $unit',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: color),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
