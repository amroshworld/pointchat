import 'package:flutter/material.dart';
import '../../services/chat_service.dart';

class SeenMessageSettingsScreen extends StatefulWidget {
  final String userId;
  const SeenMessageSettingsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SeenMessageSettingsScreen> createState() =>
      _SeenMessageSettingsScreenState();
}

class _SeenMessageSettingsScreenState extends State<SeenMessageSettingsScreen> {
  final ChatService _chatService = ChatService();
  bool _loading = true;
  bool _saving = false;
  bool _seenEnabled = true;
  bool _notifyOnSeen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final seen = await _chatService.getDefaultSeenEnabledForMe();
    final notify = await _chatService.getDefaultNotifyOnSeenForMe();
    if (!mounted) return;
    setState(() {
      _seenEnabled = seen;
      _notifyOnSeen = notify;
      _loading = false;
    });
  }

  Future<void> _applyAll() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _chatService.setDefaultSeenEnabledForMe(_seenEnabled);
      await _chatService.setDefaultNotifyOnSeenForMe(_notifyOnSeen);
      await _chatService.applySeenEnabledToAllChats(
          widget.userId, _seenEnabled);
      await _chatService.applyNotifyOnSeenToAllChats(
        widget.userId,
        _notifyOnSeen,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seen settings saved for all chats.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update seen settings.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seen & read receipts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _seenEnabled,
                        title: const Text('Show my read receipts'),
                        subtitle: const Text(
                          'People can see when you read their messages.',
                        ),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _seenEnabled = v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        value: _notifyOnSeen,
                        title: const Text('Notify me when seen'),
                        subtitle: const Text(
                          'Get in-app alerts when someone sees your messages.',
                        ),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _notifyOnSeen = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'These defaults apply to new chats and can be pushed to all existing chats.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _applyAll,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.done_all),
                  label: Text(_saving ? 'Applying...' : 'Apply to all chats'),
                ),
              ],
            ),
    );
  }
}
