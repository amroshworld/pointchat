import 'dart:math' as math;
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
            shape: BoxShape.circle,
            color: AppTheme.purpleDim,
            border: Border.all(
              color: isOnline
                  ? AppTheme.green
                  : Theme.of(context).colorScheme.outline,
              width: 1.5,
            ),
          ),
          child: ClipOval(
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
  final double onlinePercentage;

  const GroupAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.onlinePercentage = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final double normalizedPercentage = onlinePercentage.clamp(0.0, 1.0);

    Widget innerAvatar = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: ClipOval(
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

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(radius * 2),
            painter: _AvatarPresenceRingPainter(
              percentage: normalizedPercentage,
              color: AppTheme.green,
              trackColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
          innerAvatar,
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(BuildContext context) {
    return Center(
      child: Icon(Icons.group, color: AppTheme.green, size: radius),
    );
  }
}

class _AvatarPresenceRingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color trackColor;

  const _AvatarPresenceRingPainter({
    required this.percentage,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    final normalized = percentage.clamp(0.0, 1.0);
    final arcRect = (Offset.zero & size).deflate(strokeWidth / 2);
    final startAngle = -math.pi / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, trackPaint);

    if (normalized <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      arcRect,
      startAngle,
      math.pi * 2 * normalized,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPresenceRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
