import '../../widgets/pixel_symbol.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:appwrite/appwrite.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../appwrite_client.dart';
import '../../services/auth_service.dart';
import '../../services/cache_service.dart';
import '../../services/ai_service.dart';
import '../../services/notification_service.dart';
import '../../services/subscription_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../services/invite_service.dart';
import '../../services/user_service.dart';
import '../../services/bot_service.dart';
import '../../models/group_model.dart';
import '../../models/bot_model.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../subscription/ai_subscription_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/voice_message_player.dart';
import '../../utils/pointchat_tips.dart';
import '../../utils/composer_preferences.dart';
import '../../utils/chat_image_upload.dart';
import '../../utils/group_handle_resolver.dart';
import '../../utils/chat_privacy_preferences.dart';

/// Shown when typing `@` so features like `@ai` are discoverable.
class _AtCommandSuggestion {
  final String insertStem;
  final String label;
  final String hint;
  const _AtCommandSuggestion({
    required this.insertStem,
    required this.label,
    required this.hint,
  });
}

const _kAtCommandHints = <_AtCommandSuggestion>[
  _AtCommandSuggestion(
    insertStem: 'ai ',
    label: '@ai',
    hint: 'PointChat AI — private notes thread (use /newbot for custom bots)',
  ),
];

class UnifiedStreamScreen extends ConsumerStatefulWidget {
  final String currentUserId;
  const UnifiedStreamScreen({super.key, required this.currentUserId});

  @override
  ConsumerState<UnifiedStreamScreen> createState() =>
      _UnifiedStreamScreenState();
}

// Settings data holder for /setting overlay
class _MySettingsState {
  bool seenEnabled;
  bool notifyOnSeen;
  String privacyPin;
  bool tipsHidden;
  ThemeMode themeMode;

  _MySettingsState({
    this.seenEnabled = true,
    this.notifyOnSeen = false,
    this.privacyPin = '',
    this.tipsHidden = false,
    this.themeMode = ThemeMode.system,
  });
}

class _UnifiedStreamScreenState extends ConsumerState<UnifiedStreamScreen>
    with WidgetsBindingObserver {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocusNode = FocusNode();

  final _chatService = ChatService();
  final _groupService = GroupService();
  final _inviteService = InviteService();
  final _userService = UserService();
  final _botService = BotService();
  final _authService = AuthService();
  late final String currentUserId = widget.currentUserId;

  List<UserModel> _allUsers = [];
  final Map<String, UserModel> _normalizedUsersMap = {};
  List<GroupModel> _allGroups = [];
  UserModel? _currentUserModel;
  bool _isUploading = false;

  String? _expandedItemId;
  String? _focusedHandle;

  bool _isMentioning = false;
  List<dynamic> _mentionSuggestions = [];
  String? _activeMentionKind;

  Set<String> _chatParticipantIds = {};
  List<String> _recentParticipantOrder = [];
  bool _mentionScopeEveryone = false;
  List<UserModel> _globalMentionResults = [];
  bool _globalMentionLoading = false;
  Timer? _mentionSearchDebounce;
  StreamSubscription<Set<String>>? _participantIdsSub;
  StreamSubscription<List<Map<String, dynamic>>>? _recentOrderSub;

  // AI state
  bool _isAiMode = false;
  bool _isAiLoading = false;
  final AiService _aiService = AiService();

  bool _showActions = false;
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _recordingSecondsNotifier = ValueNotifier<int>(0);
  double _recordingDragOffset = 0;
  static const int _recordingMaxSeconds =
      60; // Reduced to 60s for budget control
  bool _recordingCancelled = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  Timer? _composerTipTimer;
  int _composerTipIndex = 0;
  bool _composerTipsLoaded = false;
  bool _tipsRotateEnabled = true;

  // Reply state
  MessageModel? _replyingToMessage;
  MessageModel? _forwardingMessage;

  late final Stream<List<UserModel>> _allUsersStream;
  late final Stream<List<ChatModel>> _chatsStream;
  late final Stream<List<GroupModel>> _groupsStream;
  late final Stream<List<Map<String, dynamic>>> _pendingInvitesStream;
  late final Stream<List<Map<String, dynamic>>> _combinedStream;
  Timer? _heartbeatTimer;

  void _startHeartbeat() {
    unawaited(_authService.setUserOnlineStatus(true));
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
        unawaited(_authService.setUserOnlineStatus(true));
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    unawaited(_authService.setUserOnlineStatus(false));
  }

  @override
  void initState() {
    super.initState();
    ComposerPreferences.tipsHiddenListenable.addListener(
      _onComposerTipsHiddenChanged,
    );
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();

    NotificationService.instance.bindToUser(currentUserId);

    // Single-subscription streams cannot be listened to twice (e.g. combineLatest
    // + StreamBuilder + separate .listen). Broadcast allows multiple listeners.
    _allUsersStream =
        _userService.getAllUsers(currentUserId).asBroadcastStream();
    _chatsStream = _chatService.getUserChats(currentUserId).asBroadcastStream();
    _groupsStream =
        _groupService.getUserGroups(currentUserId).asBroadcastStream();
    _pendingInvitesStream = _inviteService
        .getPendingInvitesForUser(currentUserId)
        .asBroadcastStream();

    _combinedStream = Rx.combineLatest4(
      _chatsStream,
      _groupsStream,
      _allUsersStream,
      _pendingInvitesStream,
      (chats, groups, users, pendingInvites) {
        List<Map<String, dynamic>> merged = [];

        final Map<String, List<String>> pendingByGroup = {};
        for (final invite in pendingInvites.cast<Map<String, dynamic>>()) {
          final groupId = invite['groupId']?.toString() ?? '';
          final userId = invite['userId']?.toString() ?? '';
          if (groupId.isEmpty || userId.isEmpty) {
            continue;
          }
          pendingByGroup.putIfAbsent(groupId, () => <String>[]).add(userId);
        }

        final usersMap = {for (var u in users.cast<UserModel>()) u.uid: u};

        for (var chat in chats) {
          final otherUserId = chat.getOtherUserId(currentUserId);
          final isAiSelfChat = chat.isSelfParticipantChat;
          final otherUser = isAiSelfChat ? null : usersMap[otherUserId];
          final isBotDm = otherUser?.isBot ?? false;
          // Hide empty DMs except AI thread and custom bots (newly created bots
          // have no lastMessage yet and would otherwise never appear).
          if (chat.lastMessage.isEmpty && !isAiSelfChat && !isBotDm) {
            continue;
          }

          final isOnline = otherUser?.isOnline ?? false;
          final photoUrl = otherUser?.photoUrl;
          final emptyDmHint = isAiSelfChat
              ? 'Tap to chat with AI'
              : (isBotDm ? 'Tap to open bot' : '');

          merged.add({
            'type': 'dm',
            'id': chat.chatId,
            'otherUserId': otherUserId,
            'timeRaw': chat.lastMessageTime ?? DateTime.now(),
            'conversationTitle': isAiSelfChat
                ? 'PointChat AI'
                : (otherUser?.displayName ?? 'Chat'),
            'handle': isAiSelfChat
                ? '@ai'
                : (otherUser != null
                    ? _formatHandle(otherUser.displayName)
                    : '@unknown'),
            'isAiSelfChat': isAiSelfChat,
            'isBotDm': isBotDm,
            'sender': chat.lastMessage.isEmpty
                ? ''
                : (chat.lastMessageSenderId == currentUserId
                    ? 'me'
                    : (isAiSelfChat ? 'AI' : (otherUser?.displayName ?? ''))),
            'content':
                chat.lastMessage.isEmpty ? emptyDmHint : chat.lastMessage,
            'time': chat.lastMessageTime != null
                ? DateFormat('HH:mm').format(chat.lastMessageTime!)
                : '',
            'isUnread': (chat.unreadCount[currentUserId] ?? 0) > 0,
            'image': chat.lastMessage.contains('📷'),
            'photoUrl': photoUrl,
            'isOnline': isOnline,
            'onlinePercentage': isOnline ? 1.0 : 0.0,
          });
        }

        for (var group in groups) {
          if (_normalizeHandleToken(group.name).isEmpty) {
            // Skip malformed rows (e.g. accidental empty-name groups) in stream UI.
            continue;
          }
          final pendingInviteIds =
              pendingByGroup[group.groupId] ?? const <String>[];

          int onlineCount = 0;
          for (var uid in group.members) {
            if (uid == currentUserId) {
              if (_currentUserModel?.isOnline == true) onlineCount++;
            } else {
              final member = usersMap[uid];
              if (member != null && member.isOnline) onlineCount++;
            }
          }
          final double percentage =
              group.members.isEmpty ? 0.0 : onlineCount / group.members.length;

          final hasPreview = group.lastMessage.isNotEmpty;
          final preview = hasPreview
              ? _sanitizeGroupPreviewMessage(group.lastMessage)
              : (group.pendingMemberIds.isNotEmpty
                  ? 'Invite pending · open to view'
                  : 'New group — open to chat');

          merged.add({
            'type': 'group',
            'id': group.groupId,
            'timeRaw': group.lastMessageTime ?? DateTime.now(),
            'conversationTitle': group.name,
            'handle': _formatGroupHandle(group.name),
            'sender': hasPreview
                ? (group.lastMessageSenderId == currentUserId
                    ? 'me'
                    : group.lastMessageSenderName)
                : '',
            'content': preview,
            'time': group.lastMessageTime != null
                ? DateFormat('HH:mm').format(group.lastMessageTime!)
                : '',
            'isUnread': (group.unreadCount[currentUserId] ?? 0) > 0,
            'image': hasPreview && group.lastMessage.contains('📷'),
            'photoUrl': group.photoUrl,
            'isOnline': onlineCount > 0,
            'onlinePercentage': percentage,
            'pendingInviteIds': pendingInviteIds,
            'groupMembers': group.members,
            'pendingMemberIds': group.pendingMemberIds,
            'groupAdmins': group.admins,
            'groupDescription': group.description,
          });
        }

        merged.sort(
          (a, b) =>
              (b['timeRaw'] as DateTime).compareTo(a['timeRaw'] as DateTime),
        );

        return merged;
      },
    ).asBroadcastStream();

    _allUsersStream.listen((users) {
      if (mounted) {
        setState(() {
          _allUsers = users;
          _normalizedUsersMap.clear();
          for (final u in _allUsers) {
            _normalizedUsersMap[_normalizeHandleToken(u.displayName)] = u;
          }
        });
      }
    });

    _userService.getUserStream(currentUserId).listen((user) {
      if (mounted) {
        setState(() {
          _currentUserModel = user;
        });
      }
    });

    _groupsStream.listen((groups) {
      if (mounted) {
        setState(() {
          _allGroups = groups
              .where((g) => _normalizeHandleToken(g.name).isNotEmpty)
              .toList();
        });
      }
    });

    _participantIdsSub =
        Rx.combineLatest2<List<ChatModel>, List<GroupModel>, Set<String>>(
      _chatsStream,
      _groupsStream,
      (chats, groups) {
        final ids = <String>{};
        for (final c in chats) {
          for (final p in c.participants) {
            if (p.isNotEmpty && p != currentUserId) {
              ids.add(p);
            }
          }
        }
        for (final g in groups) {
          for (final m in g.members) {
            if (m != currentUserId) {
              ids.add(m);
            }
          }
        }
        return ids;
      },
    ).listen((ids) {
      if (mounted) {
        setState(() => _chatParticipantIds = ids);
      }
    });

    _recentOrderSub = _combinedStream.listen((items) {
      final order = <String>[];
      for (final item in items) {
        if (item['type'] == 'dm') {
          final id = item['otherUserId']?.toString();
          if (id != null && id.isNotEmpty && id != currentUserId) {
            if (!order.contains(id)) {
              order.add(id);
            }
          }
        } else if (item['type'] == 'group') {
          for (final m in (item['groupMembers'] as List?) ?? const []) {
            final id = m.toString();
            if (id.isNotEmpty && id != currentUserId && !order.contains(id)) {
              order.add(id);
            }
          }
        }
      }
      if (mounted) {
        setState(() => _recentParticipantOrder = order);
      }
    });

    _commandController.addListener(_onCommandChanged);

    unawaited(_loadComposerPrefsAndTips());
  }

  void _onComposerTipsHiddenChanged() {
    if (ComposerPreferences.tipsHiddenListenable.value) {
      _composerTipTimer?.cancel();
      _composerTipTimer = null;
    } else {
      _syncComposerTipTimer();
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadComposerPrefsAndTips() async {
    await ComposerPreferences.syncListenableFromPrefs();
    final rotate = await ComposerPreferences.getTipsRotateEnabled();
    await PointchatTips.instance.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _composerTipsLoaded = true;
      _tipsRotateEnabled = rotate;
    });
    _syncComposerTipTimer();
  }

  void _syncComposerTipTimer() {
    _composerTipTimer?.cancel();
    _composerTipTimer = null;
    if (ComposerPreferences.tipsHiddenListenable.value) return;
    if (!_tipsRotateEnabled || !mounted) return;
    final n = PointchatTips.instance.rotatingTips.length;
    if (n <= 1) return;
    _composerTipTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted || !_tipsRotateEnabled) return;
      final n2 = PointchatTips.instance.rotatingTips.length;
      if (n2 <= 1) return;
      setState(() => _composerTipIndex = (_composerTipIndex + 1) % n2);
    });
  }

  Future<void> _toggleTipRotation() async {
    final next = !_tipsRotateEnabled;
    await ComposerPreferences.setTipsRotateEnabled(next);
    if (!mounted) return;
    setState(() => _tipsRotateEnabled = next);
    if (next) {
      _syncComposerTipTimer();
    } else {
      _composerTipTimer?.cancel();
      _composerTipTimer = null;
    }
  }

  void _focusComposerAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _commandFocusNode.requestFocus();
    });
  }

  void _scheduleMentionGlobalSearch(String rawQuery) {
    _mentionSearchDebounce?.cancel();
    final q = rawQuery.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _globalMentionResults = [];
          _globalMentionLoading = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _globalMentionLoading = true);
    }
    _mentionSearchDebounce = Timer(const Duration(milliseconds: 320), () async {
      try {
        final list = await _userService.searchUsers(q, currentUserId);
        if (!mounted) {
          return;
        }
        setState(() {
          _globalMentionResults = list;
          _globalMentionLoading = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _globalMentionResults = [];
          _globalMentionLoading = false;
        });
      }
    });
  }

  void _showCommandHelpSheet() {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: scheme.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat commands',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _helpRow(ctx, '@name', 'Message someone from your chats'),
              _helpRow(
                ctx,
                '#group or #group~id',
                'Same name twice? Pick from the sheet or use #name~first8id chars',
              ),
              _helpRow(
                ctx,
                '@ai',
                'PointChat AI — messages go only to your private AI thread',
              ),
              _helpRow(
                ctx,
                '/newbot Name',
                'Create a custom bot (type after the command)',
              ),
              _helpRow(
                ctx,
                '/setting',
                'Open your settings (seen status, notify on seen, profile)',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpRow(BuildContext ctx, String cmd, String desc) {
    final scheme = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bolt_rounded, size: 18, color: AppTheme.focusBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cmd,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.focusBlue,
                  ),
                ),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onCommandChanged() {
    final text = _commandController.text;
    final selection = _commandController.selection;
    if (selection.baseOffset == -1) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    final lastHash = textBeforeCursor.lastIndexOf('#');
    final lastSlash = textBeforeCursor.lastIndexOf('/');
    final lastSpace = textBeforeCursor.lastIndexOf(' ');

    // Detect /ai mode — check if text contains /
    /* AI FEATURE TEMPORARILY HIDDEN
    final slashIndex = text.indexOf('/');
    if (slashIndex >= 0) {
      // Check if there's at least one target before the /
      final beforeSlash = text.substring(0, slashIndex).trim();
      final hasTarget =
          _hasExplicitTarget(beforeSlash) || _focusedHandle != null;
      setState(() {
        _isAiMode = hasTarget;
      });
    } else {
      setState(() {
        _isAiMode = false;
      });
    }
    */
    setState(() {
      _isAiMode = false;
    });

    if (lastAt > lastSpace && lastAt >= 0) {
      final rawAfterAt = textBeforeCursor.substring(lastAt + 1);
      final query = _normalizeHandleToken(rawAfterAt);
      final rawTrim = rawAfterAt.trim();

      final cmdMatches = <_AtCommandSuggestion>[];
      for (final c in _kAtCommandHints) {
        final stemNorm = _normalizeHandleToken(c.insertStem);
        if (query.isEmpty || stemNorm.startsWith(query)) {
          cmdMatches.add(c);
        }
      }

      if (_mentionScopeEveryone && rawTrim.length >= 2) {
        _scheduleMentionGlobalSearch(rawTrim);
      } else {
        _mentionSearchDebounce?.cancel();
        if (mounted &&
            (_globalMentionResults.isNotEmpty || _globalMentionLoading)) {
          setState(() {
            _globalMentionResults = [];
            _globalMentionLoading = false;
          });
        }
      }

      List<UserModel> userMatches;
      if (_mentionScopeEveryone) {
        userMatches = _globalMentionResults;
      } else {
        userMatches = _allUsers.where((u) {
          if (!_chatParticipantIds.contains(u.uid)) {
            return false;
          }
          if (query.isEmpty) {
            return true;
          }
          return _normalizeHandleToken(u.displayName).contains(query);
        }).toList();
        userMatches.sort((a, b) {
          final ia = _recentParticipantOrder.indexOf(a.uid);
          final ib = _recentParticipantOrder.indexOf(b.uid);
          if (ia == -1 && ib == -1) {
            return a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                );
          }
          if (ia == -1) {
            return 1;
          }
          if (ib == -1) {
            return -1;
          }
          return ia.compareTo(ib);
        });
      }

      setState(() {
        _isMentioning = true;
        _activeMentionKind = '@';
        _mentionSuggestions = [...cmdMatches, ...userMatches];
      });
    } else if (lastHash > lastSpace && lastHash >= 0) {
      _mentionSearchDebounce?.cancel();
      final rawQuery = textBeforeCursor.substring(lastHash + 1);
      final query = _normalizeHandleToken(rawQuery);
      final groupMatches = _allGroups
          .where((g) => _normalizeHandleToken(g.name).contains(query))
          .toList();

      // O(1) performance optimization via Set lookup instead of O(N) .any() mapping iteration
      final groupNamesNorm = Set<String>.from(
          groupMatches.map((g) => _normalizeHandleToken(g.name)));
      final hasExactMatch = groupNamesNorm.contains(query);

      setState(() {
        _isMentioning = true;
        _activeMentionKind = '#';
        _mentionSuggestions = [
          ...groupMatches,
          if (query.isNotEmpty && !hasExactMatch) _CreateGroupSuggestion(query),
        ];
      });
    } else if (lastSlash > lastSpace && lastSlash >= 0) {
      _mentionSearchDebounce?.cancel();
      final query = textBeforeCursor.substring(lastSlash + 1).toLowerCase();
      final slashOptions = <String>[
        '/setting',
        '/newbot',
        // AI commands hidden for now
        // '/summarize',
        // '/summarize unread',
        // '/summarize conversation',
      ];
      setState(() {
        _isMentioning = true;
        _activeMentionKind = '/';
        _mentionSuggestions = slashOptions
            .where((option) => option.toLowerCase().contains(query))
            .toList();
      });
    } else {
      _mentionSearchDebounce?.cancel();
      setState(() {
        _isMentioning = false;
        _mentionSuggestions = [];
        _activeMentionKind = null;
        _globalMentionResults = [];
        _globalMentionLoading = false;
      });
    }
  }

  @override
  void dispose() {
    ComposerPreferences.tipsHiddenListenable.removeListener(
      _onComposerTipsHiddenChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _participantIdsSub?.cancel();
    _recentOrderSub?.cancel();
    _mentionSearchDebounce?.cancel();
    _composerTipTimer?.cancel();
    _commandController.removeListener(_onCommandChanged);
    _commandController.dispose();
    _commandFocusNode.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopHeartbeat();
    }
  }

  /// Match handles to stored names (users / groups). Keeps all Unicode letters;
  /// the old ASCII-only strip broke Arabic and other scripts entirely.
  String _normalizeHandleToken(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  String _displayGroupNameFromToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return '';
    return t.replaceAll('_', ' ');
  }

  List<String> _extractPendingInviteIds(String text) {
    if (!text.startsWith('[invite-pending]:')) {
      return const <String>[];
    }

    final payload = text.replaceFirst('[invite-pending]:', '');
    return payload
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  String _sanitizeGroupPreviewMessage(String text) {
    final pendingIds = _extractPendingInviteIds(text);
    if (pendingIds.isNotEmpty) {
      return 'Invitation pending approval';
    }
    return text;
  }

  Future<GroupModel?> _pickGroupWhenAmbiguous(List<GroupModel> matches) async {
    if (!mounted || matches.isEmpty) {
      return null;
    }
    final scheme = Theme.of(context).colorScheme;
    return showModalBottomSheet<GroupModel>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Several groups share this name. Pick one:',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              ...matches.map((g) {
                final hint =
                    GroupHandleResolver.composerHandleForGroup(g, _allGroups);
                final idFrag = g.groupId.length <= 8
                    ? g.groupId
                    : '${g.groupId.substring(0, 8)}…';
                return ListTile(
                  title: Text(g.name, style: GoogleFonts.inter()),
                  subtitle: Text(
                    '$hint · $idFrag',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11),
                  ),
                  onTap: () => Navigator.pop(ctx, g),
                );
              }),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<GroupModel?> _resolveGroupForAiContext(String handleWithHash) async {
    final parsed = GroupHandleResolver.parseAfterHash(
      handleWithHash.substring(1),
    );
    final matches = GroupHandleResolver.matchingByName(
      _allGroups,
      parsed.nameToken,
    );
    if (matches.isEmpty) {
      return null;
    }
    if (parsed.idSuffix != null && parsed.idSuffix!.isNotEmpty) {
      return GroupHandleResolver.pickByIdSuffix(matches, parsed.idSuffix!);
    }
    if (matches.length == 1) {
      return matches.first;
    }
    return _pickGroupWhenAmbiguous(matches);
  }

  String _formatHandle(String name) {
    return '@${name.replaceAll(' ', '').toLowerCase()}';
  }

  String _formatGroupHandle(String name) {
    return '#${name.replaceAll(' ', '').toLowerCase()}';
  }

  bool _hasExplicitTarget(String text) {
    final trimmed = text.trimLeft();
    return trimmed.startsWith('@') || trimmed.startsWith('#');
  }

  String _applyFocusedHandle(String text) {
    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return _focusedHandle ?? '';
    }

    if (_focusedHandle == null ||
        _hasExplicitTarget(trimmed) ||
        trimmed.startsWith('/') ||
        trimmed.toLowerCase().startsWith('@ai ')) {
      return trimmed;
    }

    return '${_focusedHandle!} $trimmed';
  }

  Future<void> _lockChat(Map<String, dynamic> item) async {
    final itemType = item['type'] as String?;
    final itemId = item['id'] as String?;

    if (itemType == 'dm' && itemId != null) {
      // Toggle lock status for DMs
      final currentLocked =
          (await ChatPrivacyPreferences.getLockedChatIds()).contains(itemId);
      await ChatPrivacyPreferences.toggleLocked(itemId, !currentLocked);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !currentLocked ? 'Chat locked and hidden' : 'Chat unlocked',
              style: GoogleFonts.inter(),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (itemType == 'group') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Swipe left on a DM to lock it',
            style: GoogleFonts.inter(),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteChat(Map<String, dynamic> item) async {
    final itemType = item['type'] as String?;
    final itemId = item['id'] as String?;
    final title = item['conversationTitle'] as String? ?? 'this chat';

    if (itemId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
            'Are you sure you want to delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (itemType == 'dm') {
        // Get the other user from the DM
        final otherUserId = item['otherUserId'] as String?;
        await _chatService
            .deleteChat(itemId, [currentUserId, otherUserId ?? '']);
      } else if (itemType == 'group') {
        await _groupService.deleteGroup(itemId);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "$title"', style: GoogleFonts.inter()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete: $e', style: GoogleFonts.inter()),
          ),
        );
      }
    }
  }

  void _insertHandleIntoComposer(String handle) {
    final text = _commandController.text;
    final selection = _commandController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final prefix = text.substring(0, start);
    final suffix = text.substring(end);
    final needsLeadingSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
    final replacement = '${needsLeadingSpace ? ' ' : ''}$handle ';
    final newText = '$prefix$replacement$suffix';
    final newOffset = prefix.length + replacement.length;

    _commandController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _commandFocusNode.requestFocus();
  }

  void _insertSlashCommand(String command) {
    final text = _commandController.text;
    final selection = _commandController.selection;
    final cursor =
        selection.baseOffset >= 0 ? selection.baseOffset : text.length;
    final textBeforeCursor = text.substring(0, cursor);
    final textAfterCursor = text.substring(cursor);
    final lastSlash = textBeforeCursor.lastIndexOf('/');

    final newText = lastSlash >= 0
        ? '${textBeforeCursor.substring(0, lastSlash)}$command $textAfterCursor'
        : '${textBeforeCursor.isNotEmpty ? '$textBeforeCursor ' : ''}$command $textAfterCursor';
    final newOffset = (lastSlash >= 0
            ? lastSlash
            : textBeforeCursor.length + (textBeforeCursor.isNotEmpty ? 1 : 0)) +
        command.length +
        1;

    _commandController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );

    // /newbot needs a name after it — don't auto-send.
    if (command.trim().toLowerCase() == '/newbot') {
      _commandFocusNode.requestFocus();
      return;
    }

    // Auto-submit command immediately so user doesn't have to press ok
    _sendCommand(newText);
  }

  Map<String, dynamic>? _findItemByHandle(String handle) {
    if (handle.startsWith('@')) {
      final normalized = _normalizeHandleToken(handle.substring(1));
      final user = _normalizedUsersMap[normalized];
      if (user != null) {
        return {
          'type': 'dm',
          'handle': handle,
          'otherUserId': user.uid,
          'photoUrl': user.photoUrl,
        };
      }
    }

    if (handle.startsWith('#')) {
      final parsed = GroupHandleResolver.parseAfterHash(handle.substring(1));
      final matches = GroupHandleResolver.matchingByName(
        _allGroups,
        parsed.nameToken,
      );
      if (matches.isEmpty) {
        return null;
      }
      final group = parsed.idSuffix != null && parsed.idSuffix!.isNotEmpty
          ? GroupHandleResolver.pickByIdSuffix(matches, parsed.idSuffix!)
          : (matches.length == 1 ? matches.first : null);
      if (group != null) {
        return {
          'type': 'group',
          'handle': handle,
          'id': group.groupId,
          'photoUrl': group.photoUrl,
          'groupMembers': group.members,
          'pendingMemberIds': group.pendingMemberIds,
          'groupAdmins': group.admins,
          'groupDescription': group.description,
        };
      }
    }

    return null;
  }

  Future<void> _showSettingsOverlayForHandle(String handle) async {
    final item = _findItemByHandle(handle);
    if (item == null || !mounted) {
      return;
    }

    await _showSettingsOverlay(item);
  }

  Future<void> _showMyProfileOverlay() async {
    await _showSettingsOverlay({
      'type': 'self',
      'handle': '@me',
      'otherUserId': currentUserId,
    });
  }

  Future<void> _showSettingsOverlay(Map<String, dynamic> item) async {
    if (!mounted) {
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'settings',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.88,
                  constraints: const BoxConstraints(
                    maxWidth: 460,
                    maxHeight: 620,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: _buildSettingsOverlayContent(item),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(animation),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSettingsOverlayContent(Map<String, dynamic> item) {
    final handle = item['handle'] as String? ?? '';
    final isGroup = (item['type'] as String?) == 'group';
    final isSelf = (item['type'] as String?) == 'self';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isGroup
                    ? 'Group Settings'
                    : (isSelf ? 'My Profile' : 'User Settings'),
                style: GoogleFonts.outfit(
                  color: Colors.white, // High contrast
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ],
        ),
        Text(
          handle,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: isGroup
              ? _buildGroupSettingsContent(item)
              : (isSelf
                  ? _buildMyProfileContent()
                  : _buildUserSettingsContent(item)),
        ),
      ],
    );
  }

  Widget _overlayActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final fg = danger ? const Color(0xFFFFB4AB) : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: danger ? Colors.white10 : Colors.white12,
          borderRadius: BorderRadius.zero,
          border: danger ? Border.all(color: fg.withValues(alpha: 0.35)) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSettingsContent(Map<String, dynamic> item) {
    final groupId = item['id'] as String? ?? '';

    return StreamBuilder<GroupModel?>(
      stream: _groupService.getGroupStream(groupId),
      builder: (context, snapshot) {
        final group = snapshot.data;
        if (group == null) {
          return Center(
            child: Text(
              'Group details unavailable.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          );
        }

        final description = group.description;
        final members = group.members;
        final admins = group.admins;
        final isCurrentUserAdmin = admins.contains(currentUserId);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _editableAvatar(
                    imageUrl: group.photoUrl,
                    initialsSource: group.name,
                    accent: AppTheme.green,
                    onTap: isCurrentUserAdmin
                        ? () => _updateGroupPhoto(group.groupId)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description.isEmpty
                              ? 'No group status set yet.'
                              : description,
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isCurrentUserAdmin) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _overlayActionButton(
                      icon: Icons.photo_camera_back_outlined,
                      label: 'Change Icon',
                      onTap: () => _updateGroupPhoto(group.groupId),
                    ),
                    _overlayActionButton(
                      icon: Icons.edit_note_rounded,
                      label: 'Edit Status',
                      onTap: () => _editGroupDescription(group),
                    ),
                    _overlayActionButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Add Member',
                      onTap: () => _showAddMembersOverlay(group),
                    ),
                    _overlayActionButton(
                      icon: Icons.delete_forever_outlined,
                      label: 'Delete group',
                      danger: true,
                      onTap: () => _confirmDeleteGroupFromOverlay(group),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Members',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              ...members.map((memberId) {
                final user = _allUsers.cast<UserModel?>().firstWhere(
                      (entry) => entry?.uid == memberId,
                      orElse: () =>
                          memberId == currentUserId ? _currentUserModel : null,
                    );
                final memberName = user?.displayName ?? 'Unknown';
                final memberHandle = _formatHandle(memberName);
                final isAdmin = admins.contains(memberId);
                final canModerate =
                    isCurrentUserAdmin && memberId != currentUserId;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pop();
                                _insertHandleIntoComposer(memberHandle);
                              },
                              child: Text(
                                memberHandle,
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (isAdmin)
                            Text(
                              'ADMIN',
                              style: GoogleFonts.inter(
                                color: AppTheme.purpleLt,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (canModerate)
                            _miniMemberAction(
                              label: isAdmin ? 'Remove Admin' : 'Make Admin',
                              onTap: () async {
                                if (isAdmin) {
                                  await _groupService.removeAdmin(
                                    group.groupId,
                                    memberId,
                                  );
                                } else {
                                  await _groupService.makeAdmin(
                                    group.groupId,
                                    memberId,
                                  );
                                }
                              },
                            ),
                          if (canModerate)
                            _miniMemberAction(
                              label: 'Remove Member',
                              isDanger: true,
                              onTap: () async {
                                await _groupService.removeMember(
                                  group.groupId,
                                  memberId,
                                  removedByName: cachedUserName.isEmpty
                                      ? 'Admin'
                                      : cachedUserName,
                                  skipUnreadIncrementForActor: currentUserId,
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              if (group.pendingMemberIds.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Pending invites',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'They must accept the invite before they appear in Members.',
                  style: GoogleFonts.inter(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...group.pendingMemberIds.map((pid) {
                  final user = _allUsers.cast<UserModel?>().firstWhere(
                        (u) => u?.uid == pid,
                        orElse: () => null,
                      );
                  final label = user != null
                      ? _formatHandle(user.displayName)
                      : 'User ${pid.length > 8 ? pid.substring(0, 8) : pid}…';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: Text(
                      '$label · waiting to accept',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteGroupFromOverlay(GroupModel group) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          '“${group.name}” will be removed for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _groupService.deleteGroup(group.groupId);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Group deleted',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not delete group: $e',
              style: GoogleFonts.inter(),
            ),
          ),
        );
      }
    }
  }

  Widget _buildUserSettingsContent(Map<String, dynamic> item) {
    final otherUserId = item['otherUserId'] as String? ?? '';
    final chatId = item['id'] as String?;
    return StreamBuilder<UserModel?>(
      stream: _userService.getUserStream(otherUserId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return Center(
            child: Text(
              'User details unavailable.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          );
        }

        return FutureBuilder<String>(
          future: chatId == null || chatId.isEmpty
              ? _chatService.getOrCreateChat(currentUserId, otherUserId)
              : Future.value(chatId),
          builder: (context, chatIdSnapshot) {
            if (!chatIdSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.purple,
                  strokeWidth: 2,
                ),
              );
            }

            final resolvedChatId = chatIdSnapshot.data!;
            return StreamBuilder<ChatModel?>(
              stream: _chatService.getChatStream(resolvedChatId),
              builder: (context, chatSnapshot) {
                final chat = chatSnapshot.data;
                final mySeenEnabled = chat?.seenEnabled[currentUserId] ?? true;
                final otherSeenEnabled = chat?.seenEnabled[otherUserId] ?? true;
                final myNotifyOnSeen =
                    chat?.notifyOnSeen[currentUserId] ?? false;
                final otherNotifyOnSeen =
                    chat?.notifyOnSeen[otherUserId] ?? false;

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _editableAvatar(
                            imageUrl: user.photoUrl,
                            initialsSource: user.displayName,
                            accent: AppTheme.focusBlue,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.status,
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Email and Presence concealed for privacy
                      _settingsField('Type', user.isBot ? 'AI Bot' : 'Person'),
                      const SizedBox(height: 10),
                      _seenToggleRow(
                        label: 'Show my read receipts',
                        subtitle: 'Let ${user.displayName} see when you read.',
                        value: mySeenEnabled,
                        onChanged: (val) {
                          _chatService.toggleSeenEnabled(
                            resolvedChatId,
                            currentUserId,
                            val,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      _seenToggleRow(
                        label: 'Notify me when seen',
                        subtitle:
                            'Get a notice when ${user.displayName} reads your messages.',
                        value: myNotifyOnSeen,
                        onChanged: (val) {
                          _chatService.toggleNotifyOnSeen(
                            resolvedChatId,
                            currentUserId,
                            val,
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        icon: otherSeenEnabled
                            ? Icons.done_all
                            : Icons.visibility_off_outlined,
                        text: otherSeenEnabled
                            ? '${user.displayName} is sharing read receipts.'
                            : '${user.displayName} is hiding read receipts.',
                        color: otherSeenEnabled
                            ? AppTheme.green
                            : Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        icon: otherNotifyOnSeen
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        text: otherNotifyOnSeen
                            ? '${user.displayName} turned on seen notifications for this chat.'
                            : '${user.displayName} has seen notifications off.',
                        color: otherNotifyOnSeen
                            ? AppTheme.focusBlue
                            : Theme.of(context).colorScheme.secondary,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMyProfileContent() {
    // Load settings data once
    if (_mySettingsData == null) {
      _loadMySettings();
    }

    return StreamBuilder<UserModel?>(
      stream: _userService.getUserStream(currentUserId),
      builder: (context, snapshot) {
        final user = snapshot.data ?? _currentUserModel;
        if (user == null) {
          return const Center(
            child: CircularProgressIndicator(
                color: AppTheme.purple, strokeWidth: 2),
          );
        }

        final settings = _mySettingsData ?? _MySettingsState();

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Row(
                children: [
                  _editableAvatar(
                    imageUrl: user.photoUrl,
                    initialsSource: user.displayName,
                    accent: AppTheme.focusBlue,
                    onTap: _updateMyProfilePhoto,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.status,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick Actions
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _overlayActionButton(
                    icon: Icons.photo_camera_back_outlined,
                    label: 'Photo',
                    onTap: _updateMyProfilePhoto,
                  ),
                  _overlayActionButton(
                    icon: Icons.edit_note_rounded,
                    label: 'Status',
                    onTap: () => _editMyStatus(user.status),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // =============== PRIVACY ===============
              _settingsSectionTitle('PRIVACY'),
              _settingsToggle(
                icon: Icons.done_all_outlined,
                title: 'Show read receipts',
                subtitle: 'Others see when you read',
                value: settings.seenEnabled,
                onChanged: (v) async {
                  _mySettingsData?.seenEnabled = v;
                  await _chatService.setDefaultSeenEnabledForMe(v);
                  await _chatService.applySeenEnabledToAllChats(
                      currentUserId, v);
                  if (mounted) setState(() {});
                },
              ),
              _settingsToggle(
                icon: Icons.notifications_active_outlined,
                title: 'Notify when seen',
                subtitle: 'Get alerts when read',
                value: settings.notifyOnSeen,
                onChanged: (v) async {
                  _mySettingsData?.notifyOnSeen = v;
                  await _chatService.setDefaultNotifyOnSeenForMe(v);
                  await _chatService.applyNotifyOnSeenToAllChats(
                      currentUserId, v);
                  if (mounted) setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // =============== CHATS & LOCK ===============
              _settingsSectionTitle('CHATS & LOCK'),
              // Hint text for swipe gestures
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'Hint: Swipe a chat left to hide and lock, or right to delete.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
                ),
              ),
              _settingsPinInput(
                initialValue: settings.privacyPin,
                onSave: (pin) async {
                  _mySettingsData?.privacyPin = pin;
                  await ChatPrivacyPreferences.setPrivacyPin(pin);
                  if (mounted) setState(() {});
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 44, bottom: 8),
                child: Text(
                  'Swipe a chat left to blur and lock.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white30),
                ),
              ),

              const SizedBox(height: 16),

              // =============== APPEARANCE ===============
              _settingsSectionTitle('APPEARANCE'),
              _settingsThemeRow(
                currentMode: settings.themeMode,
                onChanged: (mode) {
                  _mySettingsData?.themeMode = mode;
                  ref.read(themeModeProvider.notifier).setMode(mode);
                  if (mounted) setState(() {});
                },
              ),
              _settingsToggle(
                icon: Icons.hide_source_outlined,
                title: 'Hide composer tips',
                subtitle: 'Tips above message box',
                value: settings.tipsHidden,
                onChanged: (v) async {
                  _mySettingsData?.tipsHidden = v;
                  await ComposerPreferences.setTipsHidden(v);
                  if (mounted) setState(() {});
                },
              ),

              const SizedBox(height: 16),

              // =============== AI ===============
              _settingsSectionTitle('AI'),
              _settingsInfoRow(
                icon: Icons.auto_awesome,
                title: 'AI subscription',
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SubscriptionService.instance.state.value.hasAiAccess
                        ? AppTheme.green.withValues(alpha: 0.2)
                        : Colors.white10,
                  ),
                  child: Text(
                    SubscriptionService.instance.state.value.hasAiAccess
                        ? 'Active'
                        : 'Inactive',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          SubscriptionService.instance.state.value.hasAiAccess
                              ? AppTheme.green
                              : Colors.white54,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // =============== INFO ===============
              _settingsSectionTitle('INFO'),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text('Email: ${user.email}',
                    style:
                        GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text('Chats: ${user.chatIds.length}',
                    style:
                        GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Groups: ${user.groupIds.length}',
                    style:
                        GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  _MySettingsState? _mySettingsData;

  Future<void> _loadMySettings() async {
    final seen = await _chatService.getDefaultSeenEnabledForMe();
    final notify = await _chatService.getDefaultNotifyOnSeenForMe();
    final pin = await ChatPrivacyPreferences.getPrivacyPin();
    final tips = await ComposerPreferences.getTipsHidden();
    final theme = ref.read(themeModeProvider);

    _mySettingsData = _MySettingsState(
      seenEnabled: seen,
      notifyOnSeen: notify,
      privacyPin: pin,
      tipsHidden: tips,
      themeMode: theme,
    );
    if (mounted) setState(() {});
  }

  Widget _settingsSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style:
                        GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.green,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _settingsPinInput(
      {required String initialValue, required Function(String) onSave}) {
    final controller = TextEditingController(text: initialValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          const Icon(Icons.pin_outlined, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chat Security PIN (4-8 digits)',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                SizedBox(
                  height: 28,
                  child: TextField(
                    controller: controller,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 14, color: Colors.white70),
                    decoration: InputDecoration(
                      hintText: 'For unlocking locked chats',
                      hintStyle: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: Colors.white24),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              final pin = controller.text.trim();
              if (pin.isNotEmpty && (pin.length < 4 || pin.length > 8)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('PIN must be 4–8 digits or empty')),
                );
                return;
              }
              if (pin.isNotEmpty && int.tryParse(pin) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be numeric')),
                );
                return;
              }
              onSave(pin);
            },
            child: Text('Save',
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.focusBlue)),
          ),
        ],
      ),
    );
  }

  Widget _settingsThemeRow(
      {required ThemeMode currentMode,
      required Function(ThemeMode) onChanged}) {
    String label;
    switch (currentMode) {
      case ThemeMode.light:
        label = 'Light';
        break;
      case ThemeMode.dark:
        label = 'Dark';
        break;
      case ThemeMode.system:
        label = 'System';
        break;
    }

    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Theme',
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                for (final mode in ThemeMode.values)
                  ListTile(
                    title: Text(mode == ThemeMode.system
                        ? 'System default'
                        : mode.name[0].toUpperCase() + mode.name.substring(1)),
                    trailing: currentMode == mode
                        ? const Icon(Icons.check, color: AppTheme.green)
                        : null,
                    onTap: () {
                      onChanged(mode);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            const Icon(Icons.dark_mode_outlined,
                color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Theme',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            Text(label,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white30, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _settingsInfoRow(
      {required IconData icon,
      required String title,
      required Widget trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _editableAvatar({
    required String imageUrl,
    required String initialsSource,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final initials =
        initialsSource.isEmpty ? '?' : initialsSource[0].toUpperCase();
    final avatar = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.zero,
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        color: accent.withValues(alpha: 0.12),
        image: imageUrl.isNotEmpty
            ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
            : null,
      ),
      child: imageUrl.isEmpty
          ? Center(
              child: Text(
                initials,
                style: GoogleFonts.inter(
                  color: accent,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );

    if (onTap == null) {
      return avatar;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Icon(Icons.edit_rounded, size: 14, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMemberAction({
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? AppTheme.red : AppTheme.focusBlue;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<String?> _pickAndUploadSquareImage({
    required String filePrefix,
  }) async {
    return pickAndUploadSquareChatImage(filePrefix: filePrefix);
  }

  Future<void> _updateMyProfilePhoto() async {
    try {
      final photoUrl = await _pickAndUploadSquareImage(filePrefix: 'profile');
      if (photoUrl == null) {
        return;
      }

      await _userService.updateUserPhotoUrl(currentUserId, photoUrl);

      cachedUserPhotoUrl = photoUrl;
      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update your profile picture right now. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _updateGroupPhoto(String groupId) async {
    try {
      final photoUrl = await _pickAndUploadSquareImage(filePrefix: 'group');
      if (photoUrl == null) {
        return;
      }

      await _groupService.updateGroup(groupId, {'photoUrl': photoUrl});

      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group icon updated.')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update the group icon right now. Please try again.',
          ),
        ),
      );
    }
  }

  Future<bool> _ensureAiAccess() async {
    final service = SubscriptionService.instance;
    final hasAccess = await service.ensureAiAccess();
    if (hasAccess || !mounted) {
      return hasAccess;
    }

    final unlocked = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AiSubscriptionScreen()),
    );
    return unlocked == true || service.hasAiAccess;
  }

  Future<void> _editMyStatus(String currentStatus) async {
    final controller = TextEditingController(text: currentStatus);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Edit Status'),
        content: TextField(
          controller: controller,
          maxLength: 140,
          decoration: const InputDecoration(hintText: 'What do people see?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _userService.updateStatus(
                currentUserId,
                controller.text.trim(),
              );
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroupDescription(GroupModel group) async {
    final controller = TextEditingController(text: group.description);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Edit Group Status'),
        content: TextField(
          controller: controller,
          maxLength: 180,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Write a short group status or description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await _groupService.updateGroup(group.groupId, {
                'description': controller.text.trim(),
              });
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddMembersOverlay(GroupModel group) async {
    final selectedIds = <String>{};
    final candidates = _allUsers
        .where(
          (user) =>
              !user.isExcludedFromGroups &&
              !group.members.contains(user.uid) &&
              !group.pendingMemberIds.contains(user.uid),
        )
        .toList();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Add Members'),
          content: SizedBox(
            width: 420,
            child: candidates.isEmpty
                ? Text(
                    'No more people available to add.',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: candidates.map((user) {
                      final handle = _formatHandle(user.displayName);
                      return CheckboxListTile(
                        value: selectedIds.contains(user.uid),
                        activeColor: AppTheme.focusBlue,
                        title: Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.blueAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(child: Text(' ${handle.substring(1)}')),
                          ],
                        ),
                        subtitle: Text(
                          user.status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              selectedIds.add(user.uid);
                            } else {
                              selectedIds.remove(user.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedIds.isEmpty
                  ? null
                  : () async {
                      await _groupService.addMembers(
                        group.groupId,
                        selectedIds.toList(),
                        cachedUserName.isEmpty ? 'Admin' : cachedUserName,
                        actorUserId: currentUserId,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _seenToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10, // Contrast change, no border
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: Colors.white,
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _settingsField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _forwardPendingMessage(String input) async {
    final message = _forwardingMessage;
    if (message == null) {
      return;
    }

    final command = _applyFocusedHandle(input);
    if (!_hasExplicitTarget(command)) {
      _commandFocusNode.requestFocus();
      return;
    }

    switch (message.type) {
      case MessageType.image:
        await _processCommand(
          command,
          imageUrl: message.text,
          skipReplyMarkup: true,
        );
        break;
      case MessageType.file:
        await _processCommand(
          command,
          metadata: {
            'url': message.text,
            'type': MessageType.file,
            'fileName': message.fileName,
            'fileSize': message.fileSize,
          },
          skipReplyMarkup: true,
        );
        break;
      case MessageType.audio:
        await _processCommand(
          command,
          metadata: {
            'url': message.text,
            'type': MessageType.audio,
            'fileName': message.fileName,
            'audioDuration': message.audioDuration,
          },
          skipReplyMarkup: true,
        );
        break;
      case MessageType.location:
        if (message.latitude != null && message.longitude != null) {
          await _processCommand(
            command,
            metadata: {
              'type': MessageType.location,
              'latitude': message.latitude,
              'longitude': message.longitude,
            },
            skipReplyMarkup: true,
          );
        } else {
          await _processCommand(
            command,
            textOverride: message.text,
            skipReplyMarkup: true,
          );
        }
        break;
      case MessageType.system:
      case MessageType.text:
        await _processCommand(
          command,
          textOverride: message.text,
          skipReplyMarkup: true,
        );
        break;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _forwardingMessage = null;
    });
    _commandController.clear();
  }

  void _pickAndSendImage() async {
    final text = _applyFocusedHandle(_commandController.text);
    if (!_hasExplicitTarget(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before attaching image',
              style: GoogleFonts.jetBrainsMono(),
            ),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 70,
      maxWidth: 1600,
      maxHeight: 1600,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF161618),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.focusBlue,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Crop Photo'),
      ],
    );
    if (croppedFile == null) return;

    final imageNote = await _promptImageNote();
    if (imageNote == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = const Uuid().v4();
      final file = await appwriteStorage.createFile(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: ID.unique(),
        file: InputFile.fromPath(
          path: croppedFile.path,
          filename: '$fileName.jpg',
        ),
      );
      final downloadUrl =
          '${AppwriteConstants.endpoint}/storage/buckets/${AppwriteConstants.chatFilesBucket}/files/${file.$id}/view?project=${AppwriteConstants.projectId}';

      await _processCommand(text, imageUrl: downloadUrl);
      if (imageNote.trim().isNotEmpty) {
        await _processCommand('$text ${imageNote.trim()}');
      }
      _commandController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image upload failed.',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Pick & send file ──
  void _pickAndSendFile() async {
    final text = _applyFocusedHandle(_commandController.text);
    if (!_hasExplicitTarget(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before attaching file',
              style: GoogleFonts.jetBrainsMono(),
            ),
          ),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _isUploading = true);

    try {
      final fileId = const Uuid().v4();
      final ext = file.extension ?? 'bin';
      final uploadedFile = await appwriteStorage.createFile(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: '$fileId.$ext'),
      );
      final downloadUrl =
          '${AppwriteConstants.endpoint}/storage/buckets/${AppwriteConstants.chatFilesBucket}/files/${uploadedFile.$id}/view?project=${AppwriteConstants.projectId}';

      await _processCommand(
        text,
        metadata: {
          'url': downloadUrl,
          'type': MessageType.file,
          'fileName': file.name,
          'fileSize': file.size,
        },
      );
      _commandController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File upload failed.',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Timer? _recordingTimer;

  Future<String?> _promptImageNote() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text(
          'Add note (optional)',
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'Write a note for this photo...',
            hintStyle: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.secondary,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.purple),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(
              'Send',
              style: GoogleFonts.inter(color: AppTheme.purpleLt),
            ),
          ),
        ],
      ),
    );
  }

  // ── Start recording ──
  Future<void> _startRecording() async {
    final text = _applyFocusedHandle(_commandController.text);
    if (!_hasExplicitTarget(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before recording',
              style: GoogleFonts.jetBrainsMono(),
            ),
          ),
        );
      }
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/temp_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      _isRecordingNotifier.value = true;
      _recordingSecondsNotifier.value = 0;
      _recordingDragOffset = 0;
      _recordingCancelled = false;

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _recordingSecondsNotifier.value++;
        if (_recordingSecondsNotifier.value >= _recordingMaxSeconds) {
          _stopAndSendRecording(showLimitReachedToast: true);
        }
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Microphone permission denied.',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    }
  }

  // ── Stop & send recording ──
  Future<void> _stopAndSendRecording({
    bool showLimitReachedToast = false,
  }) async {
    if (!_isRecordingNotifier.value) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final path = await _audioRecorder.stop();
    final duration = _recordingSecondsNotifier.value;
    _isRecordingNotifier.value = false;

    if (showLimitReachedToast && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Max recording length reached ($_recordingMaxSeconds s)',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    }

    if (path == null || _recordingCancelled) return;
    // Minimum 1 second to avoid accidental taps
    if (duration < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hold longer to record',
              style: GoogleFonts.jetBrainsMono(),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final xFile = XFile(path);
      final audioBytes = await xFile.readAsBytes();

      final audioId = const Uuid().v4();
      final uploadedAudio = await appwriteStorage.createFile(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: audioBytes, filename: '$audioId.m4a'),
      );
      final downloadUrl =
          '${AppwriteConstants.endpoint}/storage/buckets/${AppwriteConstants.chatFilesBucket}/files/${uploadedAudio.$id}/view?project=${AppwriteConstants.projectId}';

      await _processCommand(
        _applyFocusedHandle(_commandController.text),
        metadata: {
          'url': downloadUrl,
          'type': MessageType.audio,
          'fileName': '$audioId.m4a',
          'audioDuration': duration,
        },
      );
      _commandController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audio upload failed: $e',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Cancel recording (drag-to-delete) ──
  void _cancelRecording() async {
    if (!_isRecordingNotifier.value) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingCancelled = true;
    await _audioRecorder.stop();
    if (mounted) {
      _isRecordingNotifier.value = false;
      _recordingDragOffset = 0;
      _recordingSecondsNotifier.value = 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recording cancelled',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    }
  }

  // ── Send location ──
  Future<void> _sendLocation([String? composerSnapshot]) async {
    final text = _applyFocusedHandle(
      composerSnapshot ?? _commandController.text,
    );
    if (!_hasExplicitTarget(text)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before sharing location',
              style: GoogleFonts.jetBrainsMono(),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await _processCommand(
        text,
        metadata: {
          'type': MessageType.location,
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );
      _commandController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.jetBrainsMono()),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _processCommand(
    String text, {
    String? imageUrl,
    Map<String, dynamic>? metadata,
    String? textOverride,
    bool skipReplyMarkup = false,
  }) async {
    final normalizedText = _applyFocusedHandle(text);
    final words = normalizedText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final handles = <String>[];
    String msg = '';
    bool collectingHandles = true;

    for (var word in words) {
      if (collectingHandles && (word.startsWith('@') || word.startsWith('#'))) {
        handles.add(word.toLowerCase());
      } else {
        collectingHandles = false;
        if (msg.isNotEmpty) msg += ' ';
        msg += word;
      }
    }

    // All mentioned users (for adding to group)
    final mentionedUsersByHandle = <String, UserModel>{};
    for (final handle in handles.where((h) => h.startsWith('@'))) {
      final tHandle = _normalizeHandleToken(handle.substring(1));
      final targetUser = _normalizedUsersMap[tHandle];
      if (targetUser != null) {
        mentionedUsersByHandle[handle] = targetUser;
      }
    }

    // Determine message type and content
    MessageType type;
    String content;
    String? fileName;
    int? fileSize;
    int? audioDuration;
    double? latitude;
    double? longitude;

    if (metadata != null) {
      type = metadata['type'] as MessageType;
      content = (metadata['url'] as String?) ??
          'lat:${metadata['latitude']},lng:${metadata['longitude']}';
      fileName = metadata['fileName'] as String?;
      fileSize = metadata['fileSize'] as int?;
      audioDuration = metadata['audioDuration'] as int?;
      latitude = (metadata['latitude'] as num?)?.toDouble();
      longitude = (metadata['longitude'] as num?)?.toDouble();
    } else if (imageUrl != null) {
      type = MessageType.image;
      content = imageUrl;
    } else {
      type = MessageType.text;
      content = textOverride ?? msg;
    }

    if (!skipReplyMarkup &&
        type == MessageType.text &&
        _replyingToMessage != null) {
      content = '> Reply: ${_replyPreview(_replyingToMessage!)}\n$content';
    }

    if (content.isEmpty && type == MessageType.text && !handles.any((h) => h.startsWith('#'))) {
      return;
    }

    final groupHandles = handles.where((h) => h.startsWith('#')).toList();

    final currentUserName = cachedUserName;
    final currentUserPhoto = cachedUserPhotoUrl;
    bool sentAtLeastOne = false;
    final dmTargetsSent = <String>{};

    // Group handles for determining multi-target messaging
    for (var handle in handles) {
      if (handle.startsWith('@')) {
        // Only process @ mentions as DMs here if there's NO group target
        // If there's a group, mentioned users will be added to the group instead.
        if (groupHandles.isNotEmpty) {
          continue;
        }

        final tHandle = _normalizeHandleToken(handle.substring(1));
        final targetUser = _normalizedUsersMap[tHandle];

        if (targetUser != null) {
          if (!dmTargetsSent.add(targetUser.uid)) {
            continue;
          }
          final chatId = await _chatService.getOrCreateChat(
            currentUserId,
            targetUser.uid,
          );
          await _chatService.sendMessage(
            chatId: chatId,
            senderId: currentUserId,
            senderName: currentUserName,
            senderPhotoUrl: currentUserPhoto,
            text: content,
            type: type,
            fileName: fileName,
            fileSize: fileSize,
            audioDuration: audioDuration,
            latitude: latitude,
            longitude: longitude,
          );
          sentAtLeastOne = true;

          // ── Bot Auto-Reply Logic ──
          if (targetUser.isBot && type == MessageType.text) {
            final hasAiAccess = await _ensureAiAccess();
            if (!hasAiAccess) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'AI access is required to chat with bots.',
                      style: GoogleFonts.inter(),
                    ),
                  ),
                );
              }
              continue;
            }

            final botConfig = await _botService.getBotByName(
              targetUser.displayName,
            );
            if (botConfig != null) {
              String botPrompt = content;
              String systemPrompt = botConfig.instructions;

              if (currentUserId == botConfig.ownerId &&
                  content.toLowerCase().contains('summarize')) {
                final history = await _chatService.getUnreadMessages(
                  chatId,
                  currentUserId,
                );
                if (history.isNotEmpty) {
                  botPrompt =
                      'Context of recent messages:\n${history.reversed.map((m) => '${m.senderName}: ${m.text}').join('\n')}\n\nPrompt: $content';
                }
              }

              _aiService
                  .generateResponse(botPrompt, systemPrompt: systemPrompt)
                  .then((reply) {
                _chatService.sendMessage(
                  chatId: chatId,
                  senderId: targetUser.uid,
                  senderName: targetUser.displayName,
                  senderPhotoUrl: targetUser.photoUrl,
                  text: reply,
                );
              });
            }
          }
        }
      } else if (handle.startsWith('#')) {
        final parsed = GroupHandleResolver.parseAfterHash(handle.substring(1));
        if (parsed.nameToken.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Group name is missing. Use #groupname before your message.',
                  style: GoogleFonts.jetBrainsMono(),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
            );
          }
          continue;
        }
        final matches = GroupHandleResolver.matchingByName(
          _allGroups,
          parsed.nameToken,
        );

        String targetGroupId = '';
        var didGroupAction = false;

        if (matches.isEmpty) {
          if (parsed.idSuffix != null && parsed.idSuffix!.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'No group matches #${parsed.nameToken}~${parsed.idSuffix}',
                    style: GoogleFonts.jetBrainsMono(),
                  ),
                  shape:
                      RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
              );
            }
            continue;
          }
          final invitees = mentionedUsersByHandle.values
              .where((u) => u.uid != currentUserId)
              .map((u) => u.uid)
              .toSet()
              .toList();

          targetGroupId = await _groupService.createGroup(
            name: _displayGroupNameFromToken(parsed.nameToken),
            description: 'Created from #${parsed.nameToken}',
            createdBy: currentUserId,
            members: invitees,
          );
          didGroupAction = true;
        } else {
          GroupModel? targetGroup;
          if (parsed.idSuffix != null && parsed.idSuffix!.isNotEmpty) {
            targetGroup =
                GroupHandleResolver.pickByIdSuffix(matches, parsed.idSuffix!);
            if (targetGroup == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No match for #${parsed.nameToken}~${parsed.idSuffix}',
                      style: GoogleFonts.jetBrainsMono(),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                );
              }
              continue;
            }
          } else if (matches.length == 1) {
            targetGroup = matches.first;
          } else {
            targetGroup = await _pickGroupWhenAmbiguous(matches);
            if (targetGroup == null) {
              continue;
            }
          }

          targetGroupId = targetGroup.groupId;
          final inviteUids = mentionedUsersByHandle.values
              .map((u) => u.uid)
              .where((id) => id != currentUserId)
              .toSet()
              .toList();
          if (inviteUids.isNotEmpty) {
            await _groupService.addMembers(
              targetGroupId,
              inviteUids,
              currentUserName.isEmpty ? 'Member' : currentUserName,
              actorUserId: currentUserId,
            );
            didGroupAction = true;
          }
        }

        if (targetGroupId.isNotEmpty &&
            (content.isNotEmpty || type != MessageType.text)) {
          await _groupService.sendGroupMessage(
            groupId: targetGroupId,
            senderId: currentUserId,
            senderName: currentUserName,
            senderPhotoUrl: currentUserPhoto,
            text: content,
            type: type,
            fileName: fileName,
            fileSize: fileSize,
            audioDuration: audioDuration,
            latitude: latitude,
            longitude: longitude,
          );
          didGroupAction = true;
        }

        if (didGroupAction) {
          sentAtLeastOne = true;
        }
      }
    }

    if (!mounted) return;
    if (!sentAtLeastOne) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No valid targets found.',
            style: GoogleFonts.jetBrainsMono(),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      );
    } else if (_replyingToMessage != null) {
      setState(() {
        _replyingToMessage = null;
      });
    }
  }

  String _replyPreview(MessageModel message) {
    switch (message.type) {
      case MessageType.image:
        return 'Photo';
      case MessageType.file:
        return message.fileName?.isNotEmpty == true
            ? message.fileName!
            : 'File';
      case MessageType.audio:
        return 'Voice message';
      case MessageType.location:
        return 'Location';
      case MessageType.system:
      case MessageType.text:
        final text = message.text.replaceAll('\n', ' ').trim();
        return text.isEmpty ? 'Message' : text;
    }
  }

  void _sendCommand(String input) async {
    if (input.trim().isEmpty && _forwardingMessage == null) return;

    final normalizedInput = _applyFocusedHandle(input);

    if (_forwardingMessage != null) {
      await _forwardPendingMessage(input);
      return;
    }

    final trimmedCmd = normalizedInput.trim();

    final newBotSlash = RegExp(
      r'^/newbot\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmedCmd);
    if (newBotSlash != null) {
      final botName = newBotSlash.group(1)!.trim();
      if (botName.isNotEmpty) {
        _showBotConfigDialog(botName);
        _commandController.clear();
        return;
      }
    }
    if (RegExp(r'^/newbot\s*$', caseSensitive: false).hasMatch(trimmedCmd)) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usage: /newbot AssistantName',
              style: GoogleFonts.inter(
                color: cs.onInverseSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: cs.inverseSurface,
          ),
        );
      }
      _commandController.clear();
      return;
    }

    // Private AI (notes thread): @ai …
    final lowerCmd = normalizedInput.toLowerCase();
    String? privateAiPrompt;
    if (lowerCmd.startsWith('@ai ')) {
      privateAiPrompt = normalizedInput.substring(4).trim();
    }
    if (privateAiPrompt != null && privateAiPrompt.isNotEmpty) {
      _commandController.clear();
      setState(() => _isAiLoading = true);
      try {
        final chatId = await _chatService.getOrCreateChat(
          currentUserId,
          currentUserId,
        );

        await _chatService.sendMessage(
          chatId: chatId,
          senderId: currentUserId,
          senderName: cachedUserName,
          senderPhotoUrl: cachedUserPhotoUrl,
          text: privateAiPrompt,
          type: MessageType.text,
        );

        final aiResponse = await _aiService.generateResponse(
          privateAiPrompt,
          systemPrompt:
              "You are PointChat's private AI assistant. Be helpful and concise.",
        );

        await _chatService.sendMessage(
          chatId: chatId,
          senderId: 'ai-system',
          senderName: 'PointChat AI',
          senderPhotoUrl: '',
          text: aiResponse,
          type: MessageType.text,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'AI is temporarily unavailable.',
                style: GoogleFonts.inter(),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isAiLoading = false);
      }
      return;
    }

    // Check for AI mode: if text contains /, extract the AI prompt
    final slashIndex = normalizedInput.indexOf('/');
    if (slashIndex >= 0) {
      final beforeSlash = normalizedInput.substring(0, slashIndex).trim();
      final aiPrompt = normalizedInput.substring(slashIndex + 1).trim();

      if (aiPrompt.toLowerCase().startsWith('setting')) {
        final targetHandle = beforeSlash
            .split(' ')
            .where((word) => word.startsWith('@') || word.startsWith('#'))
            .cast<String?>()
            .firstWhere((word) => word != null, orElse: () => _focusedHandle);
        _commandController.clear();
        if (targetHandle != null && targetHandle.isNotEmpty) {
          await _showSettingsOverlayForHandle(targetHandle);
        } else {
          await _showMyProfileOverlay();
        }
        return;
      }

      final newBotFromSlash = RegExp(
        r'^newbot\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(aiPrompt);
      if (newBotFromSlash != null) {
        _commandController.clear();
        _showBotConfigDialog(newBotFromSlash.group(1)!.trim());
        return;
      }
      if (aiPrompt.toLowerCase().trim() == 'newbot') {
        if (mounted) {
          final cs = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Usage: /newbot AssistantName',
                style: GoogleFonts.inter(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: cs.inverseSurface,
            ),
          );
        }
        _commandController.clear();
        return;
      }

      // Ensure there are @user or #group targets before the /
      final hasTarget = _hasExplicitTarget(beforeSlash);

      if (hasTarget && aiPrompt.isNotEmpty) {
        final hasAiAccess = await _ensureAiAccess();
        if (!hasAiAccess) {
          return;
        }

        setState(() => _isAiLoading = true);
        _commandController.clear();

        try {
          String finalPrompt = aiPrompt;
          final aiPromptLower = aiPrompt.toLowerCase();
          final isSummaryRequest = aiPromptLower.contains('summarize') ||
              aiPromptLower.contains('summary');

          if (isSummaryRequest) {
            final words = beforeSlash.split(' ');
            final handles = words
                .where((w) => w.startsWith('@') || w.startsWith('#'))
                .toList();

            String contextText = '';
            final onlyUnread = aiPromptLower.contains('unread');

            for (var handle in handles) {
              if (handle.startsWith('@')) {
                final tNorm = _normalizeHandleToken(handle.substring(1));
                final targetUser = _normalizedUsersMap[tNorm];
                if (targetUser != null) {
                  final chatId = await _chatService.getOrCreateChat(
                    currentUserId,
                    targetUser.uid,
                  );
                  List<MessageModel> msgs = [];
                  if (onlyUnread) {
                    msgs = await _chatService.getUnreadMessages(
                      chatId,
                      currentUserId,
                    );
                  } else {
                    // Fetch last 50 messages for general summary
                    final result = await appwriteTablesDB.listRows(
                      databaseId: AppwriteConstants.databaseId,
                      tableId: AppwriteConstants.messagesCollection,
                      queries: [
                        Query.equal('chatId', chatId),
                        Query.orderDesc('\$createdAt'),
                        Query.limit(50),
                      ],
                    );
                    msgs = result.rows
                        .map((doc) => MessageModel.fromMap(doc.data, doc.$id))
                        .toList();
                  }

                  if (msgs.isNotEmpty) {
                    contextText +=
                        '\nMessages with @${targetUser.displayName}:\n';
                    for (var msg in msgs.reversed) {
                      contextText += '${msg.senderName}: ${msg.text}\n';
                    }
                  }
                }
              } else if (handle.startsWith('#')) {
                final targetGroup = await _resolveGroupForAiContext(handle);
                if (targetGroup != null) {
                  List<MessageModel> msgs = [];
                  if (onlyUnread) {
                    msgs = await _groupService.getUnreadGroupMessages(
                      targetGroup.groupId,
                      currentUserId,
                    );
                  } else {
                    // Fetch last 50 messages for general summary
                    final result = await appwriteTablesDB.listRows(
                      databaseId: AppwriteConstants.databaseId,
                      tableId: AppwriteConstants.messagesCollection,
                      queries: [
                        Query.equal('groupId', targetGroup.groupId),
                        Query.orderDesc('\$createdAt'),
                        Query.limit(50),
                      ],
                    );
                    msgs = result.rows
                        .map((doc) => MessageModel.fromMap(doc.data, doc.$id))
                        .toList();
                  }
                  if (msgs.isNotEmpty) {
                    contextText += '\nMessages in #${targetGroup.name}:\n';
                    for (var msg in msgs.reversed) {
                      contextText += '${msg.senderName}: ${msg.text}\n';
                    }
                  }
                }
              }
            }

            if (contextText.isNotEmpty) {
              finalPrompt =
                  'Conversation context:\n$contextText\n\nTask: $aiPrompt\nWrite a clean summary using the provided messages only. Do not invent details.';
            } else {
              finalPrompt =
                  '$aiPrompt\nNo saved messages were found for the selected conversation.';
            }
          } else {
            // Normal prompt - tell AI not to use markers
            finalPrompt =
                '$aiPrompt\nRespond professionally without any weird markers or asterisks before the text. Format cleanly.';
          }

          // Send the user's prompt as a message first
          await _processCommand('$beforeSlash Prompt: $aiPrompt');

          // Generate AI response
          final aiResponse = await _aiService.generateResponse(finalPrompt);

          // Send the AI response to the same targets without any markers
          await _processCommand('$beforeSlash $aiResponse');
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'AI is temporarily unavailable. Please try again.',
                  style: GoogleFonts.inter(),
                ),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isAiLoading = false);
        }
        return;
      }
    }

    await _processCommand(normalizedInput);
    _commandController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: NestedScrollView(
                    floatHeaderSlivers: true,
                    headerSliverBuilder: (context, innerBoxIsScrolled) {
                      return [
                        SliverAppBar(
                          floating: true,
                          snap: true,
                          elevation: 0,
                          backgroundColor: Theme.of(
                            context,
                          ).scaffoldBackgroundColor,
                          bottom: PreferredSize(
                            preferredSize: const Size.fromHeight(1.0),
                            child: Container(
                              color: Theme.of(context).colorScheme.outline,
                              height: 1.0,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.zero,
                                    child: Image.asset(
                                      'assets/icon.png',
                                      width: 26,
                                      height: 26,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'PointChat',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Consumer(
                                    builder: (context, ref, child) {
                                      final themeMode = ref.watch(
                                        themeModeProvider,
                                      );
                                      final isDark =
                                          themeMode == ThemeMode.dark;
                                      return IconButton(
                                        icon: Icon(
                                          isDark
                                              ? Icons.light_mode
                                              : Icons.dark_mode,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                          size: 20,
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(themeModeProvider.notifier)
                                              .toggle();
                                        },
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.logout_rounded,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 20,
                                    ),
                                    onPressed: () => AuthService().signOut(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                    body: _buildCombinedStream(),
                  ),
                ),
                _buildCommandBar(),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.purple,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCombinedStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Stream error: ${snapshot.error}');
          return Center(
            child: Text(
              'We could not load conversations right now.',
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.purple,
              strokeWidth: 2,
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Type @name or #group to start',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: false,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isExpanded = _expandedItemId == item['id'];

            return StreamItemWidget(
              key: ValueKey(item['id']),
              item: item,
              isExpanded: isExpanded,
              isFocusLocked: _focusedHandle == item['handle'],
              currentUserId: currentUserId,
              chatService: _chatService,
              groupService: _groupService,
              inviteService: _inviteService,
              userService: _userService,
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedItemId = null;
                    if (_focusedHandle == item['handle']) {
                      _focusedHandle = null;
                    }
                  } else {
                    _expandedItemId = item['id'] as String?;
                    _focusedHandle = item['handle'] as String?;
                  }
                });
                if (!isExpanded) {
                  if (item['type'] == 'dm') {
                    _chatService.markMessagesAsRead(item['id'], currentUserId);
                  } else if (item['type'] == 'group') {
                    _groupService.markGroupAsRead(item['id'], currentUserId);
                  }
                }
              },
              onLongPress: () {
                setState(() {
                  if (_focusedHandle == item['handle']) {
                    _focusedHandle = null; // Toggle off if already focused
                  } else {
                    _focusedHandle = item['handle'] as String?;
                    _expandedItemId = item['id'] as String?; // Auto-expand
                  }
                });
                if (_focusedHandle == item['handle']) {
                  if (item['type'] == 'dm') {
                    _chatService.markMessagesAsRead(item['id'], currentUserId);
                  } else if (item['type'] == 'group') {
                    _groupService.markGroupAsRead(item['id'], currentUserId);
                  }
                }
              },
              onReply: (replyData) {
                final targetHandle = replyData['targetHandle'] as String;
                final replyMessage = replyData['message'] as MessageModel;
                _commandController.text = '$targetHandle ';
                _commandController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _commandController.text.length),
                );
                setState(() {
                  _replyingToMessage = replyMessage;
                });
                _commandFocusNode.requestFocus();
              },
              onForward: (msg) {
                setState(() {
                  _forwardingMessage = msg;
                });
                _commandFocusNode.requestFocus();
              },
              onSwipeLeft: () => _lockChat(item),
              onSwipeRight: () => _deleteChat(item),
              onHandleTap: (handle) {
                _insertHandleIntoComposer(handle);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommandBar() {
    final isFocusModeActive = _focusedHandle != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyingToMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.purple,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Replying to ${_replyingToMessage!.senderName}',
                        style: GoogleFonts.inter(
                          color: AppTheme.purpleLt,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyPreview(_replyingToMessage!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _replyingToMessage = null;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        if (_forwardingMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.zero,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.focusBlue,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forwarding message',
                        style: GoogleFonts.inter(
                          color: AppTheme.focusBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _replyPreview(_forwardingMessage!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _forwardingMessage = null;
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        Builder(
          builder: (context) {
            final sel = _commandController.selection;
            final txt = _commandController.text;
            final safeOffset = sel.baseOffset.clamp(0, txt.length);
            final tbc = txt.substring(0, safeOffset);
            final atIdx = tbc.lastIndexOf('@');
            final atQueryNorm = atIdx >= 0
                ? _normalizeHandleToken(tbc.substring(atIdx + 1))
                : '';

            final showAtExtras = _activeMentionKind == '@';
            final showPanel = _isMentioning &&
                (_mentionSuggestions.isNotEmpty ||
                    (showAtExtras &&
                        (_globalMentionLoading ||
                            (_mentionScopeEveryone &&
                                atQueryNorm.length < 2))));

            if (!showPanel) {
              return const SizedBox.shrink();
            }

            final scheme = Theme.of(context).colorScheme;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.zero,
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showAtExtras)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                      child: Row(
                        children: [
                          FilterChip(
                            label: Text(
                              'In your chats',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            selected: !_mentionScopeEveryone,
                            showCheckmark: false,
                            onSelected: (v) {
                              if (!v) {
                                return;
                              }
                              setState(() {
                                _mentionScopeEveryone = false;
                                _globalMentionResults = [];
                                _mentionSearchDebounce?.cancel();
                                _globalMentionLoading = false;
                              });
                              _onCommandChanged();
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(
                              'Everyone',
                              style: GoogleFonts.inter(fontSize: 12),
                            ),
                            selected: _mentionScopeEveryone,
                            showCheckmark: false,
                            onSelected: (v) {
                              if (!v) {
                                return;
                              }
                              setState(() => _mentionScopeEveryone = true);
                              _onCommandChanged();
                            },
                          ),
                        ],
                      ),
                    ),
                  if (showAtExtras &&
                      _mentionScopeEveryone &&
                      atQueryNorm.length < 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      child: Text(
                        'Type at least 2 letters to search all users',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (showAtExtras && _globalMentionLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.focusBlue,
                          ),
                        ),
                      ),
                    ),
                  if (_mentionSuggestions.isEmpty &&
                      showAtExtras &&
                      _mentionScopeEveryone &&
                      atQueryNorm.length >= 2 &&
                      !_globalMentionLoading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Text(
                        'No users match your search',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (_mentionSuggestions.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        itemCount: _mentionSuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _mentionSuggestions[index];
                          final isUser = suggestion is UserModel;
                          final isGroup = suggestion is GroupModel;
                          final isCreateGroup =
                              suggestion is _CreateGroupSuggestion;
                          final isAtCmd = suggestion is _AtCommandSuggestion;
                          final isAction = suggestion is String;
                          final isSlashCommand =
                              isAction && suggestion.startsWith('/');
                          final name = isUser
                              ? suggestion.displayName
                              : isGroup
                                  ? suggestion.name
                                  : isCreateGroup
                                      ? suggestion.token
                                      : isAtCmd
                                          ? suggestion.label
                                          : suggestion.toString();
                          GroupModel? groupPick;
                          if (isGroup) {
                            groupPick = suggestion;
                          }
                          final handle = isUser
                              ? _formatHandle(name)
                              : groupPick != null
                                  ? GroupHandleResolver.composerHandleForGroup(
                                      groupPick,
                                      _allGroups,
                                    )
                                  : isCreateGroup
                                      ? '#${suggestion.token}'
                                      : isAtCmd
                                          ? suggestion.label
                                          : name;

                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isUser
                                  ? Icons.person_outline_rounded
                                  : isGroup
                                      ? Icons.groups_2_outlined
                                      : isCreateGroup
                                          ? Icons.group_add_outlined
                                          : isAtCmd
                                              ? Icons.smart_toy_outlined
                                              : isSlashCommand
                                                  ? Icons.bolt_rounded
                                                  : Icons.location_on_outlined,
                              color: isUser
                                  ? AppTheme.focusBlue
                                  : isGroup
                                      ? AppTheme.green
                                      : isCreateGroup
                                          ? AppTheme.focusBlue
                                          : isAtCmd
                                              ? AppTheme.focusBlue
                                              : isSlashCommand
                                                  ? AppTheme.focusBlue
                                                  : scheme.primary,
                              size: 20,
                            ),
                            title: Text(
                              isCreateGroup
                                  ? 'Create new group $handle'
                                  : handle,
                              style: GoogleFonts.inter(
                                color: scheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: suggestion is _AtCommandSuggestion
                                ? Text(
                                    suggestion.hint,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                : groupPick != null
                                    ? Text(
                                        groupPick.groupId.length <= 10
                                            ? groupPick.groupId
                                            : '${groupPick.groupId.substring(0, 10)}…',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 10,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      )
                                    : null,
                            onTap: () {
                              if (isAtCmd) {
                                final text = _commandController.text;
                                final selection = _commandController.selection;
                                final textBeforeCursor = text.substring(
                                  0,
                                  selection.baseOffset,
                                );
                                final textAfterCursor = text.substring(
                                  selection.baseOffset,
                                );
                                final lastAt =
                                    textBeforeCursor.lastIndexOf('@');
                                if (lastAt < 0) {
                                  return;
                                }
                                final newText =
                                    '${textBeforeCursor.substring(0, lastAt + 1)}${suggestion.insertStem}$textAfterCursor';
                                final newOffset =
                                    lastAt + 1 + suggestion.insertStem.length;
                                _commandController.value = TextEditingValue(
                                  text: newText,
                                  selection: TextSelection.collapsed(
                                    offset: newOffset,
                                  ),
                                );
                                setState(() {
                                  _isMentioning = false;
                                  _mentionSuggestions = [];
                                });
                                _focusComposerAfterFrame();
                                return;
                              }

                              if (isAction) {
                                if (isSlashCommand) {
                                  setState(() {
                                    _isMentioning = false;
                                    _mentionSuggestions = [];
                                  });
                                  _insertSlashCommand(suggestion);
                                  return;
                                }
                                return;
                              }

                              final text = _commandController.text;
                              final selection = _commandController.selection;
                              final textBeforeCursor = text.substring(
                                0,
                                selection.baseOffset,
                              );
                              final textAfterCursor = text.substring(
                                selection.baseOffset,
                              );

                              final lastAt = textBeforeCursor.lastIndexOf('@');
                              final lastHash =
                                  textBeforeCursor.lastIndexOf('#');
                              final lastPrefixIndex =
                                  isUser ? lastAt : lastHash;

                              final newText =
                                  '${textBeforeCursor.substring(0, lastPrefixIndex)}$handle $textAfterCursor';
                              _commandController.text = newText;
                              _commandController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset: lastPrefixIndex + handle.length + 1,
                                ),
                              );

                              setState(() {
                                _isMentioning = false;
                                _mentionSuggestions = [];
                              });
                              _focusComposerAfterFrame();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: ComposerPreferences.tipsHiddenListenable,
          builder: (context, tipsHidden, _) {
            if (tipsHidden ||
                !_composerTipsLoaded ||
                PointchatTips.instance.rotatingTips.isEmpty ||
                _isAiMode ||
                _replyingToMessage != null ||
                _forwardingMessage != null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 1, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.tips_and_updates_outlined,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      PointchatTips.instance.rotatingTips[_composerTipIndex %
                          PointchatTips.instance.rotatingTips.length],
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        height: 1.25,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.72),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Tooltip(
                    message: _tipsRotateEnabled
                        ? 'Pause tip rotation'
                        : 'Resume tip rotation',
                    child: InkWell(
                      onTap: _toggleTipRotation,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                        child: Icon(
                          _tipsRotateEnabled
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (details.primaryDelta! < -5) {
                      setState(() => _showActions = true);
                    } else if (details.primaryDelta! > 5) {
                      setState(() {
                        _showActions = false;
                      });
                    }
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.transparent, width: 0),
                      boxShadow: isFocusModeActive
                          ? [
                              BoxShadow(
                                color: AppTheme.focusBlue.withValues(
                                  alpha: 0.16,
                                ),
                                blurRadius: 18,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // The normal text input field (always in tree to maintain keyboard focus)
                        Row(
                          children: [
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  ComposerPreferences.tipsHiddenListenable,
                              builder: (context, tipsHidden, _) {
                                if (tipsHidden) return const SizedBox.shrink();
                                return IconButton(
                                  tooltip: 'Commands & tips',
                                  icon: Icon(
                                    Icons.tips_and_updates_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    size: 22,
                                  ),
                                  onPressed: _showCommandHelpSheet,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: TextField(
                                controller: _commandController,
                                focusNode: _commandFocusNode,
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: _isAiMode
                                      ? 'Ask the AI…'
                                      : (isFocusModeActive
                                          ? 'Message $_focusedHandle…'
                                          : 'Message · @ name  # group'),
                                  hintStyle: GoogleFonts.inter(
                                    color: _isAiMode
                                        ? AppTheme.focusBlue.withValues(
                                            alpha: 0.85,
                                          )
                                        : (isFocusModeActive
                                            ? AppTheme.focusBlue.withValues(
                                                alpha: 0.85,
                                              )
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.65)),
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: Colors.transparent,
                                ),
                                cursorColor: AppTheme.focusBlue,
                                onSubmitted: _sendCommand,
                              ),
                            ),
                            if (_showActions) ...[
                              IconButton(
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: _pickAndSendImage,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.attach_file_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: _pickAndSendFile,
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.location_on_outlined,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  size: 24,
                                ),
                                onPressed: _sendLocation,
                              ),
                            ],
                            if (!_showActions)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _commandController,
                                builder: (context, value, child) {
                                  final hasText = value.text.trim().isNotEmpty;
                                  final canSend =
                                      hasText || _forwardingMessage != null;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_isAiLoading)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 12),
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: AppTheme.focusBlue,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      else if (canSend)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              _isAiMode
                                                  ? Icons.auto_awesome_rounded
                                                  : (_forwardingMessage != null
                                                      ? Icons.forward_rounded
                                                      : Icons
                                                          .arrow_forward_rounded),
                                              color: isFocusModeActive
                                                  ? AppTheme.focusBlue
                                                  : AppTheme.focusBlue,
                                              size: 26,
                                            ),
                                            onPressed: () => _sendCommand(
                                              _commandController.text,
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                        // The recording overlay (covers text field while recording)
                        ValueListenableBuilder<bool>(
                          valueListenable: _isRecordingNotifier,
                          builder: (context, isRecording, _) {
                            if (!isRecording) return const SizedBox.shrink();
                            return Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Row(
                                children: [
                                  const SizedBox(width: 14),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.red.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mic,
                                      color: AppTheme.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ValueListenableBuilder<int>(
                                    valueListenable: _recordingSecondsNotifier,
                                    builder: (context, seconds, _) {
                                      return Text(
                                        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                                        style: GoogleFonts.inter(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: Transform.translate(
                                      offset: Offset(
                                        _recordingDragOffset.clamp(-100.0, 0.0),
                                        0,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '< Slide to cancel',
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: AnimatedScale(
                                      scale: _recordingDragOffset < -50
                                          ? 1.4
                                          : 1.0,
                                      duration: const Duration(
                                        milliseconds: 150,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: _recordingDragOffset < -50
                                            ? AppTheme.red
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_showActions)
                GestureDetector(
                  onLongPressStart: (_) => _startRecording(),
                  onLongPressMoveUpdate: (details) {
                    setState(() {
                      _recordingDragOffset = details.localOffsetFromOrigin.dx;
                    });
                    if (_recordingDragOffset < -80) {
                      _cancelRecording();
                    }
                  },
                  onLongPressEnd: (_) => _stopAndSendRecording(),
                  child: Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.zero,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(Icons.mic, color: Colors.black, size: 24),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBotConfigDialog(String botName) async {
    final existingBot = await _botService.getBotByName(botName);
    final isOwner = existingBot == null || existingBot.ownerId == currentUserId;

    if (!isOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are not the owner of this bot.',
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }
      return;
    }

    final instructionsController = TextEditingController(
      text: existingBot?.instructions ?? '',
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  existingBot == null ? 'CREATE BOT' : 'EDIT BOT',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '@$botName',
              style:
                  GoogleFonts.outfit(color: AppTheme.focusBlue, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: instructionsController,
              maxLines: 5,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: const InputDecoration(
                labelText: 'Instructions / System Prompt',
                hintText:
                    'e.g. You are a business assistant for Dr. Amrh. Help users schedule appointments...',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final instructions = instructionsController.text.trim();
                  if (instructions.isEmpty) return;

                  Navigator.pop(context);
                  setState(() => _isAiLoading = true);

                  try {
                    late final BotModel bot;
                    if (existingBot == null) {
                      bot = await _botService.createBot(
                        name: botName,
                        ownerId: currentUserId,
                        instructions: instructions,
                      );
                    } else {
                      bot = existingBot;
                      await _botService.updateBot(existingBot.botId, {
                        'instructions': instructions,
                      });
                    }
                    await _chatService.getOrCreateChat(
                      currentUserId,
                      bot.botId,
                    );
                    if (mounted) {
                      setState(() {
                        if (!_allUsers.any((user) => user.uid == bot.botId)) {
                          _allUsers = [
                            ..._allUsers,
                            UserModel(
                              uid: bot.botId,
                              displayName: botName,
                              email: 'bot-${bot.botId}@pointchat.ai',
                              isBot: true,
                              status: 'Custom AI Bot',
                            ),
                          ];
                          _normalizedUsersMap.clear();
                          for (final u in _allUsers) {
                            _normalizedUsersMap[
                                _normalizeHandleToken(u.displayName)] = u;
                          }
                        }
                        _focusedHandle = _formatHandle(botName);
                      });
                    }
                    _commandController.clear();
                    _commandFocusNode.requestFocus();
                    if (context.mounted) {
                      final cs = Theme.of(context).colorScheme;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: cs.inverseSurface,
                          content: Text(
                            'Bot @$botName is ready — open it from the list.',
                            style: GoogleFonts.inter(
                              color: cs.onInverseSurface,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final cs = Theme.of(context).colorScheme;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: cs.errorContainer,
                          content: Text(
                            'Could not save your bot. Please try again.',
                            style: GoogleFonts.inter(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _isAiLoading = false);
                  }
                },
                child: Text(existingBot == null ? 'CREATE' : 'SAVE'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _CreateGroupSuggestion {
  final String token;
  const _CreateGroupSuggestion(this.token);
}

class DateSeparator extends StatelessWidget {
  final String dateText;
  const DateSeparator({super.key, required this.dateText});

  @override
  Widget build(BuildContext context) {
    // Hidden — we no longer show a LATEST label
    return const SizedBox.shrink();
  }
}

class StreamItemWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isExpanded;
  final bool isFocusLocked;
  final String currentUserId;
  final ChatService chatService;
  final GroupService groupService;
  final InviteService inviteService;
  final UserService userService;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<String> onHandleTap;
  final void Function(Map<String, dynamic>) onReply;
  final void Function(MessageModel) onForward;
  final VoidCallback onSwipeLeft; // Lock/hide chat
  final VoidCallback onSwipeRight; // Delete chat

  const StreamItemWidget({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.isFocusLocked,
    required this.currentUserId,
    required this.chatService,
    required this.groupService,
    required this.inviteService,
    required this.userService,
    required this.onTap,
    required this.onLongPress,
    required this.onHandleTap,
    required this.onReply,
    required this.onForward,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<StreamItemWidget> createState() => _StreamItemWidgetState();
}

class _StreamItemWidgetState extends State<StreamItemWidget> with SingleTickerProviderStateMixin {
  bool _showInfo = false;
  late AnimationController _swipeController;

  double _presencePct(dynamic raw) {
    if (raw is num) {
      return raw.toDouble().clamp(0.0, 1.0);
    }
    final parsed = double.tryParse(raw?.toString() ?? '');
    return (parsed ?? 0.0).clamp(0.0, 1.0);
  }

  String _safePhotoUrl(dynamic raw) {
    final s = (raw?.toString() ?? '').trim();
    if (s.isEmpty || s.toLowerCase() == 'null') {
      return '';
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _swipeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _swipeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StreamItemWidget oldWidget) {
    if (!widget.isExpanded && oldWidget.isExpanded) {
      _showInfo = false;
    }
    super.didUpdateWidget(oldWidget);
  }

  Widget _buildAvatar(Map<String, dynamic> item, ColorScheme colorScheme) {
    final String handleText = item['handle'] ?? '?';
    final isGroup = item['type'] == 'group' || handleText.startsWith('#');
    final double percentage = _presencePct(item['onlinePercentage']);
    final String photoUrl = _safePhotoUrl(item['photoUrl']);
    final bool isAiSelfChat = item['isAiSelfChat'] == true;
    final bool isBotDm = item['isBotDm'] == true;
    final titleForInitial =
        (item['conversationTitle'] as String?)?.trim() ?? '';
    final fromHandle = handleText.replaceAll(RegExp(r'[@#]'), '').trim();
    final String initialsSource =
        titleForInitial.isNotEmpty ? titleForInitial : fromHandle;
    final String initials = initialsSource.isNotEmpty
        ? initialsSource.characters.first.toUpperCase()
        : '?';

    Widget innerAvatar;
    if (isAiSelfChat || isBotDm) {
      innerAvatar = Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              AppTheme.focusBlue,
              AppTheme.focusBlue.withValues(alpha: 0.65),
            ],
          ),
          border: Border.all(
            color: AppTheme.focusBlue.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.smart_toy_rounded,
          color: Colors.white,
          size: 20,
        ),
      );
    } else if (photoUrl.isNotEmpty) {
      innerAvatar = ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (context, _) => _buildInitials(initials, colorScheme),
          errorWidget: (context, _, __) =>
              _buildInitials(initials, colorScheme),
        ),
      );
    } else {
      innerAvatar = _buildInitials(initials, colorScheme);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isFocusLocked)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.focusBlue, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.focusBlue.withValues(alpha: 0.18),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          // Online ring for DMs
          if (!widget.isFocusLocked && !isGroup)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: percentage > 0
                      ? AppTheme.green
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
          // Arc for groups
          if (isGroup)
            CustomPaint(
              size: const Size.square(40),
              painter: _PresenceRingPainter(
                percentage: percentage,
                color: AppTheme.green,
                trackColor: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
          innerAvatar,
        ],
      ),
    );
  }

  Widget _buildInitials(String initials, ColorScheme colorScheme) {
    final String handleText = widget.item['handle'] ?? '';
    final isGroup =
        widget.item['type'] == 'group' || handleText.startsWith('#');
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dmFill = isLight
        ? AppTheme.focusBlue.withValues(alpha: 0.12)
        : AppTheme.focusBlue.withValues(alpha: 0.22);
    final dmBorder = AppTheme.focusBlue.withValues(alpha: isLight ? 0.35 : 0.5);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: widget.isFocusLocked
            ? AppTheme.focusBlue.withValues(alpha: 0.18)
            : (isGroup
                ? (isLight
                    ? AppTheme.green.withValues(alpha: 0.12)
                    : const Color(0xFF1A2A1A))
                : dmFill),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isFocusLocked
              ? AppTheme.focusBlue.withValues(alpha: 0.8)
              : (isGroup ? AppTheme.green.withValues(alpha: 0.35) : dmBorder),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            color: widget.isFocusLocked
                ? AppTheme.focusBlue
                : (isGroup ? AppTheme.green : AppTheme.focusBlue),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = widget.item['isUnread'] ?? false;
    final isImage = widget.item['image'] == true;
    final String handleText = widget.item['handle'] ?? '';
    final String conversationTitle =
        (widget.item['conversationTitle'] as String?)?.trim() ?? '';
    final isGroup = handleText.startsWith('#');
    final pendingRowIds = (widget.item['pendingInviteIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final showInviteRow =
        isGroup && pendingRowIds.contains(widget.currentUserId);
    // Blue for DM (@), green for group (#); online rings stay green.
    final handlePrefixColor = isGroup ? AppTheme.green : AppTheme.focusBlue;
    final tileBorderColor = widget.isFocusLocked
        ? AppTheme.focusBlue.withValues(alpha: 0.8)
        : (isUnread
            ? AppTheme.focusBlue.withValues(alpha: 0.45)
            : Theme.of(context).colorScheme.outline);
    final tileBackgroundColor = widget.isFocusLocked
        ? AppTheme.focusBlueGlow
        : (isUnread
            ? AppTheme.focusBlue.withValues(alpha: 0.07)
            : Theme.of(context).colorScheme.surface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: ValueKey(widget.item['id'] ?? widget.item['handle']),
        direction: widget.isExpanded
            ? DismissDirection.none
            : DismissDirection.horizontal,
        dismissThresholds: const {DismissDirection.horizontal: 0.3},
        movementDuration: const Duration(milliseconds: 200),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            widget.onSwipeRight();
          } else if (direction == DismissDirection.endToStart) {
            widget.onSwipeLeft();
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: AppTheme.red,
          child: Row(
            children: [
              const Icon(Icons.delete_outline, color: Colors.white),
              const SizedBox(width: 8),
              Text('Delete',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: AppTheme.focusBlue,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Lock',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              const Icon(Icons.lock_outline, color: Colors.white),
            ],
          ),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.zero,
          splashColor: AppTheme.purpleGlow,
          highlightColor: AppTheme.purpleGlow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: tileBackgroundColor,
              borderRadius: BorderRadius.zero,
              border: Border.all(
                color: tileBorderColor,
                width: widget.isFocusLocked || isUnread ? 1.6 : 1,
              ),
              boxShadow: (widget.isFocusLocked || isUnread)
                  ? [
                      BoxShadow(
                        color: widget.isFocusLocked
                            ? AppTheme.focusBlue.withValues(alpha: 0.12)
                            : AppTheme.purple.withValues(alpha: 0.08),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(widget.item, Theme.of(context).colorScheme),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => widget.onHandleTap(handleText),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isGroup
                                          ? Icons.groups_2_outlined
                                          : (widget.item['isAiSelfChat'] == true
                                              ? Icons.smart_toy_outlined
                                              : Icons.person_outline_rounded),
                                      size: 14,
                                      color: handlePrefixColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      conversationTitle.isNotEmpty
                                          ? conversationTitle
                                          : (handleText.length > 1
                                              ? handleText.substring(1)
                                              : handleText),
                                      style:
                                          AppTheme.chatConversationTitleStyle(
                                        context,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                widget.item['time'] ?? '',
                                style: GoogleFonts.inter(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 13,
                                height: 1.4,
                              ),
                              children: [
                                if (isGroup)
                                  TextSpan(
                                    text: '${widget.item['sender']}  ',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (isImage)
                                  WidgetSpan(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      size: 14,
                                    ),
                                  ),
                                TextSpan(text: widget.item['content']),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: const BoxDecoration(
                          color: AppTheme.purple,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (showInviteRow) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _compactInviteAction(
                          label: 'Accept',
                          color: AppTheme.green,
                          onTap: () async {
                            final gid = widget.item['id'] as String;
                            await widget.groupService.approvePendingMembership(
                              gid,
                              widget.currentUserId,
                            );
                            await widget.inviteService.approveInvite(
                              groupId: gid,
                              userId: widget.currentUserId,
                            );
                            await widget.groupService.sendGroupMessage(
                              groupId: gid,
                              senderId: 'system',
                              senderName: 'System',
                              text:
                                  '${cachedUserName.isEmpty ? 'User' : cachedUserName} joined the group',
                              type: MessageType.system,
                              skipUnreadIncrementFor: widget.currentUserId,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _compactInviteAction(
                          label: 'Exit',
                          color: AppTheme.red,
                          onTap: () async {
                            final gid = widget.item['id'] as String;
                            await widget.inviteService.exitInvite(
                              groupId: gid,
                              userId: widget.currentUserId,
                            );
                            await widget.groupService.declinePendingMembership(
                              gid,
                              widget.currentUserId,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                if (widget.isExpanded)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      height: 280,
                      child: Container(
                        margin: const EdgeInsets.only(top: 14),
                        child: _showInfo
                            ? _buildInfoView()
                            : _buildExpandedMessages(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactInviteAction({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoView() {
    final isGroup = widget.item['type'] == 'group';

    if (isGroup) {
      final members = widget.item['groupMembers'] as List<dynamic>? ?? [];
      final admins = widget.item['groupAdmins'] as List<dynamic>? ?? [];
      final pendingInviteIds = (widget.item['pendingInviteIds'] as List?)
              ?.map((entry) => entry.toString())
              .toList() ??
          const <String>[];
      final desc = widget.item['groupDescription'] as String? ?? '';
      final isAdmin = admins.contains(widget.currentUserId);
      final hasPendingApproval = pendingInviteIds.contains(
        widget.currentUserId,
      );
      final groupId = widget.item['id'] as String;

      return StreamBuilder<List<UserModel>>(
        stream: widget.userService.getAllUsers(widget.currentUserId),
        builder: (context, snapshot) {
          final allUsers = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Text(
                'GROUP INFO',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Group Actions ──
              if (isAdmin)
                _actionButton(
                  icon: Icons.person_add_outlined,
                  label: 'Add Members',
                  onTap: () => _showAddMembersDialog(
                    groupId,
                    members.cast<String>(),
                    (widget.item['pendingMemberIds'] as List?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        const <String>[],
                    allUsers,
                  ),
                ),
              if (!isAdmin && hasPendingApproval) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: AppTheme.purple.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You were invited to this group. Approve to stay or exit now.',
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await widget.groupService
                                    .approvePendingMembership(
                                  groupId,
                                  widget.currentUserId,
                                );
                                await widget.inviteService.approveInvite(
                                  groupId: groupId,
                                  userId: widget.currentUserId,
                                );
                                await widget.groupService.sendGroupMessage(
                                  groupId: groupId,
                                  senderId: 'system',
                                  senderName: 'System',
                                  text:
                                      '${cachedUserName.isEmpty ? 'User' : cachedUserName} joined the group',
                                  type: MessageType.system,
                                  skipUnreadIncrementFor: widget.currentUserId,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Text(
                                  'Approve',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await widget.inviteService.exitInvite(
                                  groupId: groupId,
                                  userId: widget.currentUserId,
                                );
                                await widget.groupService
                                    .declinePendingMembership(
                                  groupId,
                                  widget.currentUserId,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.zero,
                                ),
                                child: Text(
                                  'Exit',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              _actionButton(
                icon: Icons.exit_to_app,
                label: 'Leave Group',
                color: AppTheme.red,
                onTap: () => _confirmLeaveGroup(groupId),
              ),
              const SizedBox(height: 16),

              Text(
                'MEMBERS (${members.length})',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              ...members.map((mId) {
                final u = allUsers.cast<UserModel?>().firstWhere(
                      (u) => u?.uid == mId,
                      orElse: () => null,
                    );
                final isMemberAdmin = admins.contains(mId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: u?.isOnline == true
                              ? AppTheme.green
                              : Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '@${u?.displayName.replaceAll(' ', '').toLowerCase() ?? 'unknown'}',
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isMemberAdmin)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.purpleGlow,
                            borderRadius: BorderRadius.zero,
                            border: Border.all(
                              color: AppTheme.purple.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'ADMIN',
                            style: GoogleFonts.inter(
                              color: AppTheme.purpleLt,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      // Remove button for admins
                      if (isAdmin &&
                          mId != widget.currentUserId &&
                          !isMemberAdmin)
                        GestureDetector(
                          onTap: () async {
                            await widget.groupService.removeMember(
                              groupId,
                              mId as String,
                              removedByName: 'Admin',
                              skipUnreadIncrementForActor: widget.currentUserId,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: AppTheme.red.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      );
    } else {
      // ── DM Info with Seen Status ──
      final otherUserId = widget.item['otherUserId'];
      final chatId = widget.item['id'] as String;
      return StreamBuilder<UserModel?>(
        stream: widget.userService.getUserStream(otherUserId),
        builder: (context, userSnapshot) {
          final u = userSnapshot.data;
          if (u == null) return Container();
          return StreamBuilder<ChatModel?>(
            stream: widget.chatService.getChatStream(chatId),
            builder: (context, chatSnapshot) {
              final chat = chatSnapshot.data;
              final mySeenEnabled =
                  chat?.seenEnabled[widget.currentUserId] ?? true;
              final otherSeenEnabled = chat?.seenEnabled[otherUserId] ?? true;
              final myNotifyOnSeen =
                  chat?.notifyOnSeen[widget.currentUserId] ?? false;

              // Check for pending seen requests
              final hasPendingRequestFromMe = chat?.seenRequests.any(
                    (r) =>
                        r['from'] == widget.currentUserId &&
                        r['to'] == otherUserId,
                  ) ??
                  false;
              final hasPendingRequestToMe = chat?.seenRequests.any(
                    (r) =>
                        r['from'] == otherUserId &&
                        r['to'] == widget.currentUserId,
                  ) ??
                  false;

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    'USER INFO',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'STATUS',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.status,
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EMAIL',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.email,
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(
                    height: 1,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),

                  // ── Seen Status Section ──
                  Text(
                    'SEEN STATUS',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // My seen toggle
                  _seenToggleRow(
                    label: 'Show my read receipts',
                    subtitle: 'Let ${u.displayName} see when you read',
                    value: mySeenEnabled,
                    onChanged: (val) {
                      widget.chatService.toggleSeenEnabled(
                        chatId,
                        widget.currentUserId,
                        val,
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Other user seen status
                  if (otherSeenEnabled)
                    _infoRow(
                      icon: Icons.done_all,
                      text: '${u.displayName}\'s receipts: ON',
                      color: AppTheme.green,
                    )
                  else ...[
                    _infoRow(
                      icon: Icons.visibility_off_outlined,
                      text: '${u.displayName}\'s receipts: OFF',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    if (!hasPendingRequestFromMe)
                      _actionButton(
                        icon: Icons.visibility_outlined,
                        label: 'Request Seen Access',
                        onTap: () {
                          widget.chatService.requestSeenAccess(
                            chatId: chatId,
                            requesterId: widget.currentUserId,
                            targetId: otherUserId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Seen request sent to ${u.displayName}',
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                            ),
                          );
                        },
                      )
                    else
                      _infoRow(
                        icon: Icons.hourglass_top,
                        text: 'Request pending...',
                        color: AppTheme.purple,
                      ),
                  ],

                  // Incoming seen request
                  if (hasPendingRequestToMe) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color: AppTheme.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${u.displayName} wants to see your read receipts',
                            style: GoogleFonts.inter(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    widget.chatService.approveSeenRequest(
                                      chatId: chatId,
                                      approverId: widget.currentUserId,
                                      requesterId: otherUserId,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.green.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: Text(
                                      'Approve',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: AppTheme.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    widget.chatService.denySeenRequest(
                                      chatId: chatId,
                                      requesterId: otherUserId,
                                      targetId: widget.currentUserId,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.red.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    child: Text(
                                      'Deny',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        color: AppTheme.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Notify on seen
                  _seenToggleRow(
                    label: 'Notify when seen',
                    subtitle: 'Get notified when your message is read',
                    value: myNotifyOnSeen,
                    onChanged: (val) {
                      widget.chatService.toggleNotifyOnSeen(
                        chatId,
                        widget.currentUserId,
                        val,
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Widget _buildExpandedMessages() {
    final isGroup = widget.item['type'] == 'group';
    final stream = isGroup
        ? widget.groupService.getGroupMessages(widget.item['id'])
        : widget.chatService.getChatMessages(widget.item['id']);

    return StreamBuilder<List<MessageModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppTheme.purple,
              strokeWidth: 2,
            ),
          );
        }
        final messages = snapshot.data!;
        if (messages.isEmpty) return Container();

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg.senderId == widget.currentUserId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Dismissible(
                key: Key(msg.messageId),
                direction: DismissDirection.horizontal,
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart && isMe) {
                    // Swipe left to delete
                    final bool? conf = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        title: Text(
                          'Delete message?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        content: Text(
                          'This message will be deleted for everyone.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: AppTheme.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (conf == true) {
                      if (isGroup) {
                        widget.groupService.deleteMessage(
                          msg.messageId,
                          groupId: widget.item['id'] as String,
                        );
                      } else {
                        widget.chatService.deleteMessage(
                          msg.messageId,
                          chatId: widget.item['id'] as String,
                        );
                      }
                    }
                    return false; // Always bounce back
                  } else if (direction == DismissDirection.endToStart) {
                    return false; // Cannot delete when not sent by me
                  } else if (direction == DismissDirection.startToEnd) {
                    // Swipe right to reply
                    widget.onReply({
                      'targetHandle': widget.item['handle'] as String,
                      'message': msg,
                    });
                    return false;
                  }
                  return false;
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: const Icon(Icons.reply, color: AppTheme.purple),
                ),
                secondaryBackground: isMe
                    ? Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: const Icon(Icons.delete, color: AppTheme.red),
                      )
                    : Container(),
                child: Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surface,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(
                                      Icons.reply,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    title: Text(
                                      'Reply',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      widget.onReply({
                                        'targetHandle':
                                            widget.item['handle'] as String,
                                        'message': msg,
                                      });
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.forward,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    title: Text(
                                      'Forward',
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      widget.onForward(msg);
                                    },
                                  ),
                                  if (isMe)
                                    ListTile(
                                      leading: const Icon(
                                        Icons.delete,
                                        color: AppTheme.red,
                                      ),
                                      title: Text(
                                        'Delete',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.red,
                                        ),
                                      ),
                                      onTap: () async {
                                        Navigator.pop(context);
                                        if (isGroup) {
                                          await widget.groupService
                                              .deleteMessage(
                                            msg.messageId,
                                            groupId:
                                                widget.item['id'] as String,
                                          );
                                        } else {
                                          await widget.chatService
                                              .deleteMessage(
                                            msg.messageId,
                                            chatId: widget.item['id'] as String,
                                          );
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 2),
                              bottomRight: Radius.circular(isMe ? 2 : 12),
                            ),
                            border: Border.all(
                              color: isMe
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.2)
                                  : Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show sender name in a box for group chats only
                              if (isGroup && !isMe)
                                GestureDetector(
                                  onTap: () => widget.onHandleTap(
                                    '@${msg.senderName.replaceAll(' ', '').toLowerCase()}',
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.purple.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.zero,
                                      border: Border.all(
                                        color: AppTheme.purple.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      msg.senderName,
                                      style: GoogleFonts.inter(
                                        color: AppTheme.purpleLt,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              // ── Message content based on type ──
                              _buildMessageContent(msg, isMe),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Message content renderer ──
  Widget _buildMessageContent(MessageModel msg, bool isMe) {
    final iconColor = isMe
        ? AppTheme.purpleLt
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final textStyle = GoogleFonts.inter(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: 13,
      height: 1.4,
    );

    switch (msg.type) {
      case MessageType.image:
        return GestureDetector(
          onTap: () => _showImagePreview(msg.text),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: CachedNetworkImage(
                  imageUrl: msg.text,
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (200 * MediaQuery.devicePixelRatioOf(context)).toInt(),
                  memCacheHeight:
                      (150 * MediaQuery.devicePixelRatioOf(context)).toInt(),
                  cacheManager: MediaCacheManager.instance,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 150,
                    color: Theme.of(context).colorScheme.surface,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.purple,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 200,
                    height: 150,
                    color: Theme.of(context).colorScheme.surface,
                    child: Icon(Icons.broken_image, color: iconColor, size: 32),
                  ),
                ),
              ),
            ],
          ),
        );

      case MessageType.file:
        return GestureDetector(
          onTap: () =>
              _openAttachmentLocally(msg.text, msg.fileName ?? 'file.bin'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.zero,
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppTheme.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.fileName ?? 'File',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (msg.fileSize != null)
                      Text(
                        _formatFileSize(msg.fileSize!),
                        style: GoogleFonts.inter(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.download_outlined, color: iconColor, size: 16),
            ],
          ),
        );

      case MessageType.audio:
        return VoiceMessagePlayer(audioUrl: msg.text, isMe: isMe);

      case MessageType.location:
        return GestureDetector(
          onTap: () async {
            final lat = msg.latitude;
            final lng = msg.longitude;
            if (lat != null && lng != null) {
              final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng');
              final opened = await launchUrl(
                geoUri,
                mode: LaunchMode.externalApplication,
              );
              if (!opened) {
                await launchUrl(
                  Uri.parse('https://www.google.com/maps?q=$lat,$lng'),
                  mode: LaunchMode.externalApplication,
                );
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: AppTheme.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 Location',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tap to open in Maps',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.open_in_new, color: iconColor, size: 14),
            ],
          ),
        );

      case MessageType.system:
        return Text(
          msg.text,
          style: GoogleFonts.inter(
            color: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        );

      case MessageType.text:
        if (msg.text.startsWith('> Reply:')) {
          final parts = msg.text.split('\n');
          final replyLine = parts.first;
          final rest = parts.length > 1 ? parts.sublist(1).join('\n') : '';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppTheme.purple, width: 3),
                  ),
                ),
                child: Text(
                  replyLine.replaceAll('> Reply:', 'Reply').trim(),
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              if (rest.isNotEmpty)
                MarkdownBody(
                  data: rest,
                  styleSheet: MarkdownStyleSheet(
                    p: textStyle,
                    listBullet: textStyle,
                    strong: textStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          );
        }
        return MarkdownBody(
          data: msg.text,
          styleSheet: MarkdownStyleSheet(
            p: textStyle,
            listBullet: textStyle,
            strong: textStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _showImagePreview(String imageUrl) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 180,
                    child: Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.white70,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _extractAppwriteFileId(String fileUrl) {
    final match = RegExp(r'/files/([^/]+)/').firstMatch(fileUrl);
    return match?.group(1);
  }

  Future<void> _openAttachmentLocally(
    String fileUrl,
    String preferredName,
  ) async {
    if (kIsWeb) {
      await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.platformDefault);
      return;
    }

    try {
      final fileId = _extractAppwriteFileId(fileUrl);
      if (fileId == null) {
        await launchUrl(
          Uri.parse(fileUrl),
          mode: LaunchMode.externalApplication,
        );
        return;
      }

      final bytes = await appwriteStorage.getFileDownload(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: fileId,
      );
      final tempDir = await getTemporaryDirectory();
      final cleanName = preferredName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final localPath = '${tempDir.path}/$cleanName';
      final outFile = File(localPath);
      await outFile.writeAsBytes(bytes, flush: true);

      await OpenFilex.open(localPath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not open file locally.',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    }
  }

  // ── Helper Widgets ──

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: c.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: c),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: GoogleFonts.inter(color: c, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _seenToggleRow({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Transform.scale(
          scale: 0.7,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.purple,
            activeTrackColor: AppTheme.purple.withValues(alpha: 0.3),
            inactiveThumbColor: Theme.of(context).colorScheme.secondary,
            inactiveTrackColor: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  void _showAddMembersDialog(
    String groupId,
    List<String> currentMembers,
    List<String> pendingMemberIds,
    List<UserModel> allUsers,
  ) {
    final availableUsers = allUsers
        .where(
          (u) =>
              !u.isExcludedFromGroups &&
              !currentMembers.contains(u.uid) &&
              !pendingMemberIds.contains(u.uid),
        )
        .toList();
    final selected = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(
                'Add Members',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 300,
                height: 300,
                child: availableUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No users to add',
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: availableUsers.length,
                        itemBuilder: (_, i) {
                          final user = availableUsers[i];
                          final isSelected = selected.contains(user.uid);
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppTheme.purple
                                  : Theme.of(context).colorScheme.secondary,
                              size: 20,
                            ),
                            title: Row(
                              children: [
                                PixelSymbol(
                                  isGroup: false,
                                  color: Colors.blueAccent,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    user.displayName,
                                    style: GoogleFonts.inter(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              user.email,
                              style: GoogleFonts.inter(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                            onTap: () {
                              setDialogState(() {
                                if (isSelected) {
                                  selected.remove(user.uid);
                                } else {
                                  selected.add(user.uid);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await widget.groupService.addMembers(
                            groupId,
                            selected.toList(),
                            cachedUserName.isNotEmpty
                                ? cachedUserName
                                : 'Admin',
                            actorUserId: widget.currentUserId,
                          );
                        },
                  child: Text(
                    'Add (${selected.length})',
                    style: GoogleFonts.inter(
                      color: selected.isEmpty
                          ? Theme.of(context).colorScheme.secondary
                          : AppTheme.purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmLeaveGroup(String groupId) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            'Leave group?',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You will no longer receive messages from this group.',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await widget.groupService.leaveGroup(
                  groupId,
                  widget.currentUserId,
                  cachedUserName.isNotEmpty ? cachedUserName : 'User',
                );
              },
              child: Text(
                'Leave',
                style: GoogleFonts.inter(
                  color: AppTheme.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PresenceRingPainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color trackColor;

  const _PresenceRingPainter({
    required this.percentage,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 2.5;
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
  bool shouldRepaint(covariant _PresenceRingPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

class NetworkBottomSheet extends StatefulWidget {
  final List<UserModel> users;
  final UserModel? currentUserModel;
  final Function(UserModel) onUserTap;
  final Function(String, bool) onToggleFavorite;

  const NetworkBottomSheet({
    super.key,
    required this.users,
    this.currentUserModel,
    required this.onUserTap,
    required this.onToggleFavorite,
  });

  @override
  State<NetworkBottomSheet> createState() => _NetworkBottomSheetState();
}

class _NetworkBottomSheetState extends State<NetworkBottomSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredUsers = widget.users.where((u) {
      return u.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final favorites = widget.currentUserModel?.favorites ?? [];
    final favoriteUsers =
        filteredUsers.where((u) => favorites.contains(u.uid)).toList();
    final otherUsers =
        filteredUsers.where((u) => !favorites.contains(u.uid)).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag indicator handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.purple,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Icon(
                      Icons.people_alt_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'NETWORK',
                    style: GoogleFonts.inter(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search Box
              TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),

              const SizedBox(height: 20),
              Expanded(
                child: filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No matches found',
                          style: GoogleFonts.inter(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView(
                        children: [
                          if (favoriteUsers.isNotEmpty) ...[
                            _sectionLabel('FAVORITES'),
                            const SizedBox(height: 8),
                            ...favoriteUsers.map(
                              (u) => _buildUserItem(u, true),
                            ),
                            const SizedBox(height: 16),
                            _sectionLabel('ALL PEOPLE'),
                            const SizedBox(height: 8),
                          ],
                          ...otherUsers.map((u) => _buildUserItem(u, false)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      );

  Widget _buildUserItem(UserModel user, bool isFavorite) {
    final handle = '@${user.displayName.replaceAll(' ', '').toLowerCase()}';

    return InkWell(
      onTap: () => widget.onUserTap(user),
      borderRadius: BorderRadius.zero,
      splashColor: AppTheme.purpleGlow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Avatar initial circle
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.purpleDim, Color(0xFF1A1A2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.inter(
                        color: AppTheme.purpleLt,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          handle,
                          style: GoogleFonts.inter(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (user.isOnline) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppTheme.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFavorite
                    ? AppTheme.yellow
                    : Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
              onPressed: () {
                widget.onToggleFavorite(user.uid, isFavorite);
                // Optimistic UI update so the change appears immediately
                setState(() {
                  if (isFavorite) {
                    widget.currentUserModel?.favorites.remove(user.uid);
                  } else {
                    widget.currentUserModel?.favorites.add(user.uid);
                  }
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
