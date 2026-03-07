import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/user_avatar.dart';

class UserInfoScreen extends StatelessWidget {
  final String userId;

  const UserInfoScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userService = UserService();

    return Scaffold(
      appBar: AppBar(title: Text('User Info', style: GoogleFonts.spaceMono())),
      body: StreamBuilder<UserModel?>(
        stream: userService.getUserStream(userId),
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
