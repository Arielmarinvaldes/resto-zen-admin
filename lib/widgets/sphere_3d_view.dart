import 'package:flutter/material.dart';
import 'dart:math';

// Punto 3D simple
class Point3D {
  final double x, y, z;
  Point3D(this.x, this.y, this.z);
}

class Sphere3DView extends StatefulWidget {
  final List<int> highlightedIndices;
  final int pointCount;
  final double pointSize;

  const Sphere3DView({
    Key? key,
    required this.highlightedIndices,
    this.pointCount = 300,
    this.pointSize = 2.0,
  }) : super(key: key);

  @override
  _Sphere3DViewState createState() => _Sphere3DViewState();
}

class _Sphere3DViewState extends State<Sphere3DView>
    with SingleTickerProviderStateMixin {
  late List<Point3D> points;
  late AnimationController _controller;
  double rotationAngle = 0;

  @override
  void initState() {
    super.initState();
    points = _generatePoints(widget.pointCount);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 30))
      ..repeat();

    _controller.addListener(() {
      setState(() {
        rotationAngle += 0.01;
      });
    });
  }

  @override
  void didUpdateWidget(covariant Sphere3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightedIndices != widget.highlightedIndices) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Point3D> _generatePoints(int count) {
    final List<Point3D> points = [];
    final Random rng = Random();

    for (int i = 0; i < count; i++) {
      final theta = rng.nextDouble() * 2 * pi;
      final phi = acos(2 * rng.nextDouble() - 1);
      final x = sin(phi) * cos(theta);
      final y = sin(phi) * sin(theta);
      final z = cos(phi);
      points.add(Point3D(x, y, z));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: Sphere3DPainter(
        points: points,
        rotationAngle: rotationAngle,
        highlightedIndices: widget.highlightedIndices,
        pointSize: widget.pointSize,
      ),
      child: Container(
        height: 250,
        width: double.infinity,
      ),
    );
  }
}

class Sphere3DPainter extends CustomPainter {
  final List<Point3D> points;
  final double rotationAngle;
  final List<int> highlightedIndices;
  final double pointSize;

  Sphere3DPainter({
    required this.points,
    required this.rotationAngle,
    required this.highlightedIndices,
    required this.pointSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = min(size.width, size.height) / 1.6;
    canvas.translate(size.width / 2, size.height / 1.2);

    // Contadores para debug
    int puntosVerdes = 0;
    int puntosAzules = 0;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];

      // Rotación en eje Z
      final rotatedX = point.x * cos(rotationAngle) - point.z * sin(rotationAngle);
      final rotatedZ = point.x * sin(rotationAngle) + point.z * cos(rotationAngle);

      final screenX = rotatedX * radius;
      final screenY = point.y * radius;

      // Perspectiva (usada para tamaño y opacidad)
      final perspective = (rotatedZ + 1) / 2;

      final isHighlighted = highlightedIndices.contains(i);
      final position = Offset(screenX, screenY);

      if (isHighlighted) {
        // ✨ ESTRELLAS VERDES BRILLANTES (sin cambios)
        _drawGlowingStar(canvas, position, pointSize, perspective, rotationAngle + i);
        puntosVerdes++;
      } else {
        // 🔵 PUNTOS AZULES HERMOSOS
        final baseSize = pointSize * 1.2;
        final visualSize = baseSize * (0.8 + perspective * 0.4);
        _drawBeautifulBluePoint(canvas, position, visualSize);
        puntosAzules++;
      }
    }
  }

  // MÉTODO PARA PUNTOS MORADOS
  void _drawBeautifulBluePoint(Canvas canvas, Offset position, double size) {
    // Resplandor morado fuerte
    final glowPaint = Paint()
      ..color = const Color(0xFF1F1C2C).withOpacity(0.25)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    canvas.drawCircle(position, size * 1.8, glowPaint);

    // Punto principal morado suave
    final mainPaint = Paint()
      ..color = const Color(0xFF928DAB)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, size, mainPaint);

    // Centro morado más claro
    final centerPaint = Paint()
      ..color = const Color(0xFF928DAB).withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, size * 0.5, centerPaint);
  }

  // ✨ ESTRELLAS VERDES (sin cambios - mantiene el efecto actual)
  void _drawGlowingStar(Canvas canvas, Offset position, double baseSize, double perspective, double individualRotation) {
    final size = baseSize * (1.2 + perspective * 0.6);

    // 🌟 AURA EXTERIOR
    final outerGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(position, size * 4, outerGlowPaint);

    // 💚 RESPLANDOR MEDIO
    final midGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(position, size * 2.5, midGlowPaint);

    // ⭐ RESPLANDOR INTERNO
    final innerGlowPaint = Paint()
      ..color = Colors.green.withOpacity(0.6)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
    canvas.drawCircle(position, size * 1.5, innerGlowPaint);

    // 🌟 NÚCLEO BRILLANTE
    final corePaint = Paint()
      ..color = Colors.green.withOpacity(1.0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, size, corePaint);

    // ✨ PUNTO CENTRAL SÚPER BRILLANTE
    final centerPaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(position, size * 0.4, centerPaint);

    // 🌠 RAYOS DE ESTRELLA
    _drawStarRays(canvas, position, size, individualRotation);
  }

  // ⭐ RAYOS DE ESTRELLA (sin cambios)
  void _drawStarRays(Canvas canvas, Offset center, double size, double rotation) {
    final rayPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

    // 4 rayos principales
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) + rotation * 0.5;
      final rayLength = size * 2.5;
      final rayWidth = size * 0.15;

      final endX = center.dx + cos(angle) * rayLength;
      final endY = center.dy + sin(angle) * rayLength;

      final rayPath = Path();
      rayPath.moveTo(center.dx, center.dy);
      rayPath.lineTo(endX, endY);

      canvas.drawPath(
        rayPath,
        Paint()
          ..color = Colors.green.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = rayWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // 4 rayos secundarios
    for (int i = 0; i < 4; i++) {
      final angle = (i * pi / 2) + (pi / 4) + rotation * 0.3;
      final rayLength = size * 1.8;
      final rayWidth = size * 0.1;

      final endX = center.dx + cos(angle) * rayLength;
      final endY = center.dy + sin(angle) * rayLength;

      final rayPath = Path();
      rayPath.moveTo(center.dx, center.dy);
      rayPath.lineTo(endX, endY);

      canvas.drawPath(
        rayPath,
        Paint()
          ..color = Colors.green.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = rayWidth
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}