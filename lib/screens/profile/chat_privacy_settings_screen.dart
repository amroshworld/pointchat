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
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    if (!mounted) {
      return;
    }
    setState(() {
      _pinController.text = pin;
      _hasPin = pin.isNotEmpty;
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
      setState(() => _hasPin = raw.isNotEmpty);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.isEmpty
                ? 'PIN cleared. Locked chats now use biometric only.'
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
          'Chat Security',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Hint: Swipe a chat left to hide and lock, or right to delete.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _hasPin
                        ? Colors.green.withValues(alpha: 0.1)
                        : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hasPin
                          ? Colors.green.withValues(alpha: 0.3)
                          : scheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _hasPin
                              ? Colors.green.withValues(alpha: 0.2)
                              : scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _hasPin ? Icons.shield_rounded : Icons.shield_outlined,
                          color: _hasPin ? Colors.green : scheme.onSurfaceVariant,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _hasPin ? 'PIN Protection Active' : 'PIN Not Configured',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _hasPin ? Colors.green.shade600 : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _hasPin
                                  ? 'Your locked chats are secured.'
                                  : 'Set up a PIN to secure your locked chats.',
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
                const SizedBox(height: 24),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: 'PIN (4-8 digits)',
                    hintText: _hasPin ? '••••' : 'Enter a new PIN',
                    prefixIcon: const Icon(Icons.password_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                    suffixIcon: _hasPin
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _pinController.clear();
                              setState(() => _hasPin = false);
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() => _hasPin = value.isNotEmpty);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _savePin,
                    child: Text(_hasPin ? 'Update PIN' : 'Set PIN'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Swipe a chat left to blur and lock. Use biometrics or PIN to unlock.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}
