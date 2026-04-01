import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/chat_privacy_preferences.dart';
import 'pin_setup_screen.dart';

/// App lock + 4-digit PIN UI. Used from [ProfileScreen] and stream settings overlay.
class ChatSecuritySettingsPanel extends StatefulWidget {
  const ChatSecuritySettingsPanel({super.key});

  @override
  State<ChatSecuritySettingsPanel> createState() =>
      _ChatSecuritySettingsPanelState();
}

class _ChatSecuritySettingsPanelState extends State<ChatSecuritySettingsPanel> {
  bool _loading = true;
  bool _pinSaved = false;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    final appLock = await ChatPrivacyPreferences.isAppLockEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _pinSaved = pin.isNotEmpty;
      _appLockEnabled = appLock;
      _loading = false;
    });
  }

  Future<void> _openPinSetup() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (ok == true && mounted) {
      await _load();
      await ChatPrivacyPreferences.syncAppLockListenable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PIN saved.',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _onAppLockChanged(bool value) async {
    if (value) {
      final pin = await ChatPrivacyPreferences.getPrivacyPin();
      if (!mounted) return;
      if (pin.isEmpty) {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
        if (ok != true || !mounted) {
          return;
        }
      }
      await ChatPrivacyPreferences.setAppLockEnabled(true);
    } else {
      await ChatPrivacyPreferences.setAppLockEnabled(false);
    }
    await ChatPrivacyPreferences.syncAppLockListenable();
    if (mounted) {
      setState(() => _appLockEnabled = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hint: Swipe a DM left to blur and lock, or right to delete.',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Lock app when opening',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            'Ask for fingerprint, face, or PIN to use PointChat (not for each chat).',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          value: _appLockEnabled,
          onChanged: _onAppLockChanged,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openPinSetup,
            icon: const Icon(Icons.grid_on_rounded),
            label: Text(
              _pinSaved ? 'Change PIN (4 digits)' : 'Set PIN (4 digits)',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Opens the PIN pad twice to confirm. You can use the same PIN for app lock and locked chats.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Chat Security PIN',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set a PIN to unlock locked chats when biometric authentication is unavailable.',
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _pinSaved
                ? Colors.green.withValues(alpha: 0.1)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _pinSaved
                  ? Colors.green.withValues(alpha: 0.3)
                  : scheme.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _pinSaved
                      ? Colors.green.withValues(alpha: 0.2)
                      : scheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _pinSaved ? Icons.shield_rounded : Icons.shield_outlined,
                  color: _pinSaved ? Colors.green : scheme.onSurfaceVariant,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pinSaved
                          ? 'PIN Protection Active'
                          : 'PIN Not Configured',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _pinSaved
                            ? Colors.green.shade600
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pinSaved
                          ? 'A PIN is saved on this device for app lock and locked chats.'
                          : 'Use “Set PIN” above to create a 4-digit PIN.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Swipe a DM left to blur and lock. Use biometrics or PIN to open a locked chat.',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
