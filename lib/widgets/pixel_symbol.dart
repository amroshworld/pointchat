import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Center(
        child: Text(
          isGroup ? '#' : '@',
          style: GoogleFonts.inter(
            color: color,
            fontSize: size * 0.9,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
