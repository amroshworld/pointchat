import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../appwrite_client.dart';
import '../../models/user_model.dart';
import '../../services/moderation_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';

class UserInfoScreen extends StatefulWidget {
  final String userId;

  const UserInfoScreen({super.key, required this.userId});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final UserService _userService = UserService();
  final ModerationService _moderationService = ModerationService.instance;

  bool get _isSelf => widget.userId == cachedUserId;
  bool get _isBlocked => _moderationService.isBlocked(widget.userId);

  @override
  void initState() {
    super.initState();
    _moderationService.initialize();
    _moderationService.blockedUserIdsListenable.addListener(_onBlockedChanged);
  }

  @override
  void dispose() {
    _moderationService.blockedUserIdsListenable.removeListener(
      _onBlockedChanged,
    );
    super.dispose();
  }

  void _onBlockedChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _toggleBlock(UserModel user) async {
    if (_isSelf) {
      return;
    }

    if (_isBlocked) {
      await _moderationService.unblockUser(user.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.displayName} has been unblocked.')),
      );
      return;
    }

    await _moderationService.blockUser(user.uid);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.displayName} has been blocked.')),
    );
  }

  Future<void> _reportUser(UserModel user) async {
    if (_isSelf) {
      return;
    }

    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Spam, harassment, abusive content',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason.')),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(<String, String>{
                  'reason': reason,
                  'details': detailsController.text.trim(),
                });
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    detailsController.dispose();

    if (result == null) {
      return;
    }

    await _moderationService.submitUserReport(
      reporterUserId: cachedUserId,
      targetUserId: user.uid,
      reason: result['reason'] ?? '',
      details: result['details'] ?? '',
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('User Info', style: GoogleFonts.spaceMono())),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            return Center(
              child: Text(
                'User not found',
                style: GoogleFonts.jetBrainsMono(color: colorScheme.onSurface),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      UserAvatar(
                        photoUrl: user.photoUrl,
                        name: user.displayName,
                        radius: 48,
                        isOnline: user.isOnline,
                        showOnlineIndicator: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: GoogleFonts.spaceMono(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: GoogleFonts.jetBrainsMono(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.onSurface.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          user.status,
                          style: GoogleFonts.spaceGrotesk(
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (!_isSelf) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _toggleBlock(user),
                                icon: Icon(
                                  _isBlocked
                                      ? Icons.person_add_alt_1_outlined
                                      : Icons.block_outlined,
                                ),
                                label: Text(
                                  _isBlocked ? 'Unblock user' : 'Block user',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _reportUser(user),
                                icon: const Icon(Icons.report_outlined),
                                label: const Text('Report user'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
