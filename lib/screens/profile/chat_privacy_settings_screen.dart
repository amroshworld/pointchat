import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/chat_privacy_preferences.dart';

class ChatPrivacySettingsScreen extends StatefulWidget {
  const ChatPrivacySettingsScreen({super.key});

  @override
  State<ChatPrivacySettingsScreen> createState() =>
      _ChatPrivacySettingsScreenState();
}

class _ChatPrivacySettingsScreenState extends State<ChatPrivacySettingsScreen> {
  final _pinController = TextEditingController();
  bool _loading = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    final motion = await ChatPrivacyPreferences.getReduceUiMotion();
    if (!mounted) {
      return;
    }
    setState(() {
      _pinController.text = pin;
      _reduceMotion = motion;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final raw = _pinController.text.trim();
    if (raw.isNotEmpty && (raw.length < 4 || raw.length > 8)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN must be 4–8 digits, or empty.')),
        );
      }
      return;
    }
    if (raw.isNotEmpty && int.tryParse(raw) == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN must be numeric.')),
        );
      }
      return;
    }
    await ChatPrivacyPreferences.setPrivacyPin(raw);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.isEmpty
                ? 'PIN cleared. Use biometric only when opening locked chats.'
                : 'PIN saved.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats & performance',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Locked chats',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'On the Messages tab, select one or more chats (long-press), then tap the lock icon in the app bar. Locked threads stay blurred until you unlock with biometric or PIN.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: 'Backup PIN (optional)',
                    hintText: '4–8 digits, or leave empty',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _savePin,
                  child: const Text('Save PIN'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Performance',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Reduce motion in Messages',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Shorter animations and a smaller inline preview for smoother lists.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  value: _reduceMotion,
                  onChanged: (v) async {
                    setState(() => _reduceMotion = v);
                    await ChatPrivacyPreferences.setReduceUiMotion(v);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Release builds are much faster than debug. Test latency with '
                  '`flutter run --release` before judging server vs UI.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
