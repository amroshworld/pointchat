import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, file, audio, location, system }

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

  // Extra metadata for rich messages
  final String? fileName;
  final int? fileSize;
  final int? audioDuration; // seconds
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
    this.fileName,
    this.fileSize,
    this.audioDuration,
    this.latitude,
    this.longitude,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
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
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : null,
      isRead: map['isRead'] ?? false,
      readBy: Map<String, bool>.from(map['readBy'] ?? {}),
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
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': isRead,
      'readBy': readBy,
      if (fileName != null) 'fileName': fileName,
      if (fileSize != null) 'fileSize': fileSize,
      if (audioDuration != null) 'audioDuration': audioDuration,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Preview string for conversation list
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
