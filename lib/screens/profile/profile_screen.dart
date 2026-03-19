import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:appwrite/appwrite.dart';
import 'package:uuid/uuid.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/subscription_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../appwrite_client.dart';
import '../subscription/ai_subscription_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final UserService _userService = UserService();
  bool _isUploading = false;

  Future<void> _updateProfilePicture(String uid) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      maxWidth: 1024,
      maxHeight: 1024,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF161618),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true),
      ],
    );
    if (croppedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = const Uuid().v4();
      final imageBytes = await XFile(croppedFile.path).readAsBytes();

      final file = await appwriteStorage.createFile(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: imageBytes, filename: '$fileName.jpg'),
        permissions: publicReadPermissions(),
      );

      final photoUrl = buildStoragePreviewUrl(
        file.$id,
        width: 320,
        height: 320,
      );

      await _userService.updateUserPhotoUrl(uid, photoUrl);
      final updatedUser = await _userService.getUserById(uid);
      if (updatedUser?.photoUrl != photoUrl) {
        throw Exception('Photo update not persisted in Appwrite user record.');
      }
      cachedUserPhotoUrl = photoUrl;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update picture: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authProvider);
    final authNotifier = ref.read(authProvider.notifier);

    if (cachedUserId.isEmpty) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserStream(cachedUserId),
        builder: (context, snapshot) {
          final userData = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.tertiaryContainer,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _updateProfilePicture(cachedUserId),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            UserAvatar(
                              photoUrl:
                                  userData?.photoUrl ?? cachedUserPhotoUrl,
                              name: userData?.displayName ?? cachedUserName,
                              radius: 48,
                              isOnline: true,
                              showOnlineIndicator: true,
                            ),
                            if (_isUploading)
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userData?.displayName ?? cachedUserName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        userData?.email ?? cachedUserEmail,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          userData?.status ?? 'Hey there! I am using PointChat',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settings cards
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.edit_outlined,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text('Edit Status'),
                        subtitle: Text(
                          userData?.status ?? 'Set your status',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _editStatus(cachedUserId, userData?.status ?? ''),
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: colorScheme.onPrimaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text('AI subscription'),
                        subtitle: ValueListenableBuilder<SubscriptionState>(
                          valueListenable: SubscriptionService.instance.state,
                          builder: (context, value, _) => Text(
                            value.hasAiAccess
                                ? 'Active'
                                : 'Required for all AI features',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder: (_) => const AiSubscriptionScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.dark_mode_outlined,
                            color: colorScheme.onSecondaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text('Theme'),
                        subtitle: const Text('System default'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Theme selector
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: colorScheme.onTertiaryContainer,
                            size: 20,
                          ),
                        ),
                        title: const Text('Notifications'),
                        subtitle: const Text('Enabled'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // TODO: Notification settings
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // About card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.info_outline,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        title: const Text('About PointChat'),
                        subtitle: const Text('Version 1.0.0'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'PointChat',
                            applicationVersion: '1.0.0',
                            applicationIcon: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.chat_rounded,
                                color: colorScheme.onPrimary,
                                size: 24,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Sign out
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Sign out?'),
                                content: const Text(
                                  'You will need to sign in again to access your chats.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await authNotifier.signOut();
                            }
                          },
                    icon: authState.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.error,
                            ),
                          )
                        : Icon(Icons.logout, color: colorScheme.error),
                    label: Text(
                      authState.isLoading ? 'Signing out...' : 'Sign Out',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  void _editStatus(String uid, String currentStatus) {
    final controller = TextEditingController(text: currentStatus);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Status'),
          content: TextField(
            controller: controller,
            maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What\'s on your mind?',
              prefixIcon: Icon(Icons.mood_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await _userService.updateStatus(uid, controller.text.trim());
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
