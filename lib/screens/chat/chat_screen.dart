import 'dart:async';

import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import '../../appwrite_client.dart';
import '../../services/chat_service.dart';
import '../../services/moderation_service.dart';
import '../../services/user_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../people/user_info_screen.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/user_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String currentUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    required this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final ModerationService _moderationService = ModerationService.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isComposing = false;
  bool _isRecording = false;
  bool _isBlockedUser = false;
  final List<MessageModel> _optimisticMessages = [];
  late final Stream<List<MessageModel>> _messagesStream;
  StreamSubscription<List<MessageModel>>? _messagesSub;

  @override
  void initState() {
    super.initState();
    _messagesStream =
        _chatService.getChatMessages(widget.chatId).asBroadcastStream();
    _messagesSub = _messagesStream.listen((messages) {
      final hasUnreadFromOthers = messages.any(
        (m) =>
            m.senderId != widget.currentUserId &&
            !(m.readBy[widget.currentUserId] ?? false),
      );
      if (hasUnreadFromOthers) {
        _chatService.markMessagesAsRead(widget.chatId, widget.currentUserId);
      }
    });
    _bootstrapModeration();
    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  Future<void> _bootstrapModeration() async {
    await _moderationService.initialize();
    _isBlockedUser = _moderationService.isBlocked(widget.otherUserId);
    _moderationService.blockedUserIdsListenable.addListener(
      _onBlockedUsersChanged,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _onBlockedUsersChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _isBlockedUser = _moderationService.isBlocked(widget.otherUserId);
    });
  }

  Future<void> _toggleBlockFromChat() async {
    if (_isBlockedUser) {
      await _moderationService.unblockUser(widget.otherUserId);
    } else {
      await _moderationService.blockUser(widget.otherUserId);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isBlockedUser = _moderationService.isBlocked(widget.otherUserId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBlockedUser
              ? 'User blocked. Messages are now restricted.'
              : 'User unblocked.',
        ),
      ),
    );
  }

  Future<void> _reportUserFromChat() async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Report user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Spam, harassment, abusive content',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason.')),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop(<String, String>{
                  'reason': reason,
                  'details': detailsController.text.trim(),
                });
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    reasonController.dispose();
    detailsController.dispose();

    if (result == null) {
      return;
    }

    await _moderationService.submitUserReport(
      reporterUserId: widget.currentUserId,
      targetUserId: widget.otherUserId,
      reason: result['reason'] ?? '',
      details: result['details'] ?? '',
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted. Thank you.')),
    );
  }

  void _openUserDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserInfoScreen(userId: widget.otherUserId),
      ),
    );
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _moderationService.blockedUserIdsListenable.removeListener(
      _onBlockedUsersChanged,
    );
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_isBlockedUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You blocked this user. Unblock to send messages.'),
        ),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty && !_isRecording) return;

    if (_isRecording) {
      setState(() {
        _isRecording = false;
      });
      // TODO: Implement actual voice note sending
      return;
    }

    final userName = cachedUserName;
    final userPhoto = cachedUserPhotoUrl;
    final messageId = ID.unique();

    // Immediately add optimistic message and clear input
    final optimisticMsg = MessageModel(
      messageId: messageId,
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      senderName: userName,
      senderPhotoUrl: userPhoto,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    setState(() {
      _optimisticMessages.add(optimisticMsg);
    });
    _messageController.clear();

    // Send in background without awaiting
    _chatService
        .sendMessage(
      messageId: messageId,
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      senderName: userName,
      senderPhotoUrl: userPhoto,
      text: text,
    )
        .then((_) {
      // Success - remove from optimistic messages
      // The realtime will bring in the real message
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.messageId == messageId);
        });
      }
    }).catchError((e) {
      // Failure - remove the optimistic message (user can retry)
      debugPrint('Failed to send message: $e');
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.messageId == messageId);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<UserModel?>(
          stream: _userService.getUserStream(widget.otherUserId),
          builder: (context, snapshot) {
            final user = snapshot.data;
            final isOnline = user?.isOnline ?? false;

            return Row(
              children: [
                UserAvatar(
                  photoUrl: user?.photoUrl ?? widget.otherUserPhotoUrl,
                  name: user?.displayName ?? widget.otherUserName,
                  radius: 20,
                  isOnline: isOnline,
                  showOnlineIndicator: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? widget.otherUserName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline
                              ? const Color(0xFF4CAF50)
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showChatOptions(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final serverMessages = snapshot.data ?? [];
                final serverMessageIds =
                    serverMessages.map((m) => m.messageId).toSet();

                final pendingMessages = _optimisticMessages
                    .where((m) => !serverMessageIds.contains(m.messageId))
                    .toList();

                final messages = <MessageModel>[
                  ...pendingMessages.reversed,
                  ...serverMessages,
                ];

                if (messages.isEmpty &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (messages.isEmpty) {
                  return _buildEmptyChat();
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == widget.currentUserId;
                    final showDate = index == messages.length - 1 ||
                        !_isSameDay(
                          message.timestamp,
                          messages[index + 1].timestamp,
                        );

                    return Column(
                      children: [
                        if (showDate && message.timestamp != null)
                          DateSeparator(date: message.timestamp!),
                        MessageBubble(
                          message: message.text,
                          senderName: message.senderName,
                          timestamp: message.timestamp,
                          type: message.type,
                          isMe: isMe,
                          isSystem: message.type == MessageType.system,
                          isRead: message.isRead,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Message Input
          _isBlockedUser
              ? _buildBlockedComposerNotice(colorScheme)
              : _buildMessageInput(colorScheme),
        ],
      ),
    );
  }

  Widget _buildBlockedComposerNotice(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.block_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You blocked this user. Unblock to continue chatting.',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: _openUserDetails,
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          IconButton(
            icon: Icon(
              Icons.add_circle_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            onPressed: () {
              // TODO: Add attachment options
            },
          ),

          // Text field or Recording Indicator
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: _isRecording
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.only(left: 16, right: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'select target',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.send_rounded,
                              color: colorScheme.onErrorContainer,
                            ),
                            onPressed: () {
                              setState(() {
                                _isRecording = false;
                              });
                              // TODO: Implement actual voice note sending
                            },
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 10,
                          bottom: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
            ),
          ),

          const SizedBox(width: 4),

          // Action button ALWAYS visible outside
          Container(
            decoration: BoxDecoration(
              color: _isRecording ? colorScheme.error : colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isRecording
                    ? Icons.stop
                    : (_isComposing ? Icons.send_rounded : Icons.mic),
                color:
                    _isRecording ? colorScheme.onError : colorScheme.onPrimary,
              ),
              onPressed: () {
                if (_isRecording) {
                  setState(() {
                    _isRecording = false;
                  });
                  // TODO: stop recording and send voice note
                } else if (_isComposing) {
                  _sendMessage();
                } else {
                  setState(() {
                    _isRecording = true;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.waving_hand_outlined,
              size: 40,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Say hello! 👋',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send your first message to\n${widget.otherUserName}',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('View details'),
                  onTap: () {
                    Navigator.pop(context);
                    _openUserDetails();
                  },
                ),
                ListTile(
                  leading: Icon(
                    _isBlockedUser
                        ? Icons.person_add_alt_1_outlined
                        : Icons.block_outlined,
                  ),
                  title: Text(_isBlockedUser ? 'Unblock user' : 'Block user'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _toggleBlockFromChat();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_outlined),
                  title: const Text('Report user'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _reportUserFromChat();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: const Text('Wallpaper'),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
