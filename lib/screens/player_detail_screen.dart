import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/player.dart';
import '../models/throw_record.dart';
import '../providers/throw_provider.dart';
import '../services/advice_service.dart';

class PlayerDetailScreen extends StatefulWidget {
  final Player player;
  const PlayerDetailScreen({super.key, required this.player});

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ThrowProvider>().loadThrowsForPlayer(widget.player.id);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final throwProv = context.watch<ThrowProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.player.name),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.list), text: 'Lancers'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            Tab(icon: Icon(Icons.lightbulb), text: 'Conseils'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ThrowListTab(throws: throwProv.throws, playerId: widget.player.id),
          _StatsTab(throws: throwProv.throws),
          _AdviceTab(advices: throwProv.advices),
        ],
      ),
    );
  }
}

// ── Onglet lancers ─────────────────────────────────────────────────────────────

class _ThrowListTab extends StatelessWidget {
  const _ThrowListTab({required this.throws, required this.playerId});
  final List<ThrowRecord> throws;
  final String playerId;

  @override
  Widget build(BuildContext context) {
    if (throws.isEmpty) {
      return const Center(
        child: Text(
          'Aucun lancer enregistré.\nUtilisez le calculateur pour en ajouter.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView.builder(
      itemCount: throws.length,
      itemBuilder: (_, i) {
        final t = throws[i];
        return ListTile(
          leading: const Icon(Icons.sports_baseball),
          title: Text(t.pitchType,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${t.ballSpeedKmh.toStringAsFixed(0)} km/h · '
            '${t.rotationSpeedRpm.toStringAsFixed(0)} tr/min · '
            '${t.rotationAngleDeg.toStringAsFixed(0)}°\n'
            '${fmt.format(t.recordedAt)}',
          ),
          isThreeLine: true,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await context.read<ThrowProvider>().removeThrow(t.id, playerId);
            },
          ),
        );
      },
    );
  }
}

// ── Onglet stats ───────────────────────────────────────────────────────────────

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.throws});
  final List<ThrowRecord> throws;

  @override
  Widget build(BuildContext context) {
    if (throws.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text('Aucune donnée à afficher',
                style: TextStyle(color: Colors.white54, fontSize: 16)),
          ],
        ),
      );
    }

    final recent = throws.take(20).toList().reversed.toList();

    final speedSpots = recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.ballSpeedKmh))
        .toList();

    final spinSpots = recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.rotationSpeedRpm))
        .toList();

    // Distribution des types de lancers
    final Map<String, int> distribution = {};
    for (final t in throws) {
      distribution[t.pitchType] = (distribution[t.pitchType] ?? 0) + 1;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vitesse (km/h) — 20 derniers lancers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: speedSpots,
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Rotation (tr/min) — 20 derniers lancers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spinSpots,
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Répartition des lancers',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...distribution.entries.map((e) {
            final pct = (e.value / throws.length * 100).toStringAsFixed(0);
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '(${pct}%)',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / throws.length,
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.value}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white70),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ── Onglet conseils ────────────────────────────────────────────────────────────

class _AdviceTab extends StatelessWidget {
  const _AdviceTab({required this.advices});
  final List<Advice> advices;

  @override
  Widget build(BuildContext context) {
    if (advices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline,
                size: 64,
                color: Colors.white.withOpacity(0.25)),
            const SizedBox(height: 20),
            Text(
              'Aucun conseil pour le moment.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enregistrez au moins 5 lancers pour obtenir une analyse.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: advices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, i) {
        final a = advices[i];
        final color = a.emoji == '⚡' || a.emoji == '🎯'
            ? Colors.orange
            : a.emoji == '🌀' || a.emoji == '✅'
                ? Colors.green
                : a.emoji == '📐' || a.emoji == '↔️'
                    ? Colors.cyan
                    : Colors.blue;
        return Card(
          elevation: 2,
          color: color.withOpacity(0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    a.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        a.detail,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
