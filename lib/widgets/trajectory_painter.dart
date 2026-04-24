import 'package:flutter/material.dart';

/// Visualisation 2D simplifiée de la trajectoire vue de dessus
class TrajectoryPainter extends CustomPainter {
  final double curveCm;
  final double dropCm;

  TrajectoryPainter({required this.curveCm, required this.dropCm});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond grille
    final gridPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(Offset(w * i / 4, 0), Offset(w * i / 4, h), gridPaint);
      canvas.drawLine(Offset(0, h * i / 4), Offset(w, h * i / 4), gridPaint);
    }

    // Zone de strike (marbre)
    final platePaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(w / 2, h * 0.92), width: w * 0.18, height: h * 0.12),
      platePaint,
    );

    // Trajectoire de la balle (courbe de Bezier)
    final ballPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    // Normalisation : max ±60 cm = ±0.4 * width
    final double maxCm = 60;
    final double normCurve = (curveCm / maxCm).clamp(-1.0, 1.0) * 0.4;

    final start = Offset(w / 2, h * 0.06);
    final end = Offset(w / 2 + normCurve * w, h * 0.88);
    final ctrl = Offset(w / 2 + normCurve * w * 0.3, h * 0.5);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
    canvas.drawPath(path, ballPaint);

    // Point de départ (monticule)
    canvas.drawCircle(start, 5, Paint()..color = Colors.white70);
    // Point d'arrivée
    canvas.drawCircle(end, 6, Paint()..color = Colors.orangeAccent);

    // Label déviation
    final tp = TextPainter(
      text: TextSpan(
        text: '${curveCm.abs().toStringAsFixed(1)} cm',
        style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(end.dx + 8, end.dy - 8));
  }

  @override
  bool shouldRepaint(TrajectoryPainter old) =>
      old.curveCm != curveCm || old.dropCm != dropCm;
}
