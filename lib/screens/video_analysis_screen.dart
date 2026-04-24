import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/video_analysis_service.dart';
import '../services/physics_service.dart';
import '../models/throw_record.dart';
import '../providers/throw_provider.dart';
import '../providers/player_provider.dart';

enum AnalysisState { idle, recording, processing, done, error }

class VideoAnalysisScreen extends StatefulWidget {
  const VideoAnalysisScreen({super.key});

  @override
  State<VideoAnalysisScreen> createState() => _VideoAnalysisScreenState();
}

class _VideoAnalysisScreenState extends State<VideoAnalysisScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  AnalysisState _state = AnalysisState.idle;
  VideoAnalysisResult? _result;
  String? _errorMessage;
  String? _videoPath;

  // Calibration : pixels pour 1 mètre (ajustable par l'utilisateur)
  double _calibrationPx = 50.0;
  double _fps = 120.0;
  bool _calibrating = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Permission caméra refusée';
      });
      return;
    }

    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Aucune caméra disponible';
      });
      return;
    }

    // Choisir la caméra arrière
    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _cameraController = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Erreur init caméra : $e';
      });
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized) return;

    await WakelockPlus.enable();
    await _cameraController!.startVideoRecording();
    setState(() => _state = AnalysisState.recording);
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null) return;

    setState(() => _state = AnalysisState.processing);
    await WakelockPlus.disable();

    try {
      final xFile = await _cameraController!.stopVideoRecording();
      _videoPath = xFile.path;
      await _analyzeVideo(xFile.path);
    } catch (e) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Erreur enregistrement : $e';
      });
    }
  }

  Future<void> _analyzeVideo(String path) async {
    try {
      final result = await VideoAnalysisService.analyze(
        videoPath: path,
        fps: _fps,
        calibrationPx: _calibrationPx,
      );
      setState(() {
        _result = result;
        _state = AnalysisState.done;
      });
    } catch (e) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Erreur analyse : $e';
      });
    }
  }

  Future<void> _saveResult() async {
    final result = _result;
    final player = context.read<PlayerProvider>().selectedPlayer;
    if (result == null) return;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sélectionnez un joueur dans l\'onglet Joueurs')),
      );
      return;
    }

    final pitch = PhysicsService.calculate(
      rotationAngleDeg: result.rotationAngleDeg,
      rotationSpeedRpm: result.rotationSpeedRpm,
      ballSpeedKmh: result.ballSpeedKmh,
    );

    final record = ThrowRecord(
      id: const Uuid().v4(),
      playerId: player.id,
      rotationAngleDeg: result.rotationAngleDeg,
      rotationSpeedRpm: result.rotationSpeedRpm,
      ballSpeedKmh: result.ballSpeedKmh,
      pitchType: pitch.pitchType,
      curveEstimateCm: pitch.curveEstimateCm,
      dropEstimateCm: pitch.dropEstimateCm,
      recordedAt: DateTime.now(),
      notes: 'Analyse vidéo — confiance: ${result.confidence}',
    );

    await context.read<ThrowProvider>().addThrow(record);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Lancer enregistré pour ${player.name} (${pitch.pitchType})')),
      );
      setState(() => _state = AnalysisState.idle);
    }
  }

  void _reset() {
    setState(() {
      _state = AnalysisState.idle;
      _result = null;
      _errorMessage = null;
      _videoPath = null;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse vidéo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Paramètres',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case AnalysisState.idle:
      case AnalysisState.recording:
        return _buildCameraView();
      case AnalysisState.processing:
        return _buildProcessing();
      case AnalysisState.done:
        return _buildResults();
      case AnalysisState.error:
        return _buildError();
    }
  }

  Widget _buildCameraView() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final isRecording = _state == AnalysisState.recording;

    return Column(
      children: [
        // Instructions
        Container(
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Filmez de côté, balle dans la moitié supérieure. Commencez juste avant le lancer.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Prévisualisation caméra
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),

              // Grille de visée
              CustomPaint(painter: _AimGridPainter()),

              // Indicateur enregistrement
              if (isRecording)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record,
                            color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Text('REC',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),

              // Label FPS
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_fps.toInt()} fps',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Bouton enregistrement
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          color: Colors.black,
          child: Center(
            child: GestureDetector(
              onTap: isRecording ? _stopRecording : _startRecording,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: isRecording ? Colors.red : Colors.white,
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.fiber_manual_record,
                  color: isRecording ? Colors.white : Colors.red,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Analyse en cours…', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text(
            'Détection de la balle et calcul des paramètres',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final result = _result!;
    final confidenceColor = result.confidence == 'high'
        ? Colors.green
        : result.confidence == 'medium'
            ? Colors.orange
            : Colors.red;

    final confidenceLabel = result.confidence == 'high'
        ? 'Confiance élevée'
        : result.confidence == 'medium'
            ? 'Confiance moyenne'
            : 'Confiance faible';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Badge confiance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: confidenceColor.withOpacity(0.15),
              border: Border.all(color: confidenceColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics, color: confidenceColor, size: 16),
                const SizedBox(width: 8),
                Text(confidenceLabel,
                    style: TextStyle(
                        color: confidenceColor, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(${result.detections.length} détections)',
                    style: TextStyle(color: confidenceColor, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Résultats
          _ResultCard(
            icon: Icons.speed,
            label: 'Vitesse de la balle',
            value: result.ballSpeedKmh > 0
                ? '${result.ballSpeedKmh.toStringAsFixed(1)} km/h'
                : '—',
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          _ResultCard(
            icon: Icons.rotate_right,
            label: 'Vitesse de rotation',
            value: result.rotationSpeedRpm > 0
                ? '${result.rotationSpeedRpm.toStringAsFixed(0)} tr/min'
                : '—',
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _ResultCard(
            icon: Icons.architecture,
            label: 'Angle de rotation',
            value: '${result.rotationAngleDeg.toStringAsFixed(1)}°',
            color: Colors.green,
          ),

          // Notes / avertissements
          if (result.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...result.notes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(note,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveResult,
                  icon: const Icon(Icons.save),
                  label: const Text('Enregistrer le lancer'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Nouveau lancer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(onPressed: _reset, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paramètres d\'analyse',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),

              // FPS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('FPS de la vidéo'),
                  DropdownButton<double>(
                    value: _fps,
                    items: [30.0, 60.0, 120.0, 240.0]
                        .map((v) => DropdownMenuItem(
                            value: v, child: Text('${v.toInt()} fps')))
                        .toList(),
                    onChanged: (v) {
                      setSheetState(() => _fps = v!);
                      setState(() => _fps = v!);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Calibration
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Calibration (px/m)'),
                      Text(
                        '${_calibrationPx.toStringAsFixed(0)} px',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Slider(
                    value: _calibrationPx,
                    min: 10,
                    max: 200,
                    divisions: 190,
                    onChanged: (v) {
                      setSheetState(() => _calibrationPx = v);
                      setState(() => _calibrationPx = v);
                    },
                  ),
                  const Text(
                    'Astuce : filmez un objet de taille connue à la même distance et comptez les pixels.',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  const _ResultCard({
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
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _AimGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 0.5;

    // Lignes de grille
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
          Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(
          Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), paint);
    }

    // Zone cible (moitié supérieure, centre)
    final targetPaint = Paint()
      ..color = Colors.amber.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.3),
        width: size.width * 0.5,
        height: size.height * 0.3,
      ),
      targetPaint,
    );

    // Label zone cible
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Zone balle',
        style: TextStyle(color: Colors.amber, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.14));
  }

  @override
  bool shouldRepaint(_AimGridPainter old) => false;
}
