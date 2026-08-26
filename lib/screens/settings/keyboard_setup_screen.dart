import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/quick_reply_model.dart';
import '../../services/keyboard_bridge_service.dart';

class KeyboardSetupScreen extends StatefulWidget {
  const KeyboardSetupScreen({super.key});

  @override
  State<KeyboardSetupScreen> createState() => _KeyboardSetupScreenState();
}

class _KeyboardSetupScreenState extends State<KeyboardSetupScreen> {
  final _bridgeService = KeyboardBridgeService.instance;
  final TextEditingController _testInputController = TextEditingController();
  List<QuickReplyModel> _quickReplies = [];
  bool _isLoading = true;
  bool? _isKeyboardEnabled;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _testInputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final replies = await _bridgeService.getQuickReplies();
    bool? enabled;
    if (!kIsWeb) {
      enabled = await _bridgeService.isKeyboardEnabled();
    }
    if (mounted) {
      setState(() {
        _quickReplies = replies;
        _isKeyboardEnabled = enabled;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddOrEditDialog({QuickReplyModel? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final textController = TextEditingController(text: existing?.text ?? '');
    String category = existing?.category ?? 'General';

    final result = await showDialog<QuickReplyModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Add Quick Reply' : 'Edit Quick Reply'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Button Label / Shortcut',
                    hintText: "e.g., On my way!",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Full Message Text',
                    hintText: "e.g., I'm on my way! Will be there shortly.",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'General', child: Text('General')),
                    DropdownMenuItem(value: 'Status', child: Text('Status')),
                    DropdownMenuItem(value: 'Quick', child: Text('Quick')),
                    DropdownMenuItem(value: 'Work', child: Text('Work')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => category = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final t = titleController.text.trim();
                final body = textController.text.trim();
                if (t.isEmpty || body.isEmpty) return;
                final id = existing?.id ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
                Navigator.pop(
                  ctx,
                  QuickReplyModel(
                    id: id,
                    title: t,
                    text: body,
                    category: category,
                    order: existing?.order ?? _quickReplies.length + 1,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      if (existing != null) {
        final index = _quickReplies.indexWhere((r) => r.id == existing.id);
        if (index != -1) {
          final updated = List<QuickReplyModel>.from(_quickReplies)..[index] = result;
          await _bridgeService.saveQuickReplies(updated);
        }
      } else {
        await _bridgeService.addQuickReply(result);
      }
      _loadData();
    }
  }

  Future<void> _deleteReply(String id) async {
    await _bridgeService.deleteQuickReply(id);
    _loadData();
  }

  Future<void> _resetDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Quick Replies?'),
        content: const Text(
          'This will restore the original default canned messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _bridgeService.saveQuickReplies(QuickReplyModel.defaultReplies());
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PointChat Keyboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Status',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Banner
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.keyboard_outlined,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Easy Chat System Keyboard',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Chat with your PointChat contacts directly from inside ANY app on your device (WhatsApp, Safari, Notes, etc.) without leaving your current screen.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Chip(
                              avatar: const Icon(Icons.flash_on, size: 16),
                              label: const Text('Instant Chat Bar'),
                              visualDensity: VisualDensity.compact,
                            ),
                            const SizedBox(width: 8),
                            Chip(
                              avatar: const Icon(Icons.language, size: 16),
                              label: const Text('Gboard 1-Tap Switch'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Setup Guide
                Text(
                  'Activation & Setup',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                _buildSetupStep(
                  step: '1',
                  title: _isKeyboardEnabled == true
                      ? 'PointChat Keyboard (Enabled ✓)'
                      : 'Enable PointChat Keyboard',
                  description: !kIsWeb && Platform.isIOS
                      ? 'Go to iOS Settings → Keyboards → Turn on "PointChat Keyboard"'
                      : 'Go to System Settings → System → Languages & Input → Manage Keyboards → Turn on "PointChat Keyboard"',
                  actionButton: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _bridgeService.openSystemKeyboardSettings(),
                        icon: Icon(
                          _isKeyboardEnabled == true
                              ? Icons.check_circle_outline
                              : Icons.settings,
                          size: 18,
                          color: _isKeyboardEnabled == true ? Colors.green : null,
                        ),
                        label: Text(
                          _isKeyboardEnabled == true
                              ? 'Manage Keyboards'
                              : 'Open System Settings',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _bridgeService.showInputMethodPicker(),
                        icon: const Icon(Icons.keyboard, size: 18),
                        label: const Text('Switch / Pick Keyboard'),
                      ),
                    ],
                  ),
                ),

                if (!kIsWeb && Platform.isIOS) ...[
                  const SizedBox(height: 12),
                  _buildSetupStep(
                    step: '2',
                    title: 'Allow Full Access (iOS)',
                    description:
                        'Tap "PointChat Keyboard" in settings and toggle "Allow Full Access" ON. This is required so the keyboard can send messages via Appwrite over the internet.',
                  ),
                ],

                const SizedBox(height: 12),
                _buildSetupStep(
                  step: !kIsWeb && Platform.isIOS ? '3' : '2',
                  title: 'Switch Keyboards Anytime',
                  description:
                      'Tap the Globe (🌐) icon or Keyboard Switcher key on the keyboard to instantly swap back to Gboard or standard keyboard.',
                ),

                const SizedBox(height: 24),

                // Interactive Test Sandbox
                Text(
                  'Keyboard Sandbox / Test Area',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tap the box below to bring up the keyboard and test typing or quick sending:',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _testInputController,
                          decoration: InputDecoration(
                            hintText: 'Tap here to open keyboard...',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _testInputController.clear(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Replies Manager
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Custom Quick Replies',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddOrEditDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add New'),
                    ),
                  ],
                ),
                Text(
                  'These canned messages appear in the quick replies bar above your keyboard for instant 1-tap sending.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 8),

                if (_quickReplies.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('No custom quick replies configured yet.'),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _resetDefaults,
                            child: const Text('Restore Default Replies'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ...List.generate(_quickReplies.length, (index) {
                    final reply = _quickReplies[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            reply.category.isNotEmpty
                                ? reply.category[0].toUpperCase()
                                : 'Q',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          reply.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          reply.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAddOrEditDialog(existing: reply),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteReply(reply.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetDefaults,
                      child: const Text('Restore Defaults'),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildSetupStep({
    required String step,
    required String title,
    required String description,
    Widget? actionButton,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              step,
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  ),
                ),
                if (actionButton != null) ...[
                  const SizedBox(height: 8),
                  actionButton,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
