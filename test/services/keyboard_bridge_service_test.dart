import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:point_chat/models/chat_model.dart';
import 'package:point_chat/models/quick_reply_model.dart';
import 'package:point_chat/models/user_model.dart';
import 'package:point_chat/services/keyboard_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('KeyboardBridgeService', () {
    final service = KeyboardBridgeService.instance;

    test('syncSession saves user session details to SharedPreferences', () async {
      await service.syncSession(
        userId: 'user_test_999',
        userName: 'Test User',
        userEmail: 'test@pointchat.app',
        userPhotoUrl: 'https://example.com/avatar.jpg',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(KeyboardBridgeService.prefUserId), 'user_test_999');
      expect(prefs.getString(KeyboardBridgeService.prefUserName), 'Test User');
      expect(prefs.getString(KeyboardBridgeService.prefUserEmail), 'test@pointchat.app');
      expect(prefs.getString(KeyboardBridgeService.prefUserPhoto), 'https://example.com/avatar.jpg');
      expect(prefs.getString(KeyboardBridgeService.prefAppwriteProject), isNotEmpty);
    });

    test('clearSession removes user session from SharedPreferences', () async {
      await service.syncSession(
        userId: 'user_to_delete',
        userName: 'Delete Me',
        userEmail: 'del@pointchat.app',
      );

      await service.clearSession();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(KeyboardBridgeService.prefUserId), isNull);
      expect(prefs.getString(KeyboardBridgeService.prefUserName), isNull);
      expect(prefs.getString(KeyboardBridgeService.prefUserEmail), isNull);
    });

    test('getQuickReplies returns defaults when nothing is saved', () async {
      final replies = await service.getQuickReplies();
      expect(replies.isNotEmpty, isTrue);
      expect(replies.any((r) => r.title == "I'm on my way!"), isTrue);
    });

    test('saveQuickReplies persists and updates list', () async {
      final customReplies = [
        const QuickReplyModel(
          id: 'c1',
          title: 'Heading over',
          text: 'Heading over now!',
          category: 'Status',
          order: 1,
        ),
      ];

      await service.saveQuickReplies(customReplies);
      final retrieved = await service.getQuickReplies();
      expect(retrieved.length, 1);
      expect(retrieved.first.title, 'Heading over');
    });

    test('addQuickReply and deleteQuickReply modify the stored list', () async {
      await service.saveQuickReplies([]);
      expect(await service.getQuickReplies(), isEmpty);

      final newReply = const QuickReplyModel(
        id: 'new_1',
        title: 'New Shortcut',
        text: 'Full message text',
      );
      await service.addQuickReply(newReply);
      var current = await service.getQuickReplies();
      expect(current.length, 1);
      expect(current.first.id, 'new_1');

      await service.deleteQuickReply('new_1');
      current = await service.getQuickReplies();
      expect(current.isEmpty, isTrue);
    });

    test('syncRecentChats serializes contact snapshots for native keyboard', () async {
      final chats = [
        ChatModel(
          chatId: 'chat_1',
          participants: ['me', 'other_user'],
          lastMessage: 'Hello there!',
          lastMessageTime: DateTime.now(),
          unreadCount: {'me': 2, 'other_user': 0},
        ),
      ];

      final usersMap = {
        'other_user': UserModel(
          uid: 'other_user',
          displayName: 'John Doe',
          email: 'john@pointchat.app',
          photoUrl: 'https://example.com/john.jpg',
        ),
      };

      await service.syncRecentChats(chats, usersMap, 'me');

      final prefs = await SharedPreferences.getInstance();
      final recentChatsJson = prefs.getString(KeyboardBridgeService.prefRecentChats);
      expect(recentChatsJson, isNotNull);

      final List decoded = jsonDecode(recentChatsJson!);
      expect(decoded.length, 1);
      expect(decoded[0]['chatId'], 'chat_1');
      expect(decoded[0]['title'], 'John Doe');
      expect(decoded[0]['lastMessage'], 'Hello there!');
      expect(decoded[0]['unreadCount'], 2);
      expect(decoded[0]['isOnline'], isFalse);
    });
  });
}
