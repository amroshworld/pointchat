class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String status;
  final DateTime? lastSeen;
  /// Raw `isOnline` from the database (authoritative for writes).
  final bool onlineFlag;
  final List<String> chatIds;
  final List<String> groupIds;
  final List<String> favorites;
  final bool isBot;

  static const int onlineTtlMinutes = 5;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.status = 'Hey there! I am using PointChat',
    this.lastSeen,
    this.onlineFlag = false,
    this.chatIds = const [],
    this.groupIds = const [],
    this.favorites = const [],
    this.isBot = false,
  });

  /// Effective presence for UI: server flag must be true and [lastSeen] recent.
  bool get isOnline {
    if (isBot) return false;
    if (!onlineFlag) return false;
    if (lastSeen == null) return false;
    return DateTime.now().toUtc().difference(lastSeen!.toUtc()).inMinutes <=
        onlineTtlMinutes;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawOnline = map['isOnline'] == true;
    final parsedLastSeen = map['lastSeen'] != null
        ? DateTime.tryParse(map['lastSeen'].toString())
        : null;

    return UserModel(
      uid: map['\$id'] ?? map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      status: map['status'] ?? 'Hey there! I am using PointChat',
      lastSeen: parsedLastSeen,
      onlineFlag: rawOnline,
      chatIds: List<String>.from(map['chatIds'] ?? []),
      groupIds: List<String>.from(map['groupIds'] ?? []),
      favorites: List<String>.from(map['favorites'] ?? []),
      isBot: map['isBot'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'status': status,
      'lastSeen': lastSeen?.toUtc().toIso8601String(),
      'isOnline': onlineFlag,
      'chatIds': chatIds,
      'groupIds': groupIds,
      'favorites': favorites,
      'isBot': isBot,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? status,
    DateTime? lastSeen,
    bool? onlineFlag,
    List<String>? chatIds,
    List<String>? groupIds,
    List<String>? favorites,
    bool? isBot,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      onlineFlag: onlineFlag ?? this.onlineFlag,
      chatIds: chatIds ?? this.chatIds,
      groupIds: groupIds ?? this.groupIds,
      favorites: favorites ?? this.favorites,
      isBot: isBot ?? this.isBot,
    );
  }
}
