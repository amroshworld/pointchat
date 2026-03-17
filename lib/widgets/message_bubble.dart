import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import 'voice_message_player.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final String senderName;
  final String? senderPhotoUrl;
  final DateTime? timestamp;
  final MessageType type;
  final bool isMe;
  final bool isGroup;
  final bool isSystem;
  final bool isRead;
  final bool showSenderName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.senderName,
    this.senderPhotoUrl,
    this.timestamp,
    this.type = MessageType.text,
    required this.isMe,
    this.isGroup = false,
    this.isSystem = false,
    this.isRead = false,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isSystem) {
      return _buildSystemMessage(context);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : 12,
        right: isMe ? 12 : 64,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isMe
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sender name (for group chats)
              if (showSenderName && !isMe)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    senderName,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Message Content
              if (type == MessageType.audio)
                VoiceMessagePlayer(
                  audioUrl:
                      message, // assuming message contains the URL for the audio
                  isMe: isMe,
                )
              else
                Text(
                  message,
                  style: TextStyle(
                    color: isMe
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

              const SizedBox(height: 4),

              // Time & read status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp != null
                        ? DateFormat('HH:mm').format(timestamp!)
                        : '',
                    style: TextStyle(
                      color: isMe
                          ? colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.6,
                            )
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead
                          ? colorScheme.primary
                          : colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.6,
                            ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 48),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.zero,
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class DateSeparator extends StatelessWidget {
  final DateTime date;

  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(messageDate).inDays;

    String text;
    if (difference == 0) {
      text = 'Today';
    } else if (difference == 1) {
      text = 'Yesterday';
    } else if (difference < 7) {
      text = DateFormat('EEEE').format(date);
    } else {
      text = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.zero,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
