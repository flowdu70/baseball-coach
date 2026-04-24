import 'package:flutter/material.dart';
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
        const SnackBar(content: Text('Sélectionnez d\'abord un joueur dans l\'onglet Joueurs')),
      );
      return;
    }
    if (_result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calculez d\'abord un lancer')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lancer enregistré pour ${playerProv.selectedPlayer!.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = context.watch<PlayerProvider>().selectedPlayer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculateur de lancer'),
        actions: [
          if (player != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                avatar: const Icon(Icons.person, size: 16),
                label: Text(player.name),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Sliders ──────────────────────────────────────────────────────
            _SliderCard(
              label: 'Vitesse de la balle',
              value: _speed,
              unit: 'km/h',
              min: 60,
              max: 165,
              divisions: 105,
              color: Colors.orange,
              onChanged: (v) => setState(() => _speed = v),
            ),
            const SizedBox(height: 12),
            _SliderCard(
              label: 'Vitesse de rotation',
              value: _spin,
              unit: 'tr/min',
              min: 500,
              max: 3500,
              divisions: 60,
              color: Colors.blue,
              onChanged: (v) => setState(() => _spin = v),
            ),
            const SizedBox(height: 12),
            _SliderCard(
              label: 'Angle de rotation',
              value: _angle,
              unit: '°',
              min: 0,
              max: 90,
              divisions: 90,
              color: Colors.green,
              onChanged: (v) => setState(() => _angle = v),
            ),
            const SizedBox(height: 20),

            // ── Boutons ───────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _calculate,
                    icon: const Icon(Icons.calculate),
                    label: const Text('Calculer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saveThrow,
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer'),
                  ),
                ),
              ],
            ),

            // ── Résultat ──────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!.pitchType,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatRow(
                        icon: Icons.swap_horiz,
                        label: 'Déviation latérale',
                        value: '${_result!.curveEstimateCm.abs().toStringAsFixed(1)} cm',
                        color: Colors.blue,
                      ),
                      _StatRow(
                        icon: Icons.arrow_downward,
                        label: 'Chute verticale',
                        value: '${_result!.dropEstimateCm.abs().toStringAsFixed(1)} cm',
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: CustomPaint(
                          painter: TrajectoryPainter(
                            curveCm: _result!.curveEstimateCm,
                            dropCm: _result!.dropEstimateCm,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
