import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:point_chat/models/chat_model.dart';

void main() {
  group('ChatModel', () {
    test('creates and serializes direct chat correctly', () {
      final chat = ChatModel(
        chatId: 'chat_abc',
        participants: ['user_1', 'user_2'],
        lastMessage: 'Hey there',
        lastMessageSenderId: 'user_1',
        unreadCount: {'user_1': 0, 'user_2': 1},
        seenEnabled: {'user_1': true, 'user_2': true},
      );

      expect(chat.isGroup, isFalse);
      expect(chat.getOtherUserId('user_1'), 'user_2');
      expect(chat.getOtherUserId('user_2'), 'user_1');
      expect(chat.getUnreadFor('user_2'), 1);
      expect(chat.getUnreadFor('user_1'), 0);

      final map = chat.toMap();
      expect(map['participants'], containsAll(['user_1', 'user_2']));
      expect(map['lastMessage'], 'Hey there');

      final reconstructed = ChatModel.fromMap(map, 'chat_abc');
      expect(reconstructed.chatId, 'chat_abc');
      expect(reconstructed.participants.length, 2);
      expect(reconstructed.unreadCount['user_2'], 1);
    });

    test('parses unreadCount from JSON string', () {
      final map = {
        'participants': ['u1', 'u2'],
        'unreadCount': jsonEncode({'u1': 3, 'u2': 0}),
        'seenEnabled': jsonEncode({'u1': true, 'u2': false}),
      };

      final chat = ChatModel.fromMap(map, 'c1');
      expect(chat.getUnreadFor('u1'), 3);
      expect(chat.getUnreadFor('u2'), 0);
      expect(chat.seenEnabled['u2'], isFalse);
    });

    test('group chat detection', () {
      final groupChat = ChatModel(
        chatId: 'g_1',
        participants: ['u1', 'u2', 'u3'],
      );
      expect(groupChat.isGroup, isTrue);
    });
  });
}
