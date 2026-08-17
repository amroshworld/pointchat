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
  RealtimeSubscription? _inviteSubscription;
  String? _currentUserId;
  bool _initialized = false;
  int _notificationId = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      );

      await _plugin.initialize(settings);

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.requestNotificationsPermission();

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization error: $e');
    }
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
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.messagesCollection),
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

    _inviteSubscription = _realtime.subscribe([
      AppwriteRealtimeChannels.tableRows(
        AppwriteConstants.groupInvitesCollection,
      ),
    ]);
    _inviteSubscription!.stream.listen((event) async {
      if (!event.events.any((e) => e.endsWith('.create'))) {
        return;
      }
      try {
        final raw = event.payload;
        final payload = Map<String, dynamic>.from(raw);
        if (payload['userId']?.toString() != userId) return;
        if (payload['status']?.toString() != 'pending') return;
        final groupId = payload['groupId']?.toString();
        if (groupId == null || groupId.isEmpty) return;

        String title = 'Group invite';
        try {
          final group = await _databases.getRow(
            databaseId: AppwriteConstants.databaseId,
            tableId: AppwriteConstants.groupsCollection,
            rowId: groupId,
          );
          final name = group.data['name']?.toString();
          if (name != null && name.isNotEmpty) {
            title = 'Invited to "$name"';
          }
        } catch (_) {}

        await _plugin.show(
          _nextNotificationId(),
          title,
          'Open PointChat to accept or decline.',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
        );
      } catch (error) {
        debugPrint('Invite notification error: $error');
      }
    });
  }

  Future<void> unbind() async {
    _subscription?.close();
    _subscription = null;
    _inviteSubscription?.close();
    _inviteSubscription = null;
    _currentUserId = null;
  }

  int _nextNotificationId() {
    _notificationId = (_notificationId + 1) % (1 << 31);
    return _notificationId;
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
      _nextNotificationId(),
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
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
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
