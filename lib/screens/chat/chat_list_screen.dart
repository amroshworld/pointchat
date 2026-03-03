import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';

class ChatListScreen extends StatefulWidget {
  final String currentUserId;

  const ChatListScreen({super.key, required this.currentUserId});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String? _expandedChatId;
  final Set<String> _selectedChatIds = {};
  bool _isSelectionMode = false;

  // Render.com palette
  static const _bgColor = AppTheme.bg;
  static const _surfaceColor = AppTheme.surface;
  static const _expandedColor = AppTheme.surface2;
  static const _inputBgColor = AppTheme.surface2;
  static const _textPrimary = AppTheme.textPri;
  static const _textSecondary = AppTheme.textSec;
  static const _accent = AppTheme.purple;
  static const _bubbleMe = AppTheme.purpleDim;
  static const _bubbleOther = AppTheme.surface2;

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleExpand(String chatId) {
    setState(() {
      if (_expandedChatId == chatId) {
        _expandedChatId = null;
      } else {
        _expandedChatId = chatId;
        _chatService.markMessagesAsRead(chatId, widget.currentUserId);
      }
    });
  }

  void _toggleSelect(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedChatIds.add(chatId);
        _isSelectionMode = true;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedChatIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    final senderName = user?.displayName ?? 'User';
    final senderPhoto = user?.photoURL ?? '';

    _messageController.clear();

    if (_isSelectionMode && _selectedChatIds.isNotEmpty) {
      for (final chatId in _selectedChatIds) {
        await _chatService.sendMessage(
          chatId: chatId,
          senderId: widget.currentUserId,
          senderName: senderName,
          senderPhotoUrl: senderPhoto,
          text: text,
        );
      }
      _clearSelection();
    } else if (_expandedChatId != null) {
      await _chatService.sendMessage(
        chatId: _expandedChatId!,
        senderId: widget.currentUserId,
        senderName: senderName,
        senderPhotoUrl: senderPhoto,
        text: text,
      );
    }
  }

  bool get _hasTarget => _expandedChatId != null || _selectedChatIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isSelectionMode ? '${_selectedChatIds.length} selected' : 'Messages',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close, color: _textSecondary),
              onPressed: _clearSelection,
            ),
        ],
      ),
      body: Stack(
        children: [
          // Conversation list
          StreamBuilder<List<ChatModel>>(
            stream: _chatService.getUserChats(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }
              final chats = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                itemCount: chats.length,
                itemBuilder: (context, index) =>
                    _buildConversationTile(chats[index]),
              );
            },
          ),

          // Floating input
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 12,
            child: _buildFloatingInput(),
          ),
        ],
      ),
    );
  }

  // ── Conversation tile ──────────────────────────────────────────────
  Widget _buildConversationTile(ChatModel chat) {
    final otherUserId = chat.getOtherUserId(widget.currentUserId);
    final isExpanded = _expandedChatId == chat.chatId;
    final isSelected = _selectedChatIds.contains(chat.chatId);
    final unread = chat.unreadCount[widget.currentUserId] ?? 0;

    return StreamBuilder<UserModel?>(
      stream: _userService.getUserStream(otherUserId),
      builder: (context, snap) {
        final user = snap.data;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.purpleGlow
                : isExpanded
                ? _expandedColor
                : _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.purple
                  : isExpanded
                  ? AppTheme.border
                  : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header row ──
              InkWell(
                onTap: () => _toggleExpand(chat.chatId),
                onLongPress: () => _toggleSelect(chat.chatId),
                borderRadius: BorderRadius.circular(18),
                splashColor: Colors.white10,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Selection indicator
                      if (_isSelectionMode) ...[
                        GestureDetector(
                          onTap: () => _toggleSelect(chat.chatId),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? _accent : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? _accent : _textSecondary,
                                width: 1.8,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.black,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Avatar
                      UserAvatar(
                        photoUrl: user?.photoUrl,
                        name: user?.displayName ?? '?',
                        radius: 24,
                        isOnline: user?.isOnline ?? false,
                        showOnlineIndicator: true,
                      ),
                      const SizedBox(width: 14),

                      // Name + preview
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    user?.displayName ?? '...',
                                    style: TextStyle(
                                      color: _textPrimary,
                                      fontSize: 15,
                                      fontWeight: unread > 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (chat.lastMessageTime != null)
                                  Text(
                                    timeago.format(
                                      chat.lastMessageTime!,
                                      locale: 'en_short',
                                    ),
                                    style: TextStyle(
                                      color: unread > 0
                                          ? _textPrimary
                                          : _textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat.lastMessage.isEmpty
                                        ? 'No messages yet'
                                        : chat.lastMessage,
                                    style: TextStyle(
                                      color: unread > 0
                                          ? _textPrimary.withValues(alpha: 0.8)
                                          : _textSecondary,
                                      fontSize: 13,
                                      fontWeight: unread > 0
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (unread > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.purple,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unread > 99 ? '99+' : '$unread',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 4),
                                Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: _textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Expanded messages ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: isExpanded
                    ? _buildInlineMessages(chat.chatId)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Inline messages inside expanded tile ───────────────────────────
  Widget _buildInlineMessages(String chatId) {
    return StreamBuilder<List<MessageModel>>(
      stream: _chatService.getChatMessages(chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ),
          );
        }

        final messages = snapshot.data!.take(25).toList().reversed.toList();

        return Container(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isMe = msg.senderId == widget.currentUserId;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.58,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? _bubbleMe : _bubbleOther,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe
                            ? const Radius.circular(16)
                            : const Radius.circular(4),
                        bottomRight: isMe
                            ? const Radius.circular(4)
                            : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: const TextStyle(
                            color: _textPrimary,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.timestamp != null
                                  ? DateFormat('HH:mm').format(msg.timestamp!)
                                  : '',
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 3),
                              Icon(
                                msg.isRead ? Icons.done_all : Icons.done,
                                size: 13,
                                color: msg.isRead ? _accent : _textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Floating input ─────────────────────────────────────────────────
  Widget _buildFloatingInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: null,
              enabled: _hasTarget,
              style: const TextStyle(color: _textPrimary, fontSize: 15),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isSelectionMode
                    ? 'Broadcast to ${_selectedChatIds.length} chats…'
                    : _hasTarget
                    ? 'Type a message…'
                    : 'Select a chat first…',
                hintStyle: const TextStyle(color: _textSecondary, fontSize: 15),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _hasTarget ? _sendMessage : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hasTarget ? AppTheme.purple : AppTheme.surface2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasTarget ? AppTheme.purple : AppTheme.border,
              ),
            ),
            child: Icon(
              Icons.send_rounded,
              color: _hasTarget ? Colors.white : _textSecondary,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ── Empty state ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary),
          SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start chatting from the People tab',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
