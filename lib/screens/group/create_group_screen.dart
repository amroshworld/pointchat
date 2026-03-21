import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import '../../utils/chat_image_upload.dart';
import '../../widgets/user_avatar.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;

  const CreateGroupScreen({super.key, required this.currentUserId});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GroupService _groupService = GroupService();
  final UserService _userService = UserService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedUserIds = {};
  final Map<String, UserModel> _selectedUsers = {};
  List<UserModel> _searchResults = [];
  bool _isCreating = false;
  bool _isPickingPhoto = false;
  String? _groupPhotoUrl;
  int _currentStep = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() => _searchResults = []);
      return;
    }
    final results = await _userService.searchUsers(
      query,
      widget.currentUserId,
      excludeNonHumanMembers: true,
    );
    if (!mounted) return;
    setState(() => _searchResults = results);
  }

  Future<void> _pickGroupPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final url = await pickAndUploadSquareChatImage(filePrefix: 'group');
      if (!mounted) return;
      if (url != null) setState(() => _groupPhotoUrl = url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not set group photo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  void _toggleUser(UserModel user) {
    if (user.isExcludedFromGroups) return;
    setState(() {
      if (_selectedUserIds.contains(user.uid)) {
        _selectedUserIds.remove(user.uid);
        _selectedUsers.remove(user.uid);
      } else {
        _selectedUserIds.add(user.uid);
        _selectedUsers[user.uid] = user;
      }
    });
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final groupId = await _groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: widget.currentUserId,
        members: _selectedUserIds.toList(),
        photoUrl: _groupPhotoUrl ?? '',
      );

      if (!mounted) return;

      // Navigate to the new group chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupId,
            groupName: _nameController.text.trim(),
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } catch (_) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not create the group right now. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        actions: [
          if (_currentStep == 1)
            TextButton.icon(
              onPressed: _isCreating ? null : _createGroup,
              icon: _isCreating
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_isCreating ? 'Creating...' : 'Create'),
            ),
        ],
      ),
      body: _currentStep == 0
          ? _buildMemberSelection(colorScheme)
          : _buildGroupDetails(colorScheme),
      bottomNavigationBar: _currentStep == 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _selectedUserIds.isEmpty
                      ? null
                      : () {
                          setState(() => _currentStep = 1);
                        },
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Next (${_selectedUserIds.length} selected)'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildMemberSelection(ColorScheme colorScheme) {
    return Column(
      children: [
        // Selected members chips
        if (_selectedUsers.isNotEmpty)
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _selectedUsers.length,
              itemBuilder: (context, index) {
                final user = _selectedUsers.values.elementAt(index);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          UserAvatar(
                            photoUrl: user.photoUrl,
                            name: user.displayName,
                            radius: 22,
                            isBot: user.isBot,
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: GestureDetector(
                              onTap: () => _toggleUser(user),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 10,
                                  color: colorScheme.onError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 56,
                        child: Text(
                          user.displayName.split(' ').first,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Divider
        if (_selectedUsers.isNotEmpty) const Divider(height: 1),

        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: _searchUsers,
            decoration: const InputDecoration(
              hintText: 'Search users to add...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),

        // User list
        Expanded(
          child: _searchResults.isNotEmpty
              ? ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isSelected = _selectedUserIds.contains(user.uid);

                    return ListTile(
                      leading: UserAvatar(
                        photoUrl: user.photoUrl,
                        name: user.displayName,
                        radius: 24,
                        isOnline: user.isOnline,
                        isBot: user.isBot,
                        showOnlineIndicator: true,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(user.email),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : Icon(
                              Icons.circle_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                      onTap: () => _toggleUser(user),
                    );
                  },
                )
              : _buildUserStream(colorScheme),
        ),
      ],
    );
  }

  Widget _buildUserStream(ColorScheme colorScheme) {
    return StreamBuilder<List<UserModel>>(
      stream: _userService.getAllUsers(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Text(
              'No users found',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          );
        }

        final users = snapshot.data!
            .where((u) => !u.isExcludedFromGroups)
            .toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final isSelected = _selectedUserIds.contains(user.uid);

            return ListTile(
              leading: UserAvatar(
                photoUrl: user.photoUrl,
                name: user.displayName,
                radius: 24,
                isOnline: user.isOnline,
                isBot: user.isBot,
                showOnlineIndicator: true,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(user.email),
              trailing: isSelected
                  ? Icon(Icons.check_circle, color: colorScheme.primary)
                  : Icon(
                      Icons.circle_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
              onTap: () => _toggleUser(user),
            );
          },
        );
      },
    );
  }

  Widget _buildGroupDetails(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group icon
          Center(
            child: GestureDetector(
              onTap: _isPickingPhoto ? null : _pickGroupPhoto,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 96,
                      height: 96,
                      color: colorScheme.tertiaryContainer,
                      child: _groupPhotoUrl != null && _groupPhotoUrl!.isNotEmpty
                          ? Image.network(
                              _groupPhotoUrl!,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.group,
                                size: 48,
                                color: colorScheme.onTertiaryContainer,
                              ),
                            )
                          : Icon(
                              Icons.group,
                              size: 48,
                              color: colorScheme.onTertiaryContainer,
                            ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colorScheme.surface, width: 2),
                      ),
                      child: _isPickingPhoto
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Group name
          Text(
            'Group name',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.text,
            decoration: const InputDecoration(
              hintText: 'Enter group name',
              prefixIcon: Icon(Icons.group_outlined),
            ),
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            'Description (optional)',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What\'s this group about?',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Selected members
          Text(
            'Members (${_selectedUsers.length + 1})',
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),

          // You
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
            ),
            title: const Text(
              'You',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: const Text('Admin'),
          ),

          // Selected members
          ..._selectedUsers.values.map((user) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(
                photoUrl: user.photoUrl,
                name: user.displayName,
                radius: 22,
                isBot: user.isBot,
              ),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(user.email),
              trailing: IconButton(
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: colorScheme.error,
                ),
                onPressed: () => _toggleUser(user),
              ),
            );
          }),

          const SizedBox(height: 24),

          // Create button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: _isCreating ? null : _createGroup,
              icon: _isCreating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isCreating ? 'Creating group...' : 'Create Group',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
