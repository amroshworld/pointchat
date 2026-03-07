import 'dart:async';

import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../appwrite_client.dart';
import '../models/message_model.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pointchat_messages',
    'PointChat Messages',
    description: 'Notifications for new direct and group messages.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;

  RealtimeSubscription? _subscription;
  String? _currentUserId;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> bindToUser(String userId) async {
    if (userId.isEmpty) {
      return;
    }

    await initialize();

    if (_currentUserId == userId && _subscription != null) {
      return;
    }

    await unbind();
    _currentUserId = userId;
    _subscription = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.messagesCollection}.documents',
    ]);

    _subscription!.stream.listen((event) async {
      if (!event.events.any((entry) => entry.endsWith('.create'))) {
        return;
      }

      try {
        await _handleIncomingMessage(
          userId,
          Map<String, dynamic>.from(event.payload),
        );
      } catch (error) {
        debugPrint('Notification handling error: $error');
      }
    });
  }

  Future<void> unbind() async {
    _subscription?.close();
    _subscription = null;
    _currentUserId = null;
  }

  Future<void> _handleIncomingMessage(
    String userId,
    Map<String, dynamic> payload,
  ) async {
    final messageId = payload[r'$id']?.toString() ?? '';
    final message = MessageModel.fromMap(payload, messageId);

    if (message.senderId == userId) {
      return;
    }

    final target = await _resolveNotificationTarget(userId, message);
    if (target == null) {
      return;
    }

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      target.title,
      _previewFor(message),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<_NotificationTarget?> _resolveNotificationTarget(
    String userId,
    MessageModel message,
  ) async {
    if (message.chatId != null && message.chatId!.isNotEmpty) {
      final chat = await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.chatsCollection,
        rowId: message.chatId!,
      );
      final participants = List<String>.from(chat.data['participants'] ?? []);
      if (!participants.contains(userId)) {
        return null;
      }

      return _NotificationTarget(title: message.senderName);
    }

    if (message.groupId != null && message.groupId!.isNotEmpty) {
      final group = await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.groupsCollection,
        rowId: message.groupId!,
      );
      final members = List<String>.from(group.data['members'] ?? []);
      if (!members.contains(userId)) {
        return null;
      }

      final groupName = group.data['name']?.toString() ?? 'Group';
      return _NotificationTarget(title: '${message.senderName} in $groupName');
    }

    return null;
  }

  String _previewFor(MessageModel message) {
    switch (message.type) {
      case MessageType.image:
        return 'Sent a photo';
      case MessageType.file:
        return 'Sent ${message.fileName ?? 'a file'}';
      case MessageType.audio:
        return 'Sent a voice message';
      case MessageType.location:
        return 'Shared a location';
      case MessageType.system:
      case MessageType.text:
        return message.text.trim().isEmpty
            ? 'New message'
            : message.text.trim();
    }
  }
}

class _NotificationTarget {
  const _NotificationTarget({required this.title});

  final String title;
}
