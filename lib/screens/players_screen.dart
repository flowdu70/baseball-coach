import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/player.dart';
import '../providers/player_provider.dart';
import 'player_detail_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayerProvider>().loadPlayers();
    });
  }

  void _showAddPlayerDialog() {
    final nameCtrl = TextEditingController();
    final posCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau joueur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: posCtrl,
              decoration: const InputDecoration(
                labelText: 'Position (ex: Pitcher)',
                prefixIcon: Icon(Icons.sports_baseball),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final player = Player(
                id: const Uuid().v4(),
                name: nameCtrl.text.trim(),
                position: posCtrl.text.trim().isEmpty
                    ? 'Joueur'
                    : posCtrl.text.trim(),
                createdAt: DateTime.now(),
              );
              await context.read<PlayerProvider>().addPlayer(player);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProv = context.watch<PlayerProvider>();
    final selected = playerProv.selectedPlayer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joueurs'),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPlayerDialog,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
        elevation: 4,
      ),
      body: playerProv.players.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: playerProv.players.length,
              itemBuilder: (context, i) {
                final player = playerProv.players[i];
                final isSelected = selected?.id == player.id;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                          .withOpacity(0.25)
                      : null,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isSelected
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        player.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(
                      player.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(
                      player.position,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withOpacity(0.5)),
                            ),
                            child: const Text(
                              'ACTIF',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Supprimer ?'),
                                content: Text(
                                    'Supprimer ${player.name} et tous ses lancers ?'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Annuler'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Supprimer'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await context
                                  .read<PlayerProvider>()
                                  .removePlayer(player.id);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      playerProv.selectPlayer(player);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerDetailScreen(player: player),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            'Aucun joueur.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white54),
          ),
          const SizedBox(height: 4),
          Text(
            'Appuyez sur + pour ajouter votre premier joueur',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
