import 'package:flutter/material.dart';
import '../../appwrite_client.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../utils/chat_image_upload.dart';
import '../../widgets/user_avatar.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final GroupService _groupService = GroupService();
  final UserService _userService = UserService();
  bool _uploadingGroupPhoto = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: StreamBuilder<GroupModel?>(
        stream: _groupService.getGroupStream(widget.groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final group = snapshot.data;
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }

          final isAdmin = group.admins.contains(widget.currentUserId);

          return CustomScrollView(
            slivers: [
              // App Bar with group photo
              SliverAppBar.large(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    group.name,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.tertiaryContainer,
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Center(
                      child: GestureDetector(
                        onTap: isAdmin && !_uploadingGroupPhoto
                            ? () => _changeGroupPhoto(group)
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            GroupAvatar(
                              photoUrl: group.photoUrl,
                              name: group.name,
                              radius: 48,
                            ),
                            if (isAdmin)
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colorScheme.surface,
                                      width: 2,
                                    ),
                                  ),
                                  child: _uploadingGroupPhoto
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onPrimary,
                                          ),
                                        )
                                      : Icon(
                                          Icons.camera_alt,
                                          size: 14,
                                          color: colorScheme.onPrimary,
                                        ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Group info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (group.description.isNotEmpty) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Description',
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  group.description,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Actions card
                      Card(
                        child: Column(
                          children: [
                            if (isAdmin)
                              ListTile(
                                leading: Icon(
                                  Icons.edit_outlined,
                                  color: colorScheme.primary,
                                ),
                                title: const Text('Edit group'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _editGroup(group),
                              ),
                            if (isAdmin)
                              ListTile(
                                leading: Icon(
                                  Icons.person_add_outlined,
                                  color: colorScheme.primary,
                                ),
                                title: const Text('Add members'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showAddMembers(group),
                              ),
                            ListTile(
                              leading: Icon(
                                Icons.exit_to_app,
                                color: colorScheme.error,
                              ),
                              title: Text(
                                'Leave group',
                                style: TextStyle(color: colorScheme.error),
                              ),
                              onTap: () => _confirmLeaveGroup(group),
                            ),
                            if (isAdmin)
                              ListTile(
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: colorScheme.error,
                                ),
                                title: Text(
                                  'Delete group',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                                onTap: () => _confirmDeleteGroup(group),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Members header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Members (${group.members.length})',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // Members list
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final memberId = group.members[index];
                  final isMemberAdmin = group.admins.contains(memberId);

                  return StreamBuilder<UserModel?>(
                    stream: _userService.getUserStream(memberId),
                    builder: (context, userSnapshot) {
                      final user = userSnapshot.data;
                      if (user == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: ListTile(
                            leading: UserAvatar(
                              photoUrl: user.photoUrl,
                              name: user.displayName,
                              radius: 22,
                              isOnline: user.isOnline,
                              showOnlineIndicator: true,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    memberId == widget.currentUserId
                                        ? '${user.displayName} (You)'
                                        : user.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isMemberAdmin)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Admin',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(user.email),
                            trailing:
                                isAdmin && memberId != widget.currentUserId
                                ? PopupMenuButton(
                                    itemBuilder: (_) => [
                                      if (!isMemberAdmin)
                                        const PopupMenuItem(
                                          value: 'make_admin',
                                          child: Text('Make admin'),
                                        ),
                                      if (isMemberAdmin)
                                        const PopupMenuItem(
                                          value: 'remove_admin',
                                          child: Text('Remove admin'),
                                        ),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          'Remove from group',
                                          style: TextStyle(
                                            color: colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      switch (value) {
                                        case 'make_admin':
                                          _groupService.makeAdmin(
                                            widget.groupId,
                                            memberId,
                                          );
                                          break;
                                        case 'remove_admin':
                                          _groupService.removeAdmin(
                                            widget.groupId,
                                            memberId,
                                          );
                                          break;
                                        case 'remove':
                                          _groupService.removeMember(
                                            widget.groupId,
                                            memberId,
                                            removedByName:
                                                cachedUserName.isNotEmpty
                                                    ? cachedUserName
                                                    : 'Admin',
                                            skipUnreadIncrementForActor:
                                                widget.currentUserId,
                                          );
                                          break;
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: group.members.length),
              ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _changeGroupPhoto(GroupModel group) async {
    setState(() => _uploadingGroupPhoto = true);
    try {
      final url = await pickAndUploadSquareChatImage(filePrefix: 'group');
      if (!mounted) return;
      if (url != null) {
        await _groupService.updateGroup(widget.groupId, {'photoUrl': url});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group photo updated.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update group photo. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingGroupPhoto = false);
    }
  }

  void _showAddMembers(GroupModel group) {
    final selected = <String>{};
    final searchController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Add members'),
              content: SizedBox(
                width: 320,
                height: 380,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by name or email',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: StreamBuilder<List<UserModel>>(
                        stream: _userService.getAllUsers(widget.currentUserId),
                        builder: (context, snap) {
                          final all = snap.data ?? [];
                          final q = searchController.text.trim().toLowerCase();
                          final list = all
                              .where(
                                (u) =>
                                    !u.isExcludedFromGroups &&
                                    u.uid != widget.currentUserId &&
                                    !group.members.contains(u.uid) &&
                                    !group.pendingMemberIds.contains(u.uid) &&
                                    (q.isEmpty ||
                                        u.displayName.toLowerCase().contains(
                                              q,
                                            ) ||
                                        u.email.toLowerCase().contains(q)),
                              )
                              .toList();
                          if (list.isEmpty) {
                            return Center(
                              child: Text(
                                'No people to add',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final user = list[i];
                              final on = selected.contains(user.uid);
                              return CheckboxListTile(
                                value: on,
                                onChanged: (v) {
                                  setDialogState(() {
                                    if (v == true) {
                                      selected.add(user.uid);
                                    } else {
                                      selected.remove(user.uid);
                                    }
                                  });
                                },
                                title: Text(user.displayName),
                                subtitle: Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: UserAvatar(
                                  photoUrl: user.photoUrl,
                                  name: user.displayName,
                                  radius: 20,
                                  isBot: user.isBot,
                                ),
                              );
                            },
                          );
                        },
                      ),
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
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          await _groupService.addMembers(
                            widget.groupId,
                            selected.toList(),
                            cachedUserName.isNotEmpty
                                ? cachedUserName
                                : 'Admin',
                            actorUserId: widget.currentUserId,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                  child: Text('Add (${selected.length})'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editGroup(GroupModel group) {
    final nameController = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group name',
                  prefixIcon: Icon(Icons.group_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _groupService.updateGroup(widget.groupId, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveGroup(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Leave group?'),
          content: const Text(
            'You will no longer receive messages from this group.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _groupService.leaveGroup(
                  widget.groupId,
                  widget.currentUserId,
                  'User',
                );
                if (!context.mounted) return;
                Navigator.pop(context); // Info screen
                Navigator.pop(context); // Chat screen
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteGroup(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete group?'),
          content: const Text(
            'This will permanently delete this group and all its messages for everyone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _groupService.deleteGroup(widget.groupId);
                if (!context.mounted) return;
                Navigator.pop(context); // Info screen
                Navigator.pop(context); // Chat screen
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
