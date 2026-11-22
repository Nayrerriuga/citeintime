import 'dart:math' as math;
import 'package:flutter/material.dart';

class GrandLinePalette {
  static const Color oceanDeep = Color(0xFF071324);
  static const Color oceanMid = Color(0xFF0E294B);
  static const Color treasureGold = Color(0xFFFFC107);
  static const Color strawHatRed = Color(0xFFD32F2F);
  static const Color parchmentCream = Color(0xFFFDF8E8);
}

class StrawHatLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);

    // Straw Hat Dome
    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -2), width: 42, height: 34),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFFD54F),
    );

    // Signature Red Ribbon Band
    canvas.drawLine(
      center.translate(-20, -4),
      center.translate(20, -4),
      Paint()
        ..color = GrandLinePalette.strawHatRed
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke,
    );

    // Straw Hat Brim
    canvas.drawLine(
      center.translate(-30, 0),
      center.translate(30, 0),
      Paint()
        ..color = const Color(0xFFFFCA28)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Attendance Check Arc Below
    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(center.dx - 9, center.dy + 13)
      ..lineTo(center.dx - 2, center.dy + 20)
      ..lineTo(center.dx + 11, center.dy + 9);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompassTicksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = GrandLinePalette.treasureGold
      ..strokeWidth = 2;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final inner = i % 3 == 0 ? radius - 9 : radius - 5;
      canvas.drawLine(
        Offset(
          center.dx + inner * math.cos(angle),
          center.dy + inner * math.sin(angle),
        ),
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MiniStrawHatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 2);

    canvas.drawArc(
      Rect.fromCenter(center: center.translate(0, -1), width: 20, height: 16),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFFFFD54F),
    );

    canvas.drawLine(
      center.translate(-10, -2),
      center.translate(10, -2),
      Paint()
        ..color = GrandLinePalette.strawHatRed
        ..strokeWidth = 2.5,
    );

    canvas.drawLine(
      center.translate(-14, 0),
      center.translate(14, 0),
      Paint()
        ..color = const Color(0xFFFFCA28)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GrandLineBackgroundPainter extends CustomPainter {
  final double waveProgress;
  final double compassAngle;

  GrandLineBackgroundPainter({
    required this.waveProgress,
    required this.compassAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.45),
        radius: 1.25,
        colors: [Color(0xFF133B6B), GrandLinePalette.oceanDeep],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roseCenter = Offset(size.width * 0.5, size.height * 0.24);
    final rosePaint = Paint()
      ..color = GrandLinePalette.treasureGold.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(roseCenter, 150, rosePaint);
    canvas.drawCircle(roseCenter, 195, rosePaint);

    for (int i = 0; i < 8; i++) {
      final a = compassAngle + (i * math.pi / 4);
      canvas.drawLine(
        roseCenter,
        Offset(
          roseCenter.dx + 195 * math.cos(a),
          roseCenter.dy + 195 * math.sin(a),
        ),
        rosePaint,
      );
    }

    _drawWave(
      canvas,
      size,
      amplitude: 14,
      frequency: 1.6,
      phase: waveProgress * 2 * math.pi,
      baseHeight: size.height * 0.88,
      color: GrandLinePalette.oceanMid.withValues(alpha: 0.75),
    );
    _drawWave(
      canvas,
      size,
      amplitude: 10,
      frequency: 2.2,
      phase: -waveProgress * 2 * math.pi,
      baseHeight: size.height * 0.92,
      color: GrandLinePalette.treasureGold.withValues(alpha: 0.08),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double amplitude,
    required double frequency,
    required double phase,
    required double baseHeight,
    required Color color,
  }) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 6) {
      final y =
          baseHeight +
          amplitude *
              math.sin((x / size.width * frequency * 2 * math.pi) + phase);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant GrandLineBackgroundPainter oldDelegate) => true;
}
