import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String photoUrl;
  final String createdBy;
  final List<String> members;
  final List<String> admins;
  final DateTime? createdAt;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final String lastMessageSenderName;
  final bool isPublic;

  GroupModel({
    required this.groupId,
    required this.name,
    this.description = '',
    this.photoUrl = '',
    required this.createdBy,
    required this.members,
    required this.admins,
    this.createdAt,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.lastMessageSenderName = '',
    this.isPublic = false,
  });

  int get memberCount => members.length;

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageSenderName: map['lastMessageSenderName'] ?? '',
      isPublic: map['isPublic'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'photoUrl': photoUrl,
      'createdBy': createdBy,
      'members': members,
      'admins': admins,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
      'isPublic': isPublic,
    };
  }
}
