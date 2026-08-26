import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:point_chat/models/message_model.dart';

void main() {
  group('MessageModel', () {
    test('creates and serializes text message properly', () {
      final msg = MessageModel(
        messageId: 'msg_001',
        senderId: 'user_1',
        senderName: 'Alice',
        text: 'Hello from keyboard!',
        type: MessageType.text,
        chatId: 'chat_123',
        readBy: {'user_1': true},
      );

      expect(msg.preview, 'Hello from keyboard!');
      final map = msg.toMap();
      expect(map['senderId'], 'user_1');
      expect(map['senderName'], 'Alice');
      expect(map['text'], 'Hello from keyboard!');
      expect(map['type'], 'text');
      expect(map['chatId'], 'chat_123');

      final reconstructed = MessageModel.fromMap(map, 'msg_001');
      expect(reconstructed.messageId, 'msg_001');
      expect(reconstructed.text, 'Hello from keyboard!');
      expect(reconstructed.type, MessageType.text);
      expect(reconstructed.readBy['user_1'], isTrue);
    });

    test('previews display appropriate icons for media types', () {
      final photo = MessageModel(
        messageId: 'm1',
        senderId: 'u1',
        senderName: 'Bob',
        text: '',
        type: MessageType.image,
      );
      expect(photo.preview, '📷 Photo');

      final audio = MessageModel(
        messageId: 'm2',
        senderId: 'u1',
        senderName: 'Bob',
        text: '',
        type: MessageType.audio,
      );
      expect(audio.preview, '🎙️ Voice message');

      final file = MessageModel(
        messageId: 'm3',
        senderId: 'u1',
        senderName: 'Bob',
        text: '',
        fileName: 'report.pdf',
        type: MessageType.file,
      );
      expect(file.preview, '📎 report.pdf');

      final location = MessageModel(
        messageId: 'm4',
        senderId: 'u1',
        senderName: 'Bob',
        text: '',
        type: MessageType.location,
      );
      expect(location.preview, '📍 Location');
    });

    test('fromMap parses JSON encoded string readBy and status', () {
      final map = {
        'senderId': 'u1',
        'senderName': 'Bob',
        'text': 'Test',
        'type': 'text',
        'readBy': jsonEncode({'u1': true, 'u2': true}),
        'status': 'read',
      };

      final msg = MessageModel.fromMap(map, 'm_test');
      expect(msg.readBy['u1'], isTrue);
      expect(msg.readBy['u2'], isTrue);
      expect(msg.status, MessageStatus.read);
    });
  });
}
