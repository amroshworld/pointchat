import 'dart:convert';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String photoUrl;
  final String createdBy;
  final List<String> members;

  /// Invited users not yet accepted (same element size as [members] user ids).
  final List<String> pendingMemberIds;
  final List<String> admins;
  final DateTime? createdAt;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final String lastMessageSenderName;
  final bool isPublic;

  /// Per-member unread counts (JSON string in Appwrite).
  final Map<String, int> unreadCount;

  GroupModel({
    required this.groupId,
    required this.name,
    this.description = '',
    this.photoUrl = '',
    required this.createdBy,
    required this.members,
    this.pendingMemberIds = const [],
    required this.admins,
    this.createdAt,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.lastMessageSenderName = '',
    this.isPublic = false,
    this.unreadCount = const {},
  });

  int get memberCount => members.length;

  /// Decode stored `unreadCount` (map or JSON string) without building a full row.
  static Map<String, int> decodeUnreadCount(dynamic val) =>
      _parseUnreadCount(val);

  static Map<String, int> _parseUnreadCount(dynamic val) {
    if (val is Map) {
      return Map<String, int>.from(
        val.map((k, v) =>
            MapEntry(k.toString(), (v is int) ? v : int.tryParse('$v') ?? 0)),
      );
    }
    if (val is String && val.isNotEmpty) {
      try {
        final decoded = jsonDecode(val);
        if (decoded is Map) {
          return Map<String, int>.from(
            decoded.map(
              (k, v) => MapEntry(
                  k.toString(), (v is int) ? v : int.tryParse('$v') ?? 0),
            ),
          );
        }
      } catch (_) {}
    }
    return {};
  }

  static String _asTrimmedString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v.trim();
    return v.toString().trim();
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: _asTrimmedString(map['name']),
      description: _asTrimmedString(map['description']),
      photoUrl: _asTrimmedString(map['photoUrl']),
      createdBy: _asTrimmedString(map['createdBy']),
      members: List<String>.from(map['members'] ?? []),
      pendingMemberIds: List<String>.from(map['pendingMemberIds'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      createdAt: map['\$createdAt'] != null
          ? DateTime.tryParse(map['\$createdAt'].toString())
          : null,
      lastMessage: _asTrimmedString(map['lastMessage']),
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.tryParse(map['lastMessageTime'].toString())
          : null,
      lastMessageSenderId: _asTrimmedString(map['lastMessageSenderId']),
      lastMessageSenderName: _asTrimmedString(map['lastMessageSenderName']),
      isPublic: map['isPublic'] == true,
      unreadCount: _parseUnreadCount(map['unreadCount']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': members,
      'pendingMemberIds': pendingMemberIds,
      'admins': admins,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toUtc().toIso8601String(),
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
      'isPublic': isPublic,
      'unreadCount': jsonEncode(unreadCount),
    };
  }
}
