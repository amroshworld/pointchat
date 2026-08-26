import 'dart:convert';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final Map<String, bool> seenEnabled;
  final List<Map<String, String>> seenRequests;
  final Map<String, bool> notifyOnSeen;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.unreadCount = const {},
    this.seenEnabled = const {},
    this.seenRequests = const [],
    this.notifyOnSeen = const {},
  });

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    // unreadCount, seenEnabled, notifyOnSeen are stored as JSON strings in Appwrite
    Map<String, int> parseUnreadCount(dynamic val) {
      if (val is Map) return Map<String, int>.from(val);
      if (val is String && val.isNotEmpty) {
        try {
          return Map<String, int>.from(jsonDecode(val));
        } catch (_) {}
      }
      return {};
    }

    Map<String, bool> parseBoolMap(dynamic val) {
      if (val is Map) return Map<String, bool>.from(val);
      if (val is String && val.isNotEmpty) {
        try {
          return Map<String, bool>.from(jsonDecode(val));
        } catch (_) {}
      }
      return {};
    }

    List<Map<String, String>> parseSeenRequests(dynamic val) {
      if (val is List) {
        return val.map((e) => Map<String, String>.from(e as Map)).toList();
      }
      if (val is String && val.isNotEmpty) {
        try {
          final list = jsonDecode(val) as List;
          return list.map((e) => Map<String, String>.from(e)).toList();
        } catch (_) {}
      }
      return [];
    }

    return ChatModel(
      chatId: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'])
          : null,
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      unreadCount: parseUnreadCount(map['unreadCount']),
      seenEnabled: parseBoolMap(map['seenEnabled']),
      seenRequests: parseSeenRequests(map['seenRequests']),
      notifyOnSeen: parseBoolMap(map['notifyOnSeen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toUtc().toIso8601String() ??
          DateTime.now().toUtc().toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': jsonEncode(unreadCount),
      'seenEnabled': jsonEncode(seenEnabled),
      'seenRequests': jsonEncode(seenRequests),
      'notifyOnSeen': jsonEncode(notifyOnSeen),
    };
  }

  String getOtherUserId(String currentUserId) {
    if (participants.isEmpty) return '';
    final unique = participants.toSet().toList();
    // Self-DM / AI thread: [userId, userId] — old code returned '' and broke UI.
    if (unique.length == 1 && unique.first == currentUserId) {
      return currentUserId;
    }
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.first,
    );
  }

  /// True when this chat is the special same-user thread (AI / notes).
  bool get isSelfParticipantChat {
    if (participants.length != 2) return false;
    return participants[0] == participants[1];
  }

  /// True when this chat represents a group conversation (more than 2 participants).
  bool get isGroup => participants.length > 2;

  /// Returns unread count for a given user ID.
  int getUnreadFor(String userId) => unreadCount[userId] ?? 0;
}
