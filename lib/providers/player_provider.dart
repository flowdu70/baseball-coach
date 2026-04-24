import 'package:flutter/foundation.dart';
import '../models/player.dart';
import '../services/database_service.dart';

class PlayerProvider extends ChangeNotifier {
  List<Player> _players = [];
  Player? _selectedPlayer;

  List<Player> get players => _players;
  Player? get selectedPlayer => _selectedPlayer;

  Future<void> loadPlayers() async {
    _players = await DatabaseService.instance.getPlayers();
    notifyListeners();
  }

  Future<void> addPlayer(Player player) async {
    await DatabaseService.instance.insertPlayer(player);
    await loadPlayers();
  }

  Future<void> removePlayer(String id) async {
    await DatabaseService.instance.deletePlayer(id);
    if (_selectedPlayer?.id == id) _selectedPlayer = null;
    await loadPlayers();
  }

  void selectPlayer(Player player) {
    _selectedPlayer = player;
    notifyListeners();
  }

  void clearSelection() {
    _selectedPlayer = null;
    notifyListeners();
  }
}
