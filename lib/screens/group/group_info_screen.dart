import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../../models/group_model.dart';
import '../../models/user_model.dart';
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
                      child: GroupAvatar(
                        photoUrl: group.photoUrl,
                        name: group.name,
                        radius: 48,
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
                                onTap: () {
                                  // TODO: Add members dialog
                                },
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
                await _groupService.deleteGroup(widget.groupId, group.members);
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
