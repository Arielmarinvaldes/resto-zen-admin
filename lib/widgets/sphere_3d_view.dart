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
    int puntosBlancos = 0;

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

      // Colores más visibles para debug
      final color = isHighlighted
          ? Colors.green.withOpacity(0.9)  // Verde más visible
          : Colors.black.withOpacity(0.7); // Blanco más visible

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      // Tamaño ligeramente mayor para los puntos verdes
      final baseSize = isHighlighted ? pointSize * 1.5 : pointSize;
      final visualSize = baseSize * (0.5 + perspective);

      canvas.drawCircle(Offset(screenX, screenY), visualSize, paint);

      // Contar para debug
      if (isHighlighted) {
        puntosVerdes++;
      } else {
        puntosBlancos++;
      }
    }

    // Debug: imprimir contadores cada cierto tiempo
    if (rotationAngle % (pi / 4) < 0.1) { // Cada 45 grados aproximadamente
      print("🎨 Renderizado: $puntosVerdes verdes, $puntosBlancos blancos");
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}