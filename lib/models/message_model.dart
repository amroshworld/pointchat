import 'dart:convert';

enum MessageType { text, image, file, audio, location, system }

enum MessageStatus { sending, sent, delivered, read }

class MessageModel {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderPhotoUrl;
  final String text;
  final MessageType type;
  final DateTime? timestamp;
  final bool isRead;
  final Map<String, bool> readBy;
  final String? chatId;
  final String? groupId;
  final MessageStatus status;

  final String? fileName;
  final int? fileSize;
  final int? audioDuration;
  final double? latitude;
  final double? longitude;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl = '',
    required this.text,
    this.type = MessageType.text,
    this.timestamp,
    this.isRead = false,
    this.readBy = const {},
    this.chatId,
    this.groupId,
    this.status = MessageStatus.sent,
    this.fileName,
    this.fileSize,
    this.audioDuration,
    this.latitude,
    this.longitude,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, bool> parseReadBy(dynamic val) {
      if (val is Map) return Map<String, bool>.from(val);
      if (val is String && val.isNotEmpty) {
        try {
          return Map<String, bool>.from(jsonDecode(val));
        } catch (_) {}
      }
      return {};
    }

    MessageStatus parseStatus(dynamic val) {
      if (val is String) {
        return MessageStatus.values.firstWhere(
          (e) => e.name == val,
          orElse: () => MessageStatus.sent,
        );
      }
      return MessageStatus.sent;
    }

    return MessageModel(
      messageId: id,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderPhotoUrl: map['senderPhotoUrl'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      timestamp: map['\$createdAt'] != null
          ? DateTime.tryParse(map['\$createdAt'])
          : null,
      isRead: map['isRead'] ?? false,
      readBy: parseReadBy(map['readBy']),
      chatId: map['chatId'],
      groupId: map['groupId'],
      status: parseStatus(map['status']),
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      audioDuration: map['audioDuration'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'type': type.name,
      'isRead': isRead,
      'readBy': jsonEncode(readBy),
      if (chatId != null) 'chatId': chatId,
      if (groupId != null) 'groupId': groupId,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? senderName,
    String? senderPhotoUrl,
    String? text,
    MessageType? type,
    DateTime? timestamp,
    bool? isRead,
    Map<String, bool>? readBy,
    String? chatId,
    String? groupId,
    MessageStatus? status,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    double? latitude,
    double? longitude,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderPhotoUrl: senderPhotoUrl ?? this.senderPhotoUrl,
      text: text ?? this.text,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      readBy: readBy ?? this.readBy,
      chatId: chatId ?? this.chatId,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      audioDuration: audioDuration ?? this.audioDuration,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get preview {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.file:
        return '📎 ${fileName ?? 'File'}';
      case MessageType.audio:
        return '🎙️ Voice message';
      case MessageType.location:
        return '📍 Location';
      case MessageType.system:
        return text;
      case MessageType.text:
        return text;
    }
  }
}
