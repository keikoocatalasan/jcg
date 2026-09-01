import 'package:flutter/material.dart';
import 'package:jcg_fitness/app/theme.dart';

class DotGridBackground extends StatelessWidget {
  final Widget child;
  final double dotSpacing;
  final double dotRadius;

  const DotGridBackground({
    super.key,
    required this.child,
    this.dotSpacing = 24,
    this.dotRadius = 1,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DotGridPainter(
        dotSpacing: dotSpacing,
        dotRadius: dotRadius,
      ),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final double dotSpacing;
  final double dotRadius;

  _DotGridPainter({required this.dotSpacing, required this.dotRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += dotSpacing) {
      for (double y = 0; y < size.height; y += dotSpacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.dotSpacing != dotSpacing ||
        oldDelegate.dotRadius != dotRadius;
  }
}
