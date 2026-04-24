import 'package:flutter/foundation.dart';
import '../models/throw_record.dart';
import '../services/database_service.dart';
import '../services/advice_service.dart';

class ThrowProvider extends ChangeNotifier {
  List<ThrowRecord> _throws = [];
  List<Advice> _advices = [];

  List<ThrowRecord> get throws => _throws;
  List<Advice> get advices => _advices;

  Future<void> loadThrowsForPlayer(String playerId) async {
    _throws = await DatabaseService.instance.getThrowsForPlayer(playerId);
    _advices = AdviceService.generateAdvice(_throws);
    notifyListeners();
  }

  Future<void> addThrow(ThrowRecord record) async {
    await DatabaseService.instance.insertThrow(record);
    await loadThrowsForPlayer(record.playerId);
  }

  Future<void> removeThrow(String id, String playerId) async {
    await DatabaseService.instance.deleteThrow(id);
    await loadThrowsForPlayer(playerId);
  }

  void clear() {
    _throws = [];
    _advices = [];
    notifyListeners();
  }
}
