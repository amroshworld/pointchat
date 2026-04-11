import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

import '../appwrite_client.dart';
import '../services/auth_service.dart';
import '../utils/chat_privacy_preferences.dart';

/// When app lock is enabled and a PIN exists, blocks the child until biometric or PIN succeeds.
/// Re-locks when the app returns from the background.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool? _locked;
  String _storedPin = '';
  String _enteredPin = '';
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // [main] syncs prefs before runApp; call setState immediately so the first
    // build() already sees _locked = true (not the spinner).
    _applyFromNotifiers(forceSetState: true);
    ChatPrivacyPreferences.appLockEnabledListenable.addListener(
      _onAppLockPrefChanged,
    );
    ChatPrivacyPreferences.privacyPinListenable.addListener(
      _onAppLockPrefChanged,
    );
  }

  void _applyFromNotifiers({bool forceSetState = false}) {
    if (_isAuthenticating) return;
    final enabled = ChatPrivacyPreferences.appLockEnabledListenable.value;
    final pin = ChatPrivacyPreferences.privacyPinListenable.value;
    final shouldLock = enabled && pin.isNotEmpty;
    if (shouldLock) {
      if (_locked != true || _storedPin != pin || forceSetState) {
        _locked = true;
        _storedPin = pin;
        _enteredPin = '';
        if (forceSetState) {
          // ignore mounted check — initState has no build yet
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          setState(() {});
        }
      }
    } else {
      if (_locked != false || forceSetState) {
        _locked = false;
        _storedPin = '';
        _enteredPin = '';
        if (forceSetState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() {});
          });
        } else {
          setState(() {});
        }
      }
    }
  }

  @override
  void dispose() {
    ChatPrivacyPreferences.appLockEnabledListenable.removeListener(
      _onAppLockPrefChanged,
    );
    ChatPrivacyPreferences.privacyPinListenable.removeListener(
      _onAppLockPrefChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onAppLockPrefChanged() {
    _applyFromNotifiers();
    // Keep disk in sync.
    unawaited(_evaluateLock());
  }

  Future<void> _evaluateLock() async {
    if (_isAuthenticating) return;
    final enabled = await ChatPrivacyPreferences.isAppLockEnabled();
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    if (!mounted) return;
    final shouldLock = enabled && pin.isNotEmpty;
    if (shouldLock) {
      setState(() {
        _storedPin = pin;
        _locked = true;
        _enteredPin = '';
      });
    } else {
      setState(() => _locked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isAuthenticating) return;
    if (state == AppLifecycleState.resumed) {
      // Show lock screen immediately from cached notifiers (no async gap).
      _applyFromNotifiers();
      unawaited(_evaluateLock());
    }
  }

  Future<void> _unlockWithBiometric() async {
    setState(() => _isAuthenticating = true);
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return; // Silent fail, let user use PIN
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock PointChat',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allows face/fingerprint/passcode
        ),
      );
      if (ok && mounted) {
        setState(() => _locked = false);
      }
    } catch (_) {
      // Ignore errors (user cancelled etc)
    } finally {
      // Delay resetting the authenticating flag so we ignore the
      // AppLifecycleState.resumed event triggered by the system biometric prompt closing.
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() => _isAuthenticating = false);
        }
      });
    }
  }

  void _onDigitEntered(String digit) {
    if (_enteredPin.length >= _storedPin.length) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
    });
    if (_enteredPin.length == _storedPin.length) {
      _verifyPin();
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  Future<void> _verifyPin() async {
    if (_enteredPin == _storedPin) {
      setState(() => _locked = false);
      _enteredPin = '';
    } else {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Incorrect PIN', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() {
        _enteredPin = '';
      });
    }
  }

  Widget _buildKeypadButton(String label, {VoidCallback? onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white10,
          highlightColor: Colors.white10,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            height: 72,
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadAction({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white10,
          highlightColor: Colors.white10,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            height: 72,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_locked == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_locked == true)
          Material(
            color:
                const Color(0xFF111114), // Dark background matching the design
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Text(
                    'Hi, ${cachedUserName.isNotEmpty ? cachedUserName : 'User'}',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Enter passcode to unlock',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 64),
                  // PIN Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_storedPin.length, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isFilled ? Colors.white : const Color(0xFF333333),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Numeric Keypad
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        for (final row in [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: row
                                  .map((d) => _buildKeypadButton(d,
                                      onTap: () => _onDigitEntered(d)))
                                  .toList(),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 32),
                          child: Row(
                            children: [
                              _buildKeypadAction(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Forgot PIN?',
                                          style: GoogleFonts.inter()),
                                      content: Text(
                                          'Logging out will reset your PIN and locked chats. You will need to log back in.',
                                          style: GoogleFonts.inter()),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await AuthService().signOut();
                                          },
                                          child: const Text('Log Out',
                                              style: TextStyle(
                                                  color: Colors.redAccent)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Text(
                                  'Forgot?',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueAccent.shade100,
                                  ),
                                ),
                              ),
                              _buildKeypadButton('0',
                                  onTap: () => _onDigitEntered('0')),
                              _buildKeypadAction(
                                onTap: _enteredPin.isEmpty
                                    ? _unlockWithBiometric
                                    : _onBackspace,
                                child: Icon(
                                  _enteredPin.isEmpty
                                      ? Icons.fingerprint
                                      : Icons.backspace_outlined,
                                  color: Colors.white70,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
