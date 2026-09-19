import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DemoScreen(),
    );
  }
}

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: HexPainter(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: const Center(
                        child: CornerAppLogo(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'الرئيسية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'هذه خلفية مرسومة بالكود ويمكنك وضع محتوى التطبيق فوقها مباشرة',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.74),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HexPainter extends CustomPainter {
  const HexPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF1737A7),
          Color(0xFF123094),
          Color(0xFF0E2578),
        ],
        stops: [0.0, 0.58, 1.0],
      ).createShader(bgRect);

    canvas.drawRect(bgRect, bgPaint);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.9),
        radius: 1.0,
        colors: [
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.00),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.05),
          radius: size.width * 0.9,
        ),
      );

    canvas.drawRect(bgRect, glowPaint);

    final topShape = _topMarkPath(size);
    final bottomShape = _bottomMarkPath(size);

    canvas.drawShadow(
      topShape,
      Colors.black.withOpacity(0.18),
      14,
      false,
    );

    canvas.drawShadow(
      bottomShape,
      Colors.black.withOpacity(0.14),
      12,
      false,
    );

    final topRect = Rect.fromLTWH(
      size.width * 0.44,
      size.height * 0.09,
      size.width * 0.48,
      size.height * 0.15,
    );

    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x99D6DEFF),
          Color(0x66A7B8FF),
          Color(0x22FFFFFF),
        ],
        stops: [0.0, 0.72, 1.0],
      ).createShader(topRect);

    final bottomRect = Rect.fromLTWH(
      size.width * 0.10,
      size.height * 0.24,
      size.width * 0.56,
      size.height * 0.22,
    );

    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x88E7EEFF),
          Color(0x55C3D3FF),
          Color(0x18FFFFFF),
        ],
        stops: [0.0, 0.68, 1.0],
      ).createShader(bottomRect);

    canvas.drawPath(topShape, topPaint);
    canvas.drawPath(bottomShape, bottomPaint);
  }

  Path _topMarkPath(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.46, size.height * 0.08)
      ..lineTo(size.width * 0.83, size.height * 0.17)
      ..lineTo(size.width * 0.83, size.height * 0.34)
      ..lineTo(size.width * 0.66, size.height * 0.41)
      ..lineTo(size.width * 0.50, size.height * 0.34)
      ..lineTo(size.width * 0.63, size.height * 0.27)
      ..lineTo(size.width * 0.46, size.height * 0.18)
      ..close();

    return path;
  }

  Path _bottomMarkPath(Size size) {
    final path = Path()
      ..moveTo(size.width * 0.13, size.height * 0.25)
      ..lineTo(size.width * 0.43, size.height * 0.35)
      ..lineTo(size.width * 0.60, size.height * 0.50)
      ..lineTo(size.width * 0.60, size.height * 0.67)
      ..lineTo(size.width * 0.13, size.height * 0.49)
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CornerAppLogo extends StatelessWidget {
  const CornerAppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: CornerAppLogoPainter(),
      ),
    );
  }
}

class CornerAppLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final topPath = Path()
      ..moveTo(size.width * 0.42, size.height * 0.08)
      ..lineTo(size.width * 0.90, size.height * 0.28)
      ..lineTo(size.width * 0.90, size.height * 0.54)
      ..lineTo(size.width * 0.69, size.height * 0.68)
      ..lineTo(size.width * 0.55, size.height * 0.56)
      ..lineTo(size.width * 0.70, size.height * 0.45)
      ..lineTo(size.width * 0.42, size.height * 0.22)
      ..close();

    final bottomPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.42)
      ..lineTo(size.width * 0.42, size.height * 0.28)
      ..lineTo(size.width * 0.58, size.height * 0.42)
      ..lineTo(size.width * 0.40, size.height * 0.54)
      ..lineTo(size.width * 0.72, size.height * 0.80)
      ..lineTo(size.width * 0.72, size.height * 0.95)
      ..lineTo(size.width * 0.08, size.height * 0.60)
      ..close();

    canvas.drawShadow(
      topPath,
      Colors.black.withOpacity(0.16),
      4,
      false,
    );

    canvas.drawShadow(
      bottomPath,
      Colors.black.withOpacity(0.12),
      4,
      false,
    );

    final topPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF8EA6FF),
          Color(0xFF4965F0),
          Color(0xFF253CC6),
        ],
      ).createShader(Offset.zero & size);

    final bottomPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF59D7CC),
          Color(0xFF39A8B5),
          Color(0xFF2E7EA0),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(topPath, topPaint);
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
