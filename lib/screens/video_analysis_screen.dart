import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/video_analysis_service.dart';
import '../services/camera_capability_service.dart';
import '../services/video_importer_service.dart';
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
  CameraCapability? _capability;

  double _calibrationPx = 50.0;
  double _fps = 120.0;
  bool _isImported = false;

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

    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    try {
      final target = await CameraCapabilityService.detectBestCapability(back);
      final result = await CameraCapabilityService.buildController(back, target);
      _cameraController = result.controller;
      _capability = result.capability;
      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Erreur init caméra : $e';
      });
    }
  }

  Future<void> _startRecording() async {
    if (_cameraController == null) return;
    await WakelockPlus.enable();
    await _cameraController!.startVideoRecording();
    HapticFeedback.lightImpact();
    setState(() => _state = AnalysisState.recording);
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null) return;
    setState(() => _state = AnalysisState.processing);
    await WakelockPlus.disable();
    try {
      final xFile = await _cameraController!.stopVideoRecording();
      await _analyzeVideo(xFile.path);
    } catch (e) {
      setState(() {
        _state = AnalysisState.error;
        _errorMessage = 'Erreur enregistrement : $e';
      });
    }
  }

  Future<void> _importVideo() async {
    setState(() => _state = AnalysisState.processing);
    final path = await VideoImporterService.pickVideo();
    if (path == null) {
      setState(() => _state = AnalysisState.idle);
      return;
    }
    _isImported = true;
    await _analyzeVideo(path);
  }

  Future<void> _analyzeVideo(String path) async {
    try {
      final effectiveFps = _isImported ? _fps : (_capability?.fps ?? 30.0);
      final result = await VideoAnalysisService.analyze(
        videoPath: path,
        fps: effectiveFps,
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
        SnackBar(
          content: const Text('Sélectionnez un joueur dans l’onglet Joueurs'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
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
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✨ Enregistré pour ${player.name} (${pitch.pitchType})'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() => _state = AnalysisState.idle);
    }
  }

  void _reset() {
    setState(() {
      _state = AnalysisState.idle;
      _result = null;
      _errorMessage = null;
      _isImported = false;
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
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Paramètres',
            onPressed: _showSettingsSheet,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF12121A), Color(0xFF1E1E2E)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isImported || _cameraController == null || !_cameraController!.value.isInitialized) {
      return _buildImportPlaceholder();
    }
    return _buildCameraView();
  }

  Widget _buildImportPlaceholder() {
    final hasResult = _result != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.blue.shade900],
                ),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20)],
              ),
              child: const Icon(Icons.video_library, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 28),
            const Text(
              'Mode Import vidéo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sélectionnez une vidéo de lancer depuis votre galerie.\nLe slo-mo (120fps / 240fps) améliore la précision.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.4),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _importVideo,
              icon: const Icon(Icons.folder_open),
              label: const Text('Choisir une vidéo'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            if (hasResult) ...[
              const SizedBox(height: 28),
              _ImportResultPreview(result: _result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    final controller = _cameraController!;
    final isRecording = _state == AnalysisState.recording;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.black87,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filmez de côté. La balle doit rester dans la zone centrale.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              CustomPaint(painter: _AimGridPainter()),
              if (_capability != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _capability!.isSlowMotion
                          ? Colors.blue.withOpacity(0.8)
                          : Colors.grey.shade800.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_capability!.isSlowMotion) ...[
                          const Icon(Icons.slow_motion_video, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _capability!.label,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              if (isRecording)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 8)],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                        SizedBox(width: 4),
                        Text('REC', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          color: Colors.black87,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: isRecording ? Icons.stop : Icons.fiber_manual_record,
                color: isRecording ? Colors.red : Colors.white,
                label: isRecording ? 'STOP' : 'FILMER',
                onTap: isRecording ? _stopRecording : _startRecording,
              ),
              const SizedBox(width: 28),
              _ControlButton(
                icon: Icons.video_library,
                color: Colors.blue,
                label: 'IMPORTER',
                onTap: _importVideo,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paramètres', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _ChoiceChipItem(
                        label: 'Caméra',
                        selected: !_isImported,
                        onSelected: (sel) {
                          setSheetState(() => _isImported = false);
                          setState(() => _isImported = false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChoiceChipItem(
                        label: 'Importer',
                        selected: _isImported,
                        onSelected: (sel) {
                          setSheetState(() => _isImported = true);
                          setState(() => _isImported = true);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('FPS de la vidéo'),
                    DropdownButton<double>(
                      value: _fps,
                      items: [30.0, 60.0, 120.0, 240.0]
                          .map((v) => DropdownMenuItem(value: v, child: Text('${v.toInt()} fps')))
                          .toList(),
                      onChanged: _isImported
                          ? (v) {
                              setSheetState(() => _fps = v!);
                              setState(() => _fps = v!);
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Calibration (px/m)'),
                        Text('${_calibrationPx.toInt()} px/m',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.w600)),
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
                      'Astuce : filme un objet de taille connue et ajuste pour que 1 m = N pixels.',
                      style: TextStyle(fontSize: 11, color: Colors.white54, height: 1.3),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(height: 20),
          Text('Analyse en cours…', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text('Détection de la balle et calcul des paramètres…',
              style: TextStyle(color: Colors.white54)),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: confidenceColor.withOpacity(0.15),
              border: Border.all(color: confidenceColor.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics, color: confidenceColor, size: 18),
                const SizedBox(width: 8),
                Text(confidenceLabel,
                    style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${result.detections.length} détections',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ResultCard(
                  icon: Icons.speed,
                  label: 'Vitesse',
                  value: result.ballSpeedKmh > 0
                      ? '${result.ballSpeedKmh.toStringAsFixed(1)} km/h'
                      : '—',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ResultCard(
                  icon: Icons.rotate_right,
                  label: 'Rotation',
                  value: result.rotationSpeedRpm > 0
                      ? '${result.rotationSpeedRpm.toStringAsFixed(0)} tr/min'
                      : '—',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ResultCard(
            icon: Icons.architecture,
            label: 'Angle',
            value: '${result.rotationAngleDeg.toStringAsFixed(1)}°',
            color: Colors.greenAccent,
            fullWidth: true,
          ),
          if (result.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...result.notes.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saveResult,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer le lancer'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.videocam),
            label: const Text('Nouveau lancer'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
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
            const Icon(Icons.error_outline, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Erreur inconnue',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets locaux ─────────────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ControlButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
              color: Colors.black87,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ChoiceChipItem extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  const _ChoiceChipItem({
    required this.label,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelected(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.white10,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.white24,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.white70,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;
  const _ResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.2),
            theme.colorScheme.secondaryContainer.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white60, letterSpacing: 0.5),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AimGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(Offset(size.width * i / 3, 0), Offset(size.width * i / 3, size.height), paint);
      canvas.drawLine(Offset(0, size.height * i / 3), Offset(size.width, size.height * i / 3), paint);
    }
    final targetPaint = Paint()
      ..color = Colors.amber.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.3),
        width: size.width * 0.5,
        height: size.height * 0.3,
      ),
      targetPaint,
    );
    final tp = TextPainter(
      text: const TextSpan(text: 'Zone balle', style: TextStyle(color: Colors.amber, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    tp.paint(canvas, Offset(size.width / 2 - tp.width / 2, size.height * 0.14));
  }

  @override
  bool shouldRepaint(_AimGridPainter old) => false;
}

class _ImportResultPreview extends StatelessWidget {
  final VideoAnalysisResult result;
  const _ImportResultPreview({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 450),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('Analyse terminée',
                      style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ResultCard(
                  icon: Icons.speed,
                  label: 'Vitesse',
                  value: result.ballSpeedKmh > 0
                      ? '${result.ballSpeedKmh.toStringAsFixed(1)} km/h'
                      : '—',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResultCard(
                  icon: Icons.rotate_right,
                  label: 'Rotation',
                  value: result.rotationSpeedRpm > 0
                      ? '${result.rotationSpeedRpm.toStringAsFixed(0)} tr/min'
                      : '—',
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ResultCard(
            icon: Icons.architecture,
            label: 'Angle',
            value: '${result.rotationAngleDeg.toStringAsFixed(1)}°',
            color: Colors.greenAccent,
            fullWidth: true,
          ),
        ],
      ),
    ),
  );
  }
}
