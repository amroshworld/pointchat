import 'dart:ui';

import 'package:flutter/material.dart';
import '../../appwrite_client.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../models/chat_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/app_theme.dart';
import '../../utils/chat_privacy_preferences.dart';

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
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _expandedChatId;
  final Set<String> _selectedChatIds = {};
  bool _isSelectionMode = false;
  Set<String> _lockedChatIds = {};

  Duration get _tileAnimDuration =>
      ChatPrivacyPreferences.reduceUiMotionListenable.value
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 250);

  int get _inlineMessageCap =>
      ChatPrivacyPreferences.reduceUiMotionListenable.value ? 12 : 25;

  // Render.com palette
  Color get _bgColor => Theme.of(context).scaffoldBackgroundColor;
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _expandedColor => Theme.of(context).colorScheme.primaryContainer;
  Color get _inputBgColor => Theme.of(context).colorScheme.primaryContainer;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textSecondary => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _accent => Theme.of(context).colorScheme.primary;
  Color get _bubbleMe =>
      Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
  Color get _bubbleOther => Theme.of(context).colorScheme.primaryContainer;

  @override
  void initState() {
    super.initState();
    _bootstrapPrivacy();
  }

  Future<void> _bootstrapPrivacy() async {
    await ChatPrivacyPreferences.syncLockedListenable();
    await ChatPrivacyPreferences.syncPerformanceListenable();
    ChatPrivacyPreferences.lockedChatsListenable.addListener(_onLockedChanged);
    ChatPrivacyPreferences.reduceUiMotionListenable.addListener(
      _onPerfChanged,
    );
    if (mounted) {
      setState(() {
        _lockedChatIds = Set<String>.from(
          ChatPrivacyPreferences.lockedChatsListenable.value,
        );
      });
    }
  }

  void _onLockedChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _lockedChatIds = Set<String>.from(
        ChatPrivacyPreferences.lockedChatsListenable.value,
      );
    });
  }

  void _onPerfChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    ChatPrivacyPreferences.lockedChatsListenable.removeListener(
      _onLockedChanged,
    );
    ChatPrivacyPreferences.reduceUiMotionListenable.removeListener(
      _onPerfChanged,
    );
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<bool> _verifyPrivacyUnlock() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (supported) {
        final authed = await _localAuth.authenticate(
          localizedReason: 'Unlock this chat',
        );
        if (authed) {
          return true;
        }
      }
    } catch (_) {}

    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    if (pin.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Set a backup PIN under Profile → Chats & performance.',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
      return false;
    }

    final entered = await _promptPinDialog();
    return entered != null && entered == pin;
  }

  Future<String?> _promptPinDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter PIN', style: GoogleFonts.inter()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(
            hintText: 'PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _toggleExpand(String chatId) async {
    if (_expandedChatId == chatId) {
      setState(() => _expandedChatId = null);
      return;
    }
    if (_lockedChatIds.contains(chatId)) {
      final ok = await _verifyPrivacyUnlock();
      if (!ok) {
        return;
      }
    }
    setState(() {
      _expandedChatId = chatId;
      _chatService.markMessagesAsRead(chatId, widget.currentUserId);
    });
  }

  void _toggleSelect(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
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

  Future<void> _applyLockToSelection(bool lock) async {
    for (final id in _selectedChatIds) {
      await ChatPrivacyPreferences.toggleLocked(id, lock);
    }
    await ChatPrivacyPreferences.syncLockedListenable();
    _clearSelection();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final senderName = cachedUserName;
    final senderPhoto = cachedUserPhotoUrl;

    _messageController.clear();

    if (_isSelectionMode && _selectedChatIds.isNotEmpty) {
      await Future.wait(
        _selectedChatIds.map(
          (chatId) => _chatService.sendMessage(
            chatId: chatId,
            senderId: widget.currentUserId,
            senderName: senderName,
            senderPhotoUrl: senderPhoto,
            text: text,
          ),
        ),
      );
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

  Future<bool> _confirmDeleteChat(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete chat?', style: GoogleFonts.inter()),
        content: Text(
          'Remove conversation with $title? Messages will be deleted.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

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
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(Icons.lock_outline, color: _textSecondary),
              tooltip: 'Lock selected',
              onPressed: _selectedChatIds.isEmpty
                  ? null
                  : () => _applyLockToSelection(true),
            ),
            IconButton(
              icon: Icon(Icons.lock_open, color: _textSecondary),
              tooltip: 'Unlock selected',
              onPressed: _selectedChatIds.isEmpty
                  ? null
                  : () => _applyLockToSelection(false),
            ),
            IconButton(
              icon: Icon(Icons.close, color: _textSecondary),
              onPressed: _clearSelection,
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<ChatModel>>(
            stream: _chatService.getUserChats(widget.currentUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _accent));
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

  Widget _buildConversationTile(ChatModel chat) {
    final otherUserId = chat.getOtherUserId(widget.currentUserId);
    final isExpanded = _expandedChatId == chat.chatId;
    final isSelected = _selectedChatIds.contains(chat.chatId);
    final unread = chat.unreadCount[widget.currentUserId] ?? 0;
    final locked = _lockedChatIds.contains(chat.chatId);
    final blurLocked = locked && !isExpanded;

    return StreamBuilder<UserModel?>(
      stream: _userService.getUserStream(otherUserId),
      builder: (context, snap) {
        final user = snap.data;

        final column = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    if (_isSelectionMode) ...[
                      GestureDetector(
                        onTap: () => _toggleSelect(chat.chatId),
                        child: AnimatedContainer(
                          duration: _tileAnimDuration,
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
                    UserAvatar(
                      photoUrl: user?.photoUrl,
                      name: user?.displayName ?? '?',
                      radius: 24,
                      isOnline: user?.isOnline ?? false,
                      showOnlineIndicator: true,
                    ),
                    const SizedBox(width: 14),
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
                              if (locked)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.lock_outline,
                                    size: 16,
                                    color: _textSecondary,
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
            AnimatedSize(
              duration: _tileAnimDuration,
              curve: Curves.easeInOut,
              child: isExpanded
                  ? _buildInlineMessages(chat.chatId)
                  : const SizedBox.shrink(),
            ),
          ],
        );

        final body = blurLocked
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: column,
                    ),
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.22),
                        child: Center(
                          child: Icon(
                            Icons.lock_outline,
                            color: _textSecondary.withValues(alpha: 0.9),
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : column;

        return Dismissible(
          key: ValueKey('dm-${chat.chatId}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            final name = user?.displayName ?? 'this chat';
            return _confirmDeleteChat(name);
          },
          onDismissed: (_) async {
            final participants = [widget.currentUserId, otherUserId];
            await _chatService.deleteChat(chat.chatId, participants);
            if (_expandedChatId == chat.chatId) {
              setState(() => _expandedChatId = null);
            }
            _selectedChatIds.remove(chat.chatId);
            await ChatPrivacyPreferences.toggleLocked(chat.chatId, false);
          },
          background: Container(
            alignment: Alignment.centerRight,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.shade800,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: AnimatedContainer(
            duration: _tileAnimDuration,
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
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: body,
          ),
        );
      },
    );
  }

  Widget _buildInlineMessages(String chatId) {
    return StreamBuilder<List<MessageModel>>(
      stream: _chatService.getChatMessages(chatId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'No messages yet',
                style: TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ),
          );
        }

        final messages =
            snapshot.data!.take(_inlineMessageCap).toList().reversed.toList();

        return Container(
          constraints: BoxConstraints(
            maxHeight: ChatPrivacyPreferences.reduceUiMotionListenable.value
                ? 220
                : 320,
          ),
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
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
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
                          style: TextStyle(
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
                              style: TextStyle(
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

  Widget _buildFloatingInput() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _inputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: TextField(
              controller: _messageController,
              focusNode: _focusNode,
              maxLines: null,
              enabled: _hasTarget,
              style: TextStyle(color: _textPrimary, fontSize: 15),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isSelectionMode
                    ? 'Broadcast to ${_selectedChatIds.length} chats…'
                    : _hasTarget
                        ? 'Type a message…'
                        : 'Select a chat first…',
                hintStyle: TextStyle(color: _textSecondary, fontSize: 15),
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
            duration: _tileAnimDuration,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _hasTarget
                  ? AppTheme.purple
                  : Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasTarget
                    ? AppTheme.purple
                    : Theme.of(context).colorScheme.outline,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: _textSecondary),
          const SizedBox(height: 16),
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
