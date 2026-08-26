import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../appwrite_client.dart';
import '../models/chat_model.dart';
import '../models/quick_reply_model.dart';
import '../models/user_model.dart';

class KeyboardBridgeService {
  KeyboardBridgeService._();
  static final KeyboardBridgeService instance = KeyboardBridgeService._();

  static const MethodChannel _channel =
      MethodChannel('com.amrosh.Pointchat/keyboard_bridge');

  static const String prefUserId = 'pointchat_kb_userId';
  static const String prefUserName = 'pointchat_kb_userName';
  static const String prefUserEmail = 'pointchat_kb_userEmail';
  static const String prefUserPhoto = 'pointchat_kb_userPhoto';
  static const String prefQuickReplies = 'pointchat_kb_quick_replies';
  static const String prefRecentChats = 'pointchat_kb_recent_chats';
  static const String prefAppwriteEndpoint = 'pointchat_kb_endpoint';
  static const String prefAppwriteProject = 'pointchat_kb_project';
  static const String prefAppwriteDatabase = 'pointchat_kb_database';
  static const String prefAppwriteJwt = 'pointchat_kb_jwt';
  static const String prefJwtExpiry = 'pointchat_kb_jwt_expiry';
  static const String prefShowPopup = 'pointchat_kb_show_popup';
  static const String prefKeyboardLang = 'pointchat_kb_lang';

  /// Synchronize the current logged in user and Appwrite configuration
  /// into shared storage so the native keyboard extensions can access it.
  /// Also generates a short-lived JWT (15 min) so the isolated keyboard
  /// extension can authenticate TablesDB requests without a full session cookie.
  Future<void> syncSession({
    required String userId,
    required String userName,
    required String userEmail,
    String? userPhotoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUserId, userId);
    await prefs.setString(prefUserName, userName);
    await prefs.setString(prefUserEmail, userEmail);
    await prefs.setString(prefUserPhoto, userPhotoUrl ?? '');
    await prefs.setString(prefAppwriteEndpoint, AppwriteConstants.endpoint);
    await prefs.setString(prefAppwriteProject, AppwriteConstants.projectId);
    await prefs.setString(prefAppwriteDatabase, AppwriteConstants.databaseId);

    // Generate a JWT for the keyboard extension (valid 15 min). Fire-and-forget
    // so syncSession never blocks or throws in tests/offline. The keyboard will
    // work in insert-to-host mode until a valid JWT is available.
    String jwt = prefs.getString(prefAppwriteJwt) ?? '';
    final expiryMs = prefs.getInt(prefJwtExpiry) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final needsRefresh = jwt.isEmpty || nowMs >= expiryMs - 60000; // refresh 1 min early
    if (needsRefresh) {
      // Background refresh — never awaited here so tests never hang on HttpClient 400/timeout.
      unawaited(_refreshJwtInBackground(prefs, nowMs));
    }

    // Call native channel to sync with iOS App Group / Android shared preferences if supported
    try {
      await _channel.invokeMethod('syncSession', {
        'userId': userId,
        'userName': userName,
        'userEmail': userEmail,
        'userPhotoUrl': userPhotoUrl ?? '',
        'endpoint': AppwriteConstants.endpoint,
        'projectId': AppwriteConstants.projectId,
        'databaseId': AppwriteConstants.databaseId,
        'jwt': jwt,
      });
    } catch (_) {}
  }

  Future<void> _refreshJwtInBackground(SharedPreferences prefs, int nowMs) async {
    // Skip JWT generation on desktop / test hosts — keyboard only needs it on Android/iOS.
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      final token = await appwriteAccount
          .createJWT()
          .timeout(const Duration(seconds: 3), onTimeout: () => throw TimeoutException('jwt timeout'));
      final jwt = token.jwt;
      final expiry = nowMs + 14 * 60 * 1000;
      await prefs.setString(prefAppwriteJwt, jwt);
      await prefs.setInt(prefJwtExpiry, expiry);
      try {
        await _channel.invokeMethod('syncSession', {
          'userId': prefs.getString(prefUserId) ?? '',
          'userName': prefs.getString(prefUserName) ?? '',
          'userEmail': prefs.getString(prefUserEmail) ?? '',
          'userPhotoUrl': prefs.getString(prefUserPhoto) ?? '',
          'endpoint': AppwriteConstants.endpoint,
          'projectId': AppwriteConstants.projectId,
          'databaseId': AppwriteConstants.databaseId,
          'jwt': jwt,
        });
      } catch (_) {}
    } catch (_) {
      // Silent — keyboard will fallback to local insert
    }
  }

  /// Force-refresh the JWT (call periodically or when extension reports 401).
  Future<String?> refreshJwt() async {
    try {
      final token = await appwriteAccount
          .createJWT()
          .timeout(const Duration(seconds: 3), onTimeout: () => throw TimeoutException('jwt timeout'));
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime.now().millisecondsSinceEpoch + 14 * 60 * 1000;
      await prefs.setString(prefAppwriteJwt, token.jwt);
      await prefs.setInt(prefJwtExpiry, expiry);
      try {
        await _channel.invokeMethod('syncSession', {
          'userId': prefs.getString(prefUserId) ?? '',
          'userName': prefs.getString(prefUserName) ?? '',
          'userEmail': prefs.getString(prefUserEmail) ?? '',
          'userPhotoUrl': prefs.getString(prefUserPhoto) ?? '',
          'endpoint': AppwriteConstants.endpoint,
          'projectId': AppwriteConstants.projectId,
          'databaseId': AppwriteConstants.databaseId,
          'jwt': token.jwt,
        });
      } catch (_) {}
      return token.jwt;
    } catch (_) {
      return null;
    }
  }

  /// Clear the shared session when the user logs out.
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserId);
    await prefs.remove(prefUserName);
    await prefs.remove(prefUserEmail);
    await prefs.remove(prefUserPhoto);
    await prefs.remove(prefRecentChats);
    await prefs.remove(prefAppwriteJwt);
    await prefs.remove(prefJwtExpiry);

    try {
      await _channel.invokeMethod('clearSession');
    } catch (_) {}
  }

  /// Retrieve configured quick replies.
  Future<List<QuickReplyModel>> getQuickReplies() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(prefQuickReplies);
    return QuickReplyModel.decodeList(jsonStr);
  }

  /// Save updated quick replies list.
  Future<void> saveQuickReplies(List<QuickReplyModel> replies) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = QuickReplyModel.encodeList(replies);
    await prefs.setString(prefQuickReplies, jsonStr);

    try {
      await _channel.invokeMethod('syncQuickReplies', {
        'quickRepliesJson': jsonStr,
      });
    } catch (_) {}
  }

  /// Add a single quick reply.
  Future<void> addQuickReply(QuickReplyModel reply) async {
    final current = await getQuickReplies();
    final updated = List<QuickReplyModel>.from(current)..add(reply);
    await saveQuickReplies(updated);
  }

  /// Delete a quick reply by ID.
  Future<void> deleteQuickReply(String id) async {
    final current = await getQuickReplies();
    final updated = current.where((r) => r.id != id).toList();
    await saveQuickReplies(updated);
  }

  // Popup toggle & language
  Future<bool> getShowPopup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefShowPopup) ?? true;
  }
  Future<void> setShowPopup(bool show) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefShowPopup, show);
    try {
      await _channel.invokeMethod('syncShowPopup', {'show': show});
    } catch (_) {}
  }
  Future<String> getKeyboardLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefKeyboardLang) ?? 'en';
  }
  Future<void> setKeyboardLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKeyboardLang, lang);
    try {
      await _channel.invokeMethod('syncLang', {'lang': lang});
    } catch (_) {}
  }

  /// Synchronize recent chats to native keyboard cache for fast rendering.
  /// Supports both 1:1 and group chats; the keyboard can swipe to pick any.
  /// Includes sender info, online dot, and photo for peek UI.
  Future<void> syncRecentChats(
    List<ChatModel> chats,
    Map<String, UserModel> usersMap,
    String currentUserId,
  ) async {
    final List<Map<String, dynamic>> snapshot = [];

    for (final chat in chats.take(15)) {
      final otherUserId = chat.participants.length == 2
          ? chat.participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => currentUserId,
            )
          : currentUserId;
      final user = chat.isGroup ? null : usersMap[otherUserId];
      final isOnline = user?.isOnline ?? false;
      // Prefer user displayName; fallback to chat metadata; for groups show participant count.
      final title = user?.displayName ??
          (chat.isGroup ? 'Group • ${chat.participants.length} members' : 'Direct Chat');
      final avatar = user?.photoUrl ?? '';

      snapshot.add({
        'chatId': chat.chatId,
        'title': title,
        'avatar': avatar,
        'otherUserId': otherUserId,
        'lastMessage': chat.lastMessage,
        'lastMessageTime': chat.lastMessageTime?.toIso8601String() ?? '',
        'lastMessageSenderId': chat.lastMessageSenderId,
        'unreadCount': chat.getUnreadFor(currentUserId),
        'isGroup': chat.isGroup,
        'participants': chat.participants,
        'isOnline': isOnline,
        'lastSeen': user?.lastSeen?.toIso8601String() ?? '',
      });
    }

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(snapshot);
    await prefs.setString(prefRecentChats, jsonStr);

    try {
      await _channel.invokeMethod('syncRecentChats', {
        'recentChatsJson': jsonStr,
      });
    } catch (_) {}
  }

  /// Synchronize recent group chats separately (optional enriched snapshot).
  Future<void> syncRecentGroups(
    List<dynamic> groups, // List<GroupModel> but dynamic to avoid import cycle
    String currentUserId,
  ) async {
    // Groups are merged into recentChats snapshot in unified_stream; this is
    // a supplementary sync for keyboards that want distinct group pills.
    try {
      final List<Map<String, dynamic>> snapshot = [];
      for (final g in groups.take(10)) {
        snapshot.add({
          'chatId': (g.groupId ?? g.chatId ?? '').toString(),
          'title': '# ${g.name ?? 'Group'}',
          'avatar': (g.photoUrl ?? '').toString(),
          'lastMessage': (g.lastMessage ?? '').toString(),
          'lastMessageTime': g.lastMessageTime?.toIso8601String() ?? '',
          'unreadCount': (g.unreadCount is Map ? (g.unreadCount[currentUserId] ?? 0) : 0),
          'isGroup': true,
        });
      }
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(prefRecentChats) ?? '[]';
      // Merge but keep existing direct chats first
      final List existingList = jsonDecode(existing);
      final merged = [...existingList, ...snapshot].take(15).toList();
      final jsonStr = jsonEncode(merged);
      await prefs.setString(prefRecentChats, jsonStr);
      await _channel.invokeMethod('syncRecentChats', {
        'recentChatsJson': jsonStr,
      });
    } catch (_) {}
  }

  /// Open system settings to enable the PointChat Keyboard.
  Future<bool> openSystemKeyboardSettings() async {
    if (kIsWeb) return false;

    try {
      final res = await _channel.invokeMethod<bool>('openKeyboardSettings');
      if (res == true) return true;
    } catch (_) {}

    // Fallback URL Launcher
    if (Platform.isIOS) {
      final uri = Uri.parse('app-settings:');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return false;
  }

  /// Show the system input method / keyboard picker popup.
  Future<void> showInputMethodPicker() async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod('showKeyboardPicker');
    } catch (_) {}
  }

  /// Check if the custom keyboard is enabled in system settings.
  Future<bool> isKeyboardEnabled() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('isKeyboardEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
