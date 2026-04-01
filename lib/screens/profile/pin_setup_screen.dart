import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/chat_privacy_preferences.dart';
import '../../widgets/four_digit_pin_entry.dart';

/// Enter a 4-digit PIN twice; saves to [ChatPrivacyPreferences.setPrivacyPin].
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  int _step = 0;
  String? _first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PIN setup',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: FourDigitPinEntry(
                    key: ValueKey(_step),
                    title: _step == 0 ? 'Create PIN' : 'Confirm PIN',
                    subtitle: _step == 0
                        ? 'Enter 4 digits. You will enter them again on the next step.'
                        : 'Enter the same 4 digits again to confirm.',
                    onCompleted: (pin) async {
                      if (_step == 0) {
                        setState(() {
                          _first = pin;
                          _step = 1;
                        });
                        return;
                      }
                      if (pin == _first) {
                        await ChatPrivacyPreferences.setPrivacyPin(pin);
                        await ChatPrivacyPreferences.syncAppLockListenable();
                        if (context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'PINs did not match. Start again.',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        }
                        setState(() {
                          _step = 0;
                          _first = null;
                        });
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
