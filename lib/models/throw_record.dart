class ThrowRecord {
  final String id;
  final String playerId;
  final double rotationAngleDeg;   // angle de rotation en degrés (axe tilt)
  final double rotationSpeedRpm;   // vitesse de rotation en tours/min
  final double ballSpeedKmh;       // vitesse de la balle en km/h
  final String pitchType;          // type de lancer calculé
  final double curveEstimateCm;    // déviation latérale estimée en cm
  final double dropEstimateCm;     // chute verticale estimée en cm
  final DateTime recordedAt;
  final String? notes;

  ThrowRecord({
    required this.id,
    required this.playerId,
    required this.rotationAngleDeg,
    required this.rotationSpeedRpm,
    required this.ballSpeedKmh,
    required this.pitchType,
    required this.curveEstimateCm,
    required this.dropEstimateCm,
    required this.recordedAt,
    this.notes,
  });

  factory ThrowRecord.fromMap(Map<String, dynamic> map) {
    return ThrowRecord(
      id: map['id'] as String,
      playerId: map['player_id'] as String,
      rotationAngleDeg: (map['rotation_angle_deg'] as num).toDouble(),
      rotationSpeedRpm: (map['rotation_speed_rpm'] as num).toDouble(),
      ballSpeedKmh: (map['ball_speed_kmh'] as num).toDouble(),
      pitchType: map['pitch_type'] as String,
      curveEstimateCm: (map['curve_estimate_cm'] as num).toDouble(),
      dropEstimateCm: (map['drop_estimate_cm'] as num).toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_id': playerId,
      'rotation_angle_deg': rotationAngleDeg,
      'rotation_speed_rpm': rotationSpeedRpm,
      'ball_speed_kmh': ballSpeedKmh,
      'pitch_type': pitchType,
      'curve_estimate_cm': curveEstimateCm,
      'drop_estimate_cm': dropEstimateCm,
      'recorded_at': recordedAt.toIso8601String(),
      'notes': notes,
    };
  }
}
