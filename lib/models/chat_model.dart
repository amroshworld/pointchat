import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;

  /// Per-chat seen settings: each participant can enable/disable seen for this chat
  /// Key: userId, Value: true if that user allows seen status to be shown
  final Map<String, bool> seenEnabled;

  /// Pending seen requests: userId who requested → userId they requested from
  /// e.g. { 'amrId': 'saraId' } means Amr requested seen access from Sara
  final List<Map<String, String>> seenRequests;

  /// Whether to notify when the message is seen (per user setting)
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
    return ChatModel(
      chatId: id,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      seenEnabled: Map<String, bool>.from(map['seenEnabled'] ?? {}),
      seenRequests:
          (map['seenRequests'] as List<dynamic>?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      notifyOnSeen: Map<String, bool>.from(map['notifyOnSeen'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'seenEnabled': seenEnabled,
      'seenRequests': seenRequests,
      'notifyOnSeen': notifyOnSeen,
    };
  }

  /// Get the other participant's UID in a 1-to-1 chat
  String getOtherUserId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}
