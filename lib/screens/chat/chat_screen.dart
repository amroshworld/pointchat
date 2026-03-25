import 'package:flutter/material.dart';
import '../../appwrite_client.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
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
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isComposing = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _chatService.markMessagesAsRead(widget.chatId, widget.currentUserId);
    _messageController.addListener(() {
      setState(() {
        _isComposing = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && !_isRecording) return;

    if (_isRecording) {
      setState(() {
        _isRecording = false;
      });
      // TODO: Implement actual voice note sending
      return;
    }

    _messageController.clear();

    final userName = cachedUserName;
    final userPhoto = cachedUserPhotoUrl;

    await _chatService.sendMessage(
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      senderName: userName,
      senderPhotoUrl: userPhoto,
      text: text,
    );
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
              stream: _chatService.getChatMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyChat();
                }

                final messages = snapshot.data!;

                // Mark messages as read
                _chatService.markMessagesAsRead(
                  widget.chatId,
                  widget.currentUserId,
                );

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
          _buildMessageInput(colorScheme),
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
                  title: const Text('View profile'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.wallpaper_outlined),
                  title: const Text('Wallpaper'),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text(
                    'Delete chat',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteChat();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete chat?'),
          content: const Text(
            'This will permanently delete all messages in this conversation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _chatService.deleteChat(widget.chatId, [
                  widget.currentUserId,
                  widget.otherUserId,
                ]);
                if (!context.mounted) return;
                Navigator.pop(context);
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
