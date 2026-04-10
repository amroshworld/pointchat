import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../services/moderation_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ModerationService _moderationService = ModerationService.instance;
  final UserService _userService = UserService();

  Set<String> _blockedUserIds = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrapBlockedUsers();
  }

  @override
  void dispose() {
    _moderationService.blockedUserIdsListenable.removeListener(
      _onBlockedUsersChanged,
    );
    super.dispose();
  }

  Future<void> _bootstrapBlockedUsers() async {
    await _moderationService.initialize();
    if (!mounted) {
      return;
    }

    setState(() {
      _blockedUserIds = Set<String>.from(
        _moderationService.blockedUserIdsListenable.value,
      );
      _loading = false;
    });

    _moderationService.blockedUserIdsListenable.addListener(
      _onBlockedUsersChanged,
    );
  }

  void _onBlockedUsersChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _blockedUserIds = Set<String>.from(
        _moderationService.blockedUserIdsListenable.value,
      );
    });
  }

  Future<void> _unblockUser(String userId, String userLabel) async {
    await _moderationService.unblockUser(userId);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$userLabel has been unblocked.',
          style: GoogleFonts.inter(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final blockedList = _blockedUserIds.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : blockedList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.block,
                          size: 56,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No blocked users',
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'People you block will appear here so you can unblock them anytime.',
                          style: GoogleFonts.inter(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: blockedList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final blockedUserId = blockedList[index];
                    return FutureBuilder<UserModel?>(
                      future: _userService.getUserById(blockedUserId),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        final displayName = user?.displayName.isNotEmpty == true
                            ? user!.displayName
                            : blockedUserId;
                        final subtitleText = user?.email.isNotEmpty == true
                            ? user!.email
                            : blockedUserId;

                        return Card(
                          child: ListTile(
                            leading: UserAvatar(
                              photoUrl: user?.photoUrl,
                              name: displayName,
                              radius: 20,
                              isOnline: user?.isOnline ?? false,
                              showOnlineIndicator: false,
                            ),
                            title: Text(
                              displayName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              subtitleText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: FilledButton.tonal(
                              onPressed: () => _unblockUser(
                                blockedUserId,
                                displayName,
                              ),
                              child: const Text('Unblock'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
