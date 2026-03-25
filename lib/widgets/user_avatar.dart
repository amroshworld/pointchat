import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool showOnlineIndicator;
  final bool isBot;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.isBot = false,
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
            border: Border.all(
              color: isOnline
                  ? AppTheme.green
                  : Theme.of(context).colorScheme.outline,
              width: 1.5,
            ),
          ),
          child: ClipRect(
            child: isBot
                ? Center(
                    child: Icon(
                      Icons.smart_toy_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: radius * 1.05,
                    ),
                  )
                : (photoUrl != null && photoUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!,
                        width: radius * 2,
                        height: radius * 2,
                        fit: BoxFit.cover,
                        memCacheWidth: (radius *
                                2 *
                                MediaQuery.devicePixelRatioOf(context))
                            .toInt(),
                        memCacheHeight: (radius *
                                2 *
                                MediaQuery.devicePixelRatioOf(context))
                            .toInt(),
                        errorWidget: (context, url, error) =>
                            _buildFallbackText(context),
                      )
                    : _buildFallbackText(context),
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
                color: isOnline
                    ? AppTheme.green
                    : Theme.of(context).colorScheme.secondary,
                shape: BoxShape.rectangle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackText(BuildContext context) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
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
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.5,
        ),
      ),
      child: ClipRect(
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                memCacheWidth:
                    (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                        .toInt(),
                memCacheHeight:
                    (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                        .toInt(),
                errorWidget: (context, url, error) =>
                    _buildFallbackIcon(context),
              )
            : _buildFallbackIcon(context),
      ),
    );
  }

  Widget _buildFallbackIcon(BuildContext context) {
    return Center(
      child: Icon(Icons.group, color: AppTheme.green, size: radius),
    );
  }
}
