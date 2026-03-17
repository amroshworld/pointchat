import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool showOnlineIndicator;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.isOnline = false,
    this.showOnlineIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            color: AppTheme.purpleDim,
            border: Border.all(color: AppTheme.border, width: 1.5),
          ),
          child: ClipRect(
            child: (photoUrl != null && photoUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: photoUrl!,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => _buildFallbackText(),
                  )
                : _buildFallbackText(),
          ),
        ),
        if (showOnlineIndicator)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: isOnline ? AppTheme.green : AppTheme.muted,
                shape: BoxShape.rectangle,
                border: Border.all(color: AppTheme.bg, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackText() {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: AppTheme.textPri,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class GroupAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;

  const GroupAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: AppTheme.surface2,
        border: Border.all(color: AppTheme.border, width: 1.5),
      ),
      child: ClipRect(
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => _buildFallbackIcon(),
              )
            : _buildFallbackIcon(),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Center(
      child: Icon(Icons.group, color: AppTheme.green, size: radius),
    );
  }
}
