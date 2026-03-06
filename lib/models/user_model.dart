class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String photoUrl;
  final String status;
  final DateTime? lastSeen;
  final bool isOnline;
  final List<String> chatIds;
  final List<String> groupIds;
  final List<String> favorites;

  UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl = '',
    this.status = 'Hey there! I am using PointChat',
    this.lastSeen,
    this.isOnline = false,
    this.chatIds = const [],
    this.groupIds = const [],
    this.favorites = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['\$id'] ?? map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      status: map['status'] ?? 'Hey there! I am using PointChat',
      lastSeen: map['lastSeen'] != null
          ? DateTime.tryParse(map['lastSeen'])
          : null,
      isOnline: map['isOnline'] ?? false,
      chatIds: List<String>.from(map['chatIds'] ?? []),
      groupIds: List<String>.from(map['groupIds'] ?? []),
      favorites: List<String>.from(map['favorites'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'status': status,
      'lastSeen': lastSeen?.toUtc().toIso8601String(),
      'isOnline': isOnline,
      'chatIds': chatIds,
      'groupIds': groupIds,
      'favorites': favorites,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? status,
    DateTime? lastSeen,
    bool? isOnline,
    List<String>? chatIds,
    List<String>? groupIds,
    List<String>? favorites,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      isOnline: isOnline ?? this.isOnline,
      chatIds: chatIds ?? this.chatIds,
      groupIds: groupIds ?? this.groupIds,
      favorites: favorites ?? this.favorites,
    );
  }
}
