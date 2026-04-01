import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Four large digit boxes with an on-screen keypad (0–9, backspace).
class FourDigitPinEntry extends StatefulWidget {
  final String title;
  final String? subtitle;
  final void Function(String fourDigits) onCompleted;
  final bool obscureDigits;

  const FourDigitPinEntry({
    super.key,
    required this.title,
    this.subtitle,
    required this.onCompleted,
    this.obscureDigits = true,
  });

  @override
  State<FourDigitPinEntry> createState() => _FourDigitPinEntryState();
}

class _FourDigitPinEntryState extends State<FourDigitPinEntry> {
  final StringBuffer _buf = StringBuffer();

  void _add(String d) {
    if (_buf.length >= 4) return;
    setState(() => _buf.write(d));
    if (_buf.length == 4) {
      widget.onCompleted(_buf.toString());
    }
  }

  void _backspace() {
    if (_buf.isEmpty) return;
    setState(() {
      final s = _buf.toString();
      _buf.clear();
      _buf.write(s.substring(0, s.length - 1));
    });
  }

  void clear() {
    setState(_buf.clear);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final digits = _buf.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < digits.length;
            final ch = filled ? (widget.obscureDigits ? '•' : digits[i]) : '';
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: filled
                        ? scheme.primary
                        : scheme.outline.withValues(alpha: 0.45),
                    width: filled ? 2.2 : 1.2,
                  ),
                ),
                child: Text(
                  ch,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: widget.obscureDigits ? 28 : 22,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        _Keypad(
          onDigit: _add,
          onBackspace: _backspace,
        ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap}) {
      return Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 52,
            child: Center(
              child: label == '⌫'
                  ? Icon(Icons.backspace_outlined, color: scheme.onSurface)
                  : Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (final cell in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: cell.isEmpty
                          ? const SizedBox(height: 52)
                          : key(
                              cell,
                              onTap: cell == '⌫'
                                  ? onBackspace
                                  : () => onDigit(cell),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
