import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/user_service.dart';
import '../../services/chat_service.dart';
import '../../services/moderation_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
import '../chat/chat_screen.dart';
import 'user_info_screen.dart';

class PeopleScreen extends StatefulWidget {
  final String currentUserId;

  const PeopleScreen({super.key, required this.currentUserId});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();
  final ModerationService _moderationService = ModerationService.instance;
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  Set<String> _blockedUserIds = <String>{};

  @override
  void initState() {
    super.initState();
    _moderationService.initialize();
    _blockedUserIds = Set<String>.from(
      _moderationService.blockedUserIdsListenable.value,
    );
    _moderationService.blockedUserIdsListenable.addListener(
      _onBlockedUsersChanged,
    );
  }

  @override
  void dispose() {
    _moderationService.blockedUserIdsListenable.removeListener(
      _onBlockedUsersChanged,
    );
    _searchController.dispose();
    super.dispose();
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

  void _openUserInfo(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserInfoScreen(userId: userId)),
    );
  }

  void _openChat(UserModel user) async {
    if (_blockedUserIds.contains(user.uid)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This user is blocked. Open user settings to unblock before chatting.',
          ),
        ),
      );
      return;
    }

    final chatId = await _chatService.getOrCreateChat(
      widget.currentUserId,
      user.uid,
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: chatId,
          otherUserId: user.uid,
          otherUserName: user.displayName,
          otherUserPhotoUrl: user.photoUrl,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<List<UserModel>>(
          stream: _userService.getAllUsers(widget.currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading users',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final allUsers = snapshot.data ?? [];
            final visibleUsers = allUsers
                .where((u) => !_blockedUserIds.contains(u.uid))
                .toList();

            // Client-side filter
            final users = _searchQuery.isEmpty
                ? visibleUsers
                : visibleUsers
                    .where(
                      (u) =>
                          u.displayName.toLowerCase().contains(
                                _searchQuery,
                              ) ||
                          u.email.toLowerCase().contains(_searchQuery),
                    )
                    .toList();

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  floating: true,
                  snap: true,
                  title: Text(
                    'People',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (_searchQuery.isEmpty && visibleUsers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Favorites',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 85,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: visibleUsers.take(6).length,
                              itemBuilder: (context, index) {
                                final user = visibleUsers[index];
                                return GestureDetector(
                                  onTap: () => _openChat(user),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      children: [
                                        UserAvatar(
                                          photoUrl: user.photoUrl,
                                          name: user.displayName,
                                          radius: 28,
                                          isOnline: user.isOnline,
                                          showOnlineIndicator: true,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          user.displayName.split(' ').first,
                                          style: GoogleFonts.inter(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (visibleUsers.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No other users yet',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Signed-in users will appear here',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (users.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_search_outlined,
                            size: 64,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users match "$_searchQuery"',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final user = users[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outline),
                          ),
                          child: ListTile(
                            onTap: () => _openUserInfo(user.uid),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            leading: UserAvatar(
                              photoUrl: user.photoUrl,
                              name: user.displayName,
                              radius: 24,
                              isOnline: user.isOnline,
                              showOnlineIndicator: true,
                            ),
                            title: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              user.email,
                              style: GoogleFonts.inter(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            trailing: TextButton.icon(
                              onPressed: () => _openChat(user),
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                                size: 14,
                                color: AppTheme.purpleLt,
                              ),
                              label: Text(
                                'Chat',
                                style: GoogleFonts.inter(
                                  color: AppTheme.purpleLt,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                backgroundColor: AppTheme.purpleGlow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        );
                      }, childCount: users.length),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
