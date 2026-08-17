import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/chat_privacy_preferences.dart';
import '../../widgets/four_digit_pin_entry.dart';

/// Sets or changes the 4-digit chat-security PIN.
///
/// When a PIN already exists, the current PIN must be verified first before a
/// new one can be created.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  int _step = 0;
  int _attempt = 0;
  String? _first;
  String _currentPin = '';
  bool _loading = true;

  bool get _requiresVerify => _currentPin.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    if (!mounted) return;
    setState(() {
      _currentPin = pin;
      _loading = false;
    });
  }

  String get _title {
    if (_requiresVerify) {
      switch (_step) {
        case 0:
          return 'Enter current PIN';
        case 1:
          return 'Create new PIN';
        default:
          return 'Confirm new PIN';
      }
    }
    return _step == 0 ? 'Create PIN' : 'Confirm PIN';
  }

  String get _subtitle {
    if (_requiresVerify) {
      switch (_step) {
        case 0:
          return 'Verify your current PIN before changing it.';
        case 1:
          return 'Enter 4 digits. You will enter them again on the next step.';
        default:
          return 'Enter the same 4 digits again to confirm.';
      }
    }
    return _step == 0
        ? 'Enter 4 digits. You will enter them again on the next step.'
        : 'Enter the same 4 digits again to confirm.';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
      ),
    );
  }

  void _clearEntry() {
    setState(() => _attempt++);
  }

  Future<void> _onCompleted(String pin) async {
    if (_requiresVerify) {
      if (_step == 0) {
        if (pin == _currentPin) {
          setState(() {
            _first = null;
            _step = 1;
            _attempt++;
          });
        } else {
          _showSnack('Incorrect PIN');
          _clearEntry();
        }
        return;
      }
      if (_step == 1) {
        if (pin == _currentPin) {
          _showSnack('New PIN must be different from the current PIN');
          setState(() => _attempt++);
          return;
        }
        setState(() {
          _first = pin;
          _step = 2;
          _attempt++;
        });
        return;
      }
      // step == 2 (confirm)
      if (pin == _first) {
        await ChatPrivacyPreferences.setPrivacyPin(pin);
        await ChatPrivacyPreferences.syncAppLockListenable();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showSnack('PINs did not match. Start again.');
        setState(() {
          _step = 1;
          _first = null;
          _attempt++;
        });
      }
      return;
    }

    // No existing PIN: create + confirm.
    if (_step == 0) {
      setState(() {
        _first = pin;
        _step = 1;
        _attempt++;
      });
      return;
    }
    if (pin == _first) {
      await ChatPrivacyPreferences.setPrivacyPin(pin);
      await ChatPrivacyPreferences.syncAppLockListenable();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      _showSnack('PINs did not match. Start again.');
      setState(() {
        _step = 0;
        _first = null;
        _attempt++;
      });
    }
  }

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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: FourDigitPinEntry(
                          key: ValueKey('${_step}_$_attempt'),
                          title: _title,
                          subtitle: _subtitle,
                          onCompleted: _onCompleted,
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
