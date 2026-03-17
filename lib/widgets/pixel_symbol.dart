import 'package:flutter/material.dart';

class PixelSymbol extends StatelessWidget {
  final bool isGroup;
  final Color color;
  final double size;

  const PixelSymbol({
    super.key,
    required this.isGroup,
    required this.color,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    // 5x5 pixel grid logic
    final double pixelSize = size / 5;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PixelPainter(
          isGroup: isGroup,
          color: color,
          pixelSize: pixelSize,
        ),
      ),
    );
  }
}

class _PixelPainter extends CustomPainter {
  final bool isGroup;
  final Color color;
  final double pixelSize;

  _PixelPainter({
    required this.isGroup,
    required this.color,
    required this.pixelSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // We'll draw a 5x5 grid
    List<List<int>> grid = [];

    if (isGroup) {
      // Small group representation
      grid = [
        [0, 1, 0, 1, 0],
        [1, 1, 1, 1, 1],
        [0, 1, 0, 1, 0],
        [1, 0, 1, 0, 1],
        [1, 1, 1, 1, 1],
      ];
    } else {
      // Single person representation
      grid = [
        [0, 1, 1, 1, 0],
        [0, 1, 0, 1, 0],
        [0, 1, 1, 1, 0],
        [1, 1, 1, 1, 1],
        [1, 0, 0, 0, 1],
      ];
    }

    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        if (grid[y][x] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(x * pixelSize, y * pixelSize, pixelSize, pixelSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
