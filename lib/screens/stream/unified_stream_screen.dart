import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
import '../../services/user_service.dart';
import '../../services/bot_service.dart';
import '../../models/group_model.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../models/message_model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/voice_message_player.dart';

class UnifiedStreamScreen extends StatefulWidget {
  final String currentUserId;
  const UnifiedStreamScreen({super.key, required this.currentUserId});

  @override
  State<UnifiedStreamScreen> createState() => _UnifiedStreamScreenState();
}

class _UnifiedStreamScreenState extends State<UnifiedStreamScreen> {
  final TextEditingController _commandController = TextEditingController();
  final FocusNode _commandFocusNode = FocusNode();

  final _chatService = ChatService();
  final _groupService = GroupService();
  final _userService = UserService();
  final _botService = BotService();
  late final String currentUserId = widget.currentUserId;

  List<UserModel> _allUsers = [];
  List<GroupModel> _allGroups = [];
  UserModel? _currentUserModel;
  bool _isUploading = false;

  String? _expandedItemId;

  bool _isMentioning = false;
  List<dynamic> _mentionSuggestions = [];

  // AI state
  bool _isAiMode = false;
  bool _isAiLoading = false;
  final AiService _aiService = AiService();

  bool _showActions = false;
  bool _showEmojiPopup = false;
  final ValueNotifier<bool> _isRecordingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _recordingSecondsNotifier = ValueNotifier<int>(0);
  double _recordingDragOffset = 0;
  static const int _recordingMaxSeconds =
      60; // Reduced to 60s for budget control
  bool _recordingCancelled = false;
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Reply state
  MessageModel? _replyingToMessage;

  late final Stream<List<UserModel>> _allUsersStream;
  late final Stream<List<ChatModel>> _chatsStream;
  late final Stream<List<GroupModel>> _groupsStream;
  late final Stream<List<Map<String, dynamic>>> _combinedStream;

  @override
  void initState() {
    super.initState();

    _allUsersStream = _userService.getAllUsers(currentUserId);
    _chatsStream = _chatService.getUserChats(currentUserId);
    _groupsStream = _groupService.getUserGroups(currentUserId);

    _combinedStream = Rx.combineLatest3(
      _chatsStream,
      _groupsStream,
      _allUsersStream,
      (chats, groups, users) {
        List<Map<String, dynamic>> merged = [];

        for (var chat in chats) {
          if (chat.lastMessage.isEmpty) continue;
          final otherUserId = chat.getOtherUserId(currentUserId);
          final otherUser = users.cast<UserModel?>().firstWhere(
            (u) => u?.uid == otherUserId,
            orElse: () => null,
          );

          final isOnline = otherUser?.isOnline ?? false;
          final photoUrl = otherUser?.photoUrl;

          merged.add({
            'type': 'dm',
            'id': chat.chatId,
            'otherUserId': otherUserId,
            'timeRaw': chat.lastMessageTime ?? DateTime.now(),
            'handle': otherUser != null
                ? _formatHandle(otherUser.displayName)
                : '@unknown',
            'sender': chat.lastMessageSenderId == currentUserId
                ? 'me'
                : (otherUser?.displayName ?? ''),
            'content': chat.lastMessage,
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
          if (group.lastMessage.isEmpty) continue;

          int onlineCount = 0;
          for (var uid in group.members) {
            if (uid == currentUserId) {
              if (_currentUserModel?.isOnline == true) onlineCount++;
            } else {
              final member = users.cast<UserModel?>().firstWhere(
                (u) => u?.uid == uid,
                orElse: () => null,
              );
              if (member != null && member.isOnline) onlineCount++;
            }
          }
          final double percentage = group.members.isEmpty
              ? 0.0
              : onlineCount / group.members.length;

          merged.add({
            'type': 'group',
            'id': group.groupId,
            'timeRaw': group.lastMessageTime ?? DateTime.now(),
            'handle': _formatGroupHandle(group.name),
            'sender': group.lastMessageSenderId == currentUserId
                ? 'me'
                : group.lastMessageSenderName,
            'content': group.lastMessage,
            'time': group.lastMessageTime != null
                ? DateFormat('HH:mm').format(group.lastMessageTime!)
                : '',
            'isUnread': false,
            'image': group.lastMessage.contains('📷'),
            'photoUrl': group.photoUrl,
            'isOnline': onlineCount > 0,
            'onlinePercentage': percentage,
            'groupMembers': group.members,
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
    );

    _allUsersStream.listen((users) {
      if (mounted) {
        setState(() {
          _allUsers = users;
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
          _allGroups = groups;
        });
      }
    });

    _commandController.addListener(_onCommandChanged);
  }

  void _onCommandChanged() {
    final text = _commandController.text;
    final selection = _commandController.selection;
    if (selection.baseOffset == -1) return;

    final textBeforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = textBeforeCursor.lastIndexOf('@');
    final lastHash = textBeforeCursor.lastIndexOf('#');
    final lastSpace = textBeforeCursor.lastIndexOf(' ');
    final lastToken = textBeforeCursor.split(' ').last.toLowerCase();

    // Detect /ai mode — check if text contains /
    final slashIndex = text.indexOf('/');
    if (slashIndex >= 0) {
      // Check if there's at least one target before the /
      final beforeSlash = text.substring(0, slashIndex).trim();
      final hasTarget =
          beforeSlash.startsWith('@') || beforeSlash.startsWith('#');
      setState(() {
        _isAiMode = hasTarget;
      });
    } else {
      setState(() {
        _isAiMode = false;
      });
    }

    if (lastAt > lastSpace && lastAt >= 0) {
      final query = textBeforeCursor.substring(lastAt + 1).toLowerCase();
      setState(() {
        _isMentioning = true;
        _mentionSuggestions = _allUsers
            .where(
              (u) => u.displayName
                  .toLowerCase()
                  .replaceAll(' ', '')
                  .contains(query),
            )
            .toList();
      });
    } else if (lastHash > lastSpace && lastHash >= 0) {
      final query = textBeforeCursor.substring(lastHash + 1).toLowerCase();
      setState(() {
        _isMentioning = true;
        _mentionSuggestions = _allGroups
            .where(
              (g) => g.name.toLowerCase().replaceAll(' ', '').contains(query),
            )
            .toList();
      });
    } else if ('location'.startsWith(lastToken) && lastToken.length >= 2) {
      setState(() {
        _isMentioning = true;
        _mentionSuggestions = ['Share current location'];
      });
    } else {
      setState(() {
        _isMentioning = false;
        _mentionSuggestions = [];
      });
    }
  }

  @override
  void dispose() {
    _commandController.removeListener(_onCommandChanged);
    _commandController.dispose();
    _commandFocusNode.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _formatHandle(String name) {
    return '@${name.replaceAll(' ', '').toLowerCase()}';
  }

  String _formatGroupHandle(String name) {
    return '#${name.replaceAll(' ', '').toLowerCase()}';
  }

  void _handleItemTap(String handle) {
    _commandController.text = '$handle ';
    _commandController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commandController.text.length),
    );
    _commandFocusNode.requestFocus();
  }

  void _pickAndSendImage() async {
    final text = _commandController.text.trim();
    if (text.isEmpty || (!text.startsWith('@') && !text.startsWith('#'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before attaching image',
              style: GoogleFonts.jetBrainsMono(),
            ),
            backgroundColor: const Color(0xFF161618),
          ),
        );
      }
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (pickedFile == null) return;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF161618),
          toolbarWidgetColor: Colors.white,
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
      final imageBytes = await XFile(croppedFile.path).readAsBytes();
      final file = await appwriteStorage.createFile(
        bucketId: AppwriteConstants.chatFilesBucket,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: imageBytes, filename: '$fileName.jpg'),
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
          backgroundColor: const Color(0xFF161618),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Pick & send file ──
  void _pickAndSendFile() async {
    final text = _commandController.text.trim();
    if (text.isEmpty || (!text.startsWith('@') && !text.startsWith('#'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before attaching file',
              style: GoogleFonts.jetBrainsMono(),
            ),
            backgroundColor: const Color(0xFF161618),
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
          backgroundColor: const Color(0xFF161618),
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
          style: GoogleFonts.inter(color: AppTheme.textPri),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: GoogleFonts.inter(color: AppTheme.textPri),
          decoration: InputDecoration(
            hintText: 'Write a note for this photo...',
            hintStyle: GoogleFonts.inter(color: AppTheme.muted),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.border),
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
              style: GoogleFonts.inter(color: AppTheme.muted),
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
    final text = _commandController.text.trim();
    if (text.isEmpty || (!text.startsWith('@') && !text.startsWith('#'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before recording',
              style: GoogleFonts.jetBrainsMono(),
            ),
            backgroundColor: const Color(0xFF161618),
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
          backgroundColor: const Color(0xFF161618),
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
          backgroundColor: const Color(0xFF161618),
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
            backgroundColor: const Color(0xFF161618),
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
        _commandController.text.trim(),
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
          backgroundColor: const Color(0xFF161618),
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
          backgroundColor: const Color(0xFF161618),
        ),
      );
    }
  }

  // ── Send location ──
  void _sendLocation() async {
    final text = _commandController.text.trim();
    if (text.isEmpty || (!text.startsWith('@') && !text.startsWith('#'))) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a target (@user or #group) before sharing location',
              style: GoogleFonts.jetBrainsMono(),
            ),
            backgroundColor: const Color(0xFF161618),
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
          backgroundColor: const Color(0xFF161618),
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
  }) async {
    final words = text.split(' ');
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
      content =
          (metadata['url'] as String?) ??
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
      content = msg;
    }

    if (type == MessageType.text && _replyingToMessage != null) {
      content = '> Reply: ${_replyPreview(_replyingToMessage!)}\n$content';
    }

    if (content.isEmpty && type == MessageType.text) return;

    final currentUserName = cachedUserName;
    final currentUserPhoto = cachedUserPhotoUrl;
    bool sentAtLeastOne = false;

    for (var handle in handles) {
      if (handle.startsWith('@')) {
        final tHandle = handle.substring(1);
        final targetUser = _allUsers.cast<UserModel?>().firstWhere(
          (u) => u!.displayName.replaceAll(' ', '').toLowerCase() == tHandle,
          orElse: () => null,
        );

        if (targetUser != null) {
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
            final botConfig = await _botService.getBotByName(
              targetUser.displayName,
            );
            if (botConfig != null) {
              String botPrompt = content;
              String systemPrompt = botConfig.instructions;

              // Check if owner wants a summary
              if (currentUserId == botConfig.ownerId &&
                  content.toLowerCase().contains('summarize')) {
                // Fetch interactions with this bot from all users?
                // For now, let's just fetch recent messages in this specific chat.
                final history = await _chatService.getUnreadMessages(
                  chatId,
                  currentUserId,
                );
                if (history.isNotEmpty) {
                  botPrompt =
                      'Context of recent messages:\n${history.reversed.map((m) => '${m.senderName}: ${m.text}').join('\n')}\n\nPrompt: $content';
                }
              }

              // Run AI in background
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
        final tHandle = handle.substring(1);
        final groups = await _groupService.getUserGroups(currentUserId).first;
        final targetGroup = groups.cast<GroupModel?>().firstWhere(
          (g) => g!.name.replaceAll(' ', '').toLowerCase() == tHandle,
          orElse: () => null,
        );

        if (targetGroup != null) {
          await _groupService.sendGroupMessage(
            groupId: targetGroup.groupId,
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
          backgroundColor: const Color(0xFF161618),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    if (input.trim().isEmpty) return;

    // Check for @bot creation command
    if (input.toLowerCase().startsWith('@bot ')) {
      final botName = input.substring(5).trim();
      if (botName.isNotEmpty) {
        _showBotConfigDialog(botName);
        _commandController.clear();
        return;
      }
    }

    // Check for AI mode: if text contains /, extract the AI prompt
    final slashIndex = input.indexOf('/');
    if (slashIndex >= 0) {
      final beforeSlash = input.substring(0, slashIndex).trim();
      final aiPrompt = input.substring(slashIndex + 1).trim();

      // Ensure there are @user or #group targets before the /
      final hasTarget =
          beforeSlash.startsWith('@') || beforeSlash.startsWith('#');

      if (hasTarget && aiPrompt.isNotEmpty) {
        setState(() => _isAiLoading = true);
        _commandController.clear();

        try {
          String finalPrompt = aiPrompt;
          final aiPromptLower = aiPrompt.toLowerCase();

          if (aiPromptLower.contains('summarize') &&
              (aiPromptLower.contains('unread') ||
                  aiPromptLower.contains('conversation'))) {
            final words = beforeSlash.split(' ');
            final handles = words
                .where((w) => w.startsWith('@') || w.startsWith('#'))
                .toList();

            String contextText = '';
            final onlyUnread = aiPromptLower.contains('unread');

            for (var handle in handles) {
              if (handle.startsWith('@')) {
                final tHandle = handle.substring(1).toLowerCase();
                final targetUser = _allUsers.cast<UserModel?>().firstWhere(
                  (u) =>
                      u!.displayName.replaceAll(' ', '').toLowerCase() ==
                      tHandle,
                  orElse: () => null,
                );
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
                final tHandle = handle.substring(1).toLowerCase();
                final targetGroup = _allGroups.cast<GroupModel?>().firstWhere(
                  (g) => g!.name.replaceAll(' ', '').toLowerCase() == tHandle,
                  orElse: () => null,
                );
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
                  'Context:\n$contextText\n\nPrompt: $aiPrompt\nRespond professionally without any weird markers or asterisks before the text. Format cleanly.';
            } else {
              finalPrompt = '$aiPrompt (Note: No messages found to summarize)';
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
                content: Text('AI error: $e', style: GoogleFonts.inter()),
                backgroundColor: const Color(0xFF161618),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isAiLoading = false);
        }
        return;
      }
    }

    await _processCommand(input.trim());
    _commandController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildStatusBar(),
                Expanded(child: _buildCombinedStream()),
                _buildCommandBar(),
              ],
            ),
          ),
          if (_isUploading)
            Container(
              color: AppTheme.bg.withValues(alpha: 0.7),
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

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // App icon + name (uses actual assets/icon.png)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
                  color: AppTheme.textPri,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppTheme.muted,
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
    );
  }

  Widget _buildCombinedStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _combinedStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Stream error: ${snapshot.error}');
          return Center(
            child: SelectableText(
              'ERROR: ${snapshot.error}',
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
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
                  color: AppTheme.border,
                ),
                const SizedBox(height: 16),
                Text(
                  'No conversations yet',
                  style: GoogleFonts.inter(
                    color: AppTheme.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Type @name or #group to start',
                  style: GoogleFonts.inter(color: AppTheme.muted, fontSize: 13),
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
              currentUserId: currentUserId,
              chatService: _chatService,
              groupService: _groupService,
              userService: _userService,
              onTap: () {
                setState(() {
                  _expandedItemId = isExpanded ? null : item['id'];
                });
                if (!isExpanded && item['type'] == 'dm') {
                  _chatService.markMessagesAsRead(item['id'], currentUserId);
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
                _commandController.text = ' Forwarded: ${msg.text} ';
                _commandController.selection = TextSelection.fromPosition(
                  TextPosition(offset: 0),
                );
                _commandFocusNode.requestFocus();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Type @user or #group to forward this message',
                    ),
                  ),
                );
              },
              onLongPress: () => _handleItemTap(item['handle'] ?? ''),
            );
          },
        );
      },
    );
  }

  Widget _buildEmojiPopup() {
    final emojis = ['👍', '❤️', '😂', '🔥', '🎉', '🚀'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E20),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...emojis.map(
            (emoji) => InkWell(
              onTap: () {
                final text = _commandController.text;
                final selection = _commandController.selection;
                final start = selection.start >= 0
                    ? selection.start
                    : text.length;
                final end = selection.end >= 0 ? selection.end : text.length;
                final newText =
                    text.substring(0, start) + emoji + text.substring(end);
                _commandController.text = newText;
                _commandController.selection = TextSelection.collapsed(
                  offset: start + emoji.length,
                );
                _commandFocusNode.requestFocus();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyingToMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppTheme.purple,
                    borderRadius: BorderRadius.circular(4),
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
                          color: AppTheme.textSec,
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
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.muted,
                    size: 18,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

        if (_isMentioning && _mentionSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _mentionSuggestions.length,
              itemBuilder: (context, index) {
                final suggestion = _mentionSuggestions[index];
                final isUser = suggestion is UserModel;
                final isGroup = suggestion is GroupModel;
                final isAction = suggestion is String;
                final name = isUser
                    ? suggestion.displayName
                    : isGroup
                    ? suggestion.name
                    : suggestion.toString();
                final handle = isUser
                    ? _formatHandle(name)
                    : isGroup
                    ? _formatGroupHandle(name)
                    : name;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isUser
                        ? Icons.person_outline_rounded
                        : isGroup
                        ? Icons.tag_rounded
                        : Icons.location_on_outlined,
                    color: isUser
                        ? AppTheme.purple
                        : isGroup
                        ? AppTheme.green
                        : AppTheme.accent,
                    size: 20, // larger
                  ),
                  title: Text(
                    handle,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPri,
                      fontSize: 14, // larger
                    ),
                  ),
                  onTap: () {
                    if (isAction) {
                      setState(() {
                        _isMentioning = false;
                        _mentionSuggestions = [];
                      });
                      _sendLocation();
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
                    final lastHash = textBeforeCursor.lastIndexOf('#');
                    final lastPrefixIndex = isUser ? lastAt : lastHash;

                    final newText =
                        '${textBeforeCursor.substring(0, lastPrefixIndex)}$handle $textAfterCursor';
                    _commandController.text = newText;
                    _commandController.selection = TextSelection.fromPosition(
                      TextPosition(offset: lastPrefixIndex + handle.length + 1),
                    );

                    setState(() {
                      _isMentioning = false;
                      _mentionSuggestions = [];
                    });
                    _commandFocusNode.requestFocus();
                  },
                );
              },
            ),
          ),

        if (_showEmojiPopup) _buildEmojiPopup(),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
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
                        _showEmojiPopup = false;
                      });
                    }
                  },
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isAiMode ? AppTheme.purple : Colors.white,
                        width: _isAiMode ? 2.0 : 1.5,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // The normal text input field (always in tree to maintain keyboard focus)
                        Row(
                          children: [
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextField(
                                controller: _commandController,
                                focusNode: _commandFocusNode,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPri,
                                  fontSize: 15,
                                ),
                                decoration: InputDecoration(
                                  hintText: _isAiMode
                                      ? '✨ Type your AI prompt...'
                                      : '@user or #group message... ( / for AI)',
                                  hintStyle: GoogleFonts.inter(
                                    color: _isAiMode
                                        ? AppTheme.purpleLt
                                        : AppTheme.muted,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  fillColor: Colors.transparent,
                                ),
                                cursorColor: AppTheme.purple,
                                onSubmitted: _sendCommand,
                              ),
                            ),
                            if (_showActions) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: AppTheme.textSec,
                                  size: 24,
                                ),
                                onPressed: () {
                                  setState(
                                    () => _showEmojiPopup = !_showEmojiPopup,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppTheme.textSec,
                                  size: 24,
                                ),
                                onPressed: _pickAndSendImage,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.attach_file_outlined,
                                  color: AppTheme.textSec,
                                  size: 24,
                                ),
                                onPressed: _pickAndSendFile,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.location_on_outlined,
                                  color: AppTheme.textSec,
                                  size: 24,
                                ),
                                onPressed: _sendLocation,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.group_add_outlined,
                                  color: AppTheme.textSec,
                                  size: 24,
                                ),
                                onPressed: _showCreateGroupDialog,
                              ),
                            ],
                            if (!_showActions)
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _commandController,
                                builder: (context, value, child) {
                                  final hasText = value.text.trim().isNotEmpty;
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
                                              color: AppTheme.purple,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        )
                                      else if (hasText)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          child: IconButton(
                                            icon: Icon(
                                              _isAiMode
                                                  ? Icons.auto_awesome_rounded
                                                  : Icons.arrow_forward_rounded,
                                              color: AppTheme.purple,
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
                              color: AppTheme.surface,
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
                                          color: AppTheme.textPri,
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
                                      child: const Center(
                                        child: Text(
                                          '< Slide to cancel',
                                          style: TextStyle(
                                            color: AppTheme.textSec,
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
                                            : AppTheme.textSec,
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
                      color: const Color(0xFFF5F5F5), // offwhite
                      borderRadius: BorderRadius.circular(
                        16,
                      ), // Soft corner square
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
          const SnackBar(content: Text('You are not the owner of this bot.')),
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
      backgroundColor: AppTheme.surface,
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
                    color: AppTheme.textPri,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '@$botName',
              style: GoogleFonts.outfit(color: AppTheme.purpleLt, fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: instructionsController,
              maxLines: 5,
              style: GoogleFonts.inter(color: AppTheme.textPri),
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
                    if (existingBot == null) {
                      await _botService.createBot(
                        name: botName,
                        ownerId: currentUserId,
                        instructions: instructions,
                      );
                    } else {
                      await _botService.updateBot(existingBot.botId, {
                        'instructions': instructions,
                      });
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bot @$botName configured!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

  void _showCreateGroupDialog() {
    String grpName = '';
    bool isCreating = false;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                ),
              ),
              title: Text(
                'CREATE GROUP',
                style: GoogleFonts.spaceMono(color: colorScheme.onSurface),
              ),
              content: TextField(
                autofocus: true,
                enabled: !isCreating,
                style: GoogleFonts.jetBrainsMono(color: colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Group Name',
                  hintStyle: GoogleFonts.jetBrainsMono(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                onChanged: (val) => grpName = val,
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(context),
                  child: Text(
                    '  CANCEL  ',
                    style: GoogleFonts.jetBrainsMono(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          final trimmedName = grpName.trim();
                          if (trimmedName.isEmpty) return;

                          // Check if group name is unique
                          final exists = _allGroups.any(
                            (g) =>
                                g.name.toLowerCase() ==
                                trimmedName.toLowerCase(),
                          );
                          if (exists) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Group name already exists!',
                                  style: GoogleFonts.jetBrainsMono(),
                                ),
                                backgroundColor: const Color(0xFF161618),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() => isCreating = true);

                          try {
                            await _groupService.createGroup(
                              name: trimmedName,
                              description: '',
                              createdBy: currentUserId,
                              members: [],
                            );
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          } catch (e) {
                            setState(() => isCreating = false);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to create group.',
                                  style: GoogleFonts.jetBrainsMono(),
                                ),
                                backgroundColor: colorScheme.error,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '  CREATE  ',
                          style: GoogleFonts.jetBrainsMono(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
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
  final String currentUserId;
  final ChatService chatService;
  final GroupService groupService;
  final UserService userService;
  final VoidCallback onTap;
  final void Function(Map<String, dynamic>) onReply;
  final void Function(MessageModel) onForward;
  final VoidCallback onLongPress;

  const StreamItemWidget({
    super.key,
    required this.item,
    required this.isExpanded,
    required this.currentUserId,
    required this.chatService,
    required this.groupService,
    required this.userService,
    required this.onTap,
    required this.onReply,
    required this.onForward,
    required this.onLongPress,
  });

  @override
  State<StreamItemWidget> createState() => _StreamItemWidgetState();
}

class _StreamItemWidgetState extends State<StreamItemWidget> {
  bool _showInfo = false;

  @override
  void didUpdateWidget(StreamItemWidget oldWidget) {
    if (!widget.isExpanded && oldWidget.isExpanded) {
      _showInfo = false;
    }
    super.didUpdateWidget(oldWidget);
  }

  Widget _buildAvatar(Map<String, dynamic> item, ColorScheme colorScheme) {
    final isGroup = item['type'] == 'group';
    final double percentage = item['onlinePercentage'] ?? 0.0;
    final String photoUrl = item['photoUrl'] ?? '';
    final String handleText = item['handle'] ?? '?';
    final String initials =
        handleText.replaceAll(RegExp(r'[@#]'), '').isNotEmpty
        ? handleText
              .replaceAll(RegExp(r'[@#]'), '')
              .substring(0, 1)
              .toUpperCase()
        : '?';

    Widget innerAvatar;
    if (photoUrl.isNotEmpty) {
      innerAvatar = ClipOval(
        child: Image.network(
          photoUrl,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildInitials(initials, colorScheme),
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
          // Online ring for DMs
          if (!isGroup && percentage > 0)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.green, width: 2),
              ),
            ),
          // Arc for groups
          if (isGroup && percentage > 0)
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 2,
                backgroundColor: AppTheme.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.green),
              ),
            ),
          innerAvatar,
        ],
      ),
    );
  }

  Widget _buildInitials(String initials, ColorScheme colorScheme) {
    final isGroup = widget.item['type'] == 'group';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isGroup ? const Color(0xFF1A2A1A) : AppTheme.purpleDim,
        shape: BoxShape.circle,
        border: Border.all(
          color: isGroup
              ? AppTheme.green.withValues(alpha: 0.3)
              : AppTheme.purple.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            color: isGroup ? AppTheme.green : AppTheme.purpleLt,
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
    final isGroup = handleText.startsWith('#');
    // Purple for DM (@), emerald-ish green for group (#)
    final handlePrefixColor = isGroup ? AppTheme.green : AppTheme.purple;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (widget.isExpanded) {
            if (details.primaryDelta! > 5) {
              setState(() => _showInfo = true);
            } else if (details.primaryDelta! < -5) {
              setState(() => _showInfo = false);
            }
          }
        },
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          splashColor: AppTheme.purpleGlow,
          highlightColor: AppTheme.purpleGlow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: isUnread ? AppTheme.purpleGlow : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isUnread
                    ? AppTheme.purple.withValues(alpha: 0.5)
                    : AppTheme.border,
                width: isUnread ? 1.5 : 1,
              ),
              boxShadow: isUnread
                  ? [
                      BoxShadow(
                        color: AppTheme.purple.withValues(alpha: 0.08),
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
                              // Handle: coloured prefix symbol + white name
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: handleText.isNotEmpty
                                          ? handleText.substring(0, 1)
                                          : '',
                                      style: GoogleFonts.inter(
                                        color: handlePrefixColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(
                                      text: handleText.length > 1
                                          ? handleText.substring(1)
                                          : '',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFF0F0F0),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                widget.item['time'] ?? '',
                                style: GoogleFonts.inter(
                                  color: AppTheme.muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          // Sender + content — show sender only in groups
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.inter(
                                color: const Color(0xFF9B9B9B),
                                fontSize: 13,
                                height: 1.4,
                              ),
                              children: [
                                // Only show sender name for group conversations
                                if (isGroup)
                                  TextSpan(
                                    text: '${widget.item['sender']}  ',
                                    style: const TextStyle(
                                      color: Color(0xFF6B6B6B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (isImage)
                                  const WidgetSpan(
                                    child: Icon(
                                      Icons.image_outlined,
                                      color: Color(0xFF9B9B9B),
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
                    // Unread dot
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

  Widget _buildInfoView() {
    final isGroup = widget.item['type'] == 'group';

    if (isGroup) {
      final members = widget.item['groupMembers'] as List<dynamic>? ?? [];
      final admins = widget.item['groupAdmins'] as List<dynamic>? ?? [];
      final desc = widget.item['groupDescription'] as String? ?? '';
      final isAdmin = admins.contains(widget.currentUserId);
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
                  color: AppTheme.textPri,
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
                    color: AppTheme.textSec,
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
                    allUsers,
                  ),
                ),
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
                  color: AppTheme.muted,
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
                              : AppTheme.muted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '@${u?.displayName.replaceAll(' ', '').toLowerCase() ?? 'unknown'}',
                          style: GoogleFonts.inter(
                            color: AppTheme.textPri,
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
                            borderRadius: BorderRadius.circular(4),
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
              final hasPendingRequestFromMe =
                  chat?.seenRequests.any(
                    (r) =>
                        r['from'] == widget.currentUserId &&
                        r['to'] == otherUserId,
                  ) ??
                  false;
              final hasPendingRequestToMe =
                  chat?.seenRequests.any(
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
                      color: AppTheme.textPri,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'STATUS',
                    style: GoogleFonts.inter(
                      color: AppTheme.muted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.status,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSec,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'EMAIL',
                    style: GoogleFonts.inter(
                      color: AppTheme.muted,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    u.email,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSec,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 16),

                  // ── Seen Status Section ──
                  Text(
                    'SEEN STATUS',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPri,
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
                      color: AppTheme.muted,
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
                              backgroundColor: AppTheme.surface2,
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
                        borderRadius: BorderRadius.circular(8),
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
                              color: AppTheme.textPri,
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
                                      borderRadius: BorderRadius.circular(6),
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
                                      borderRadius: BorderRadius.circular(6),
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
                    return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: Text(
                          'Delete message?',
                          style: TextStyle(color: AppTheme.textPri),
                        ),
                        content: Text(
                          'This message will be deleted for everyone.',
                          style: TextStyle(color: AppTheme.textSec),
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
                onDismissed: (direction) {
                  if (direction == DismissDirection.endToStart) {
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
                },
                background: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.reply, color: AppTheme.purple),
                ),
                secondaryBackground: isMe
                    ? Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: AppTheme.red),
                      )
                    : Container(),
                child: Row(
                  mainAxisAlignment: isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: AppTheme.surface,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.reply,
                                      color: AppTheme.textPri,
                                    ),
                                    title: Text(
                                      'Reply',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.textPri,
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
                                    leading: const Icon(
                                      Icons.forward,
                                      color: AppTheme.textPri,
                                    ),
                                    title: Text(
                                      'Forward',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.textPri,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      // Just copy text to clipboard for now or fill the input field
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Forward functionality coming soon!',
                                          ),
                                        ),
                                      );
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
                                                chatId:
                                                    widget.item['id'] as String,
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
                                ? const Color(0xFF2A2A2E)
                                : const Color(0xFF1E1E20),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(12),
                              topRight: const Radius.circular(12),
                              bottomLeft: Radius.circular(isMe ? 12 : 2),
                              bottomRight: Radius.circular(isMe ? 2 : 12),
                            ),
                            border: Border.all(
                              color: isMe
                                  ? const Color(0xFF3A3A3E)
                                  : AppTheme.border,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show sender name in a box for group chats only
                              if (isGroup && !isMe)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.purple.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
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
    final iconColor = isMe ? AppTheme.purpleLt : AppTheme.textSec;
    final textStyle = GoogleFonts.inter(
      color: AppTheme.textPri,
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
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: msg.text,
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                  cacheManager: MediaCacheManager.instance,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 150,
                    color: AppTheme.surface,
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
                    color: AppTheme.surface,
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
                  borderRadius: BorderRadius.circular(6),
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
                        color: AppTheme.textPri,
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
                          color: AppTheme.muted,
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
                  borderRadius: BorderRadius.circular(6),
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
                      color: AppTheme.textPri,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Tap to open in Maps',
                    style: GoogleFonts.inter(
                      color: AppTheme.muted,
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
            color: AppTheme.muted,
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
                    color: AppTheme.textSec,
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
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(
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
                icon: const Icon(Icons.close, color: Colors.white),
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
          backgroundColor: const Color(0xFF161618),
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
    final c = color ?? AppTheme.textPri;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
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
    final c = color ?? AppTheme.textSec;
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
                  color: AppTheme.textPri,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(color: AppTheme.muted, fontSize: 10),
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
            inactiveThumbColor: AppTheme.muted,
            inactiveTrackColor: AppTheme.border,
          ),
        ),
      ],
    );
  }

  void _showAddMembersDialog(
    String groupId,
    List<String> currentMembers,
    List<UserModel> allUsers,
  ) {
    final availableUsers = allUsers
        .where((u) => !currentMembers.contains(u.uid))
        .toList();
    final selected = <String>{};

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                'Add Members',
                style: GoogleFonts.inter(
                  color: AppTheme.textPri,
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
                            color: AppTheme.muted,
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
                                  : AppTheme.muted,
                              size: 20,
                            ),
                            title: Text(
                              user.displayName,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPri,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              user.email,
                              style: GoogleFonts.inter(
                                color: AppTheme.muted,
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
                    style: GoogleFonts.inter(color: AppTheme.muted),
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
                          );
                        },
                  child: Text(
                    'Add (${selected.length})',
                    style: GoogleFonts.inter(
                      color: selected.isEmpty
                          ? AppTheme.muted
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
          backgroundColor: AppTheme.surface,
          title: Text(
            'Leave group?',
            style: GoogleFonts.inter(
              color: AppTheme.textPri,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'You will no longer receive messages from this group.',
            style: GoogleFonts.inter(color: AppTheme.textSec, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppTheme.muted),
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
    final favoriteUsers = filteredUsers
        .where((u) => favorites.contains(u.uid))
        .toList();
    final otherUsers = filteredUsers
        .where((u) => !favorites.contains(u.uid))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.only(
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
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
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
                      gradient: const LinearGradient(
                        colors: [AppTheme.purple, AppTheme.purpleLt],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(7),
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
                      color: AppTheme.textPri,
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
                style: GoogleFonts.inter(color: AppTheme.textPri, fontSize: 14),
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
                            color: AppTheme.muted,
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
      color: AppTheme.muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );

  Widget _buildUserItem(UserModel user, bool isFavorite) {
    final handle = '@${user.displayName.replaceAll(' ', '').toLowerCase()}';

    return InkWell(
      onTap: () => widget.onUserTap(user),
      borderRadius: BorderRadius.circular(8),
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
                    border: Border.all(color: AppTheme.border),
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
                            color: AppTheme.textPri,
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
                color: isFavorite ? AppTheme.yellow : AppTheme.muted,
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
