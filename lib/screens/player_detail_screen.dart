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
        bottom: TabBar(
          controller: _tabs,
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
      return const Center(child: Text('Pas encore de données'));
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
          const SizedBox(height: 8),
          ...distribution.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.key)),
                    Text('${e.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: LinearProgressIndicator(
                        value: e.value / throws.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              )),
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
      return const Center(
          child: Text('Enregistrez des lancers pour obtenir des conseils'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: advices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final a = advices[i];
        return Card(
          child: ListTile(
            leading: Text(a.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(a.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(a.detail),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
