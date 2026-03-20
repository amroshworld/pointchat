import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;

  // Get or create a chat between two users
  Future<String> getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    // Check if chat already exists
    final result = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      queries: [
        Query.contains('participants', [currentUserId]),
        Query.limit(500),
      ],
    );

    for (final doc in result.rows) {
      final participants = List<String>.from(doc.data['participants'] ?? []);
      if (participants.length != 2) continue;

      // Self / AI thread: [userId, userId] only. Do not match [me, someoneElse].
      if (currentUserId == otherUserId) {
        if (participants[0] == participants[1] &&
            participants[0] == currentUserId) {
          return doc.$id;
        }
        continue;
      }

      if (participants.contains(otherUserId)) {
        return doc.$id;
      }
    }

    // Create new chat with default seen settings
    final chatId = ID.unique();
    final chat = ChatModel(
      chatId: chatId,
      participants: [currentUserId, otherUserId],
      seenEnabled: {currentUserId: true, otherUserId: true},
      notifyOnSeen: {currentUserId: false, otherUserId: false},
    );
    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: chat.toMap(),
    );

    // Update both users' chatIds
    await _addToArray(
      AppwriteConstants.usersCollection,
      currentUserId,
      'chatIds',
      chatId,
    );
    await _addToArray(
      AppwriteConstants.usersCollection,
      otherUserId,
      'chatIds',
      chatId,
    );

    return chatId;
  }

  // Get user's chats stream
  Stream<List<ChatModel>> getUserChats(String userId) {
    final controller = StreamController<List<ChatModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.chatsCollection,
          queries: [
            Query.contains('participants', [userId]),
            Query.orderDesc('lastMessageTime'),
            Query.limit(100),
          ],
        );
        if (!controller.isClosed) {
          controller.add(
            result.rows
                .map((doc) => ChatModel.fromMap(doc.data, doc.$id))
                .toList(),
          );
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.chatsCollection),
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get a single chat stream
  Stream<ChatModel?> getChatStream(String chatId) {
    final controller = StreamController<ChatModel?>.broadcast();

    Future<void> fetch() async {
      try {
        final doc = await _databases.getRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.chatsCollection,
          rowId: chatId,
        );
        if (!controller.isClosed) {
          controller.add(ChatModel.fromMap(doc.data, doc.$id));
        }
      } on AppwriteException catch (e) {
        if (e.code == 404 && !controller.isClosed) {
          controller.add(null);
        } else if (!controller.isClosed) {
          controller.addError(e);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      AppwriteRealtimeChannels.tableRow(
        AppwriteConstants.chatsCollection,
        chatId,
      ),
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get messages stream for a chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    final controller = StreamController<List<MessageModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.messagesCollection,
          queries: [
            Query.equal('chatId', chatId),
            Query.orderDesc('\$createdAt'),
            Query.limit(100),
          ],
        );
        if (!controller.isClosed) {
          controller.add(
            result.rows
                .map((doc) => MessageModel.fromMap(doc.data, doc.$id))
                .toList(),
          );
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.messagesCollection),
    ]);
    sub.stream.listen((event) {
      final payload = event.payload;
      final chat = payload is Map ? payload['chatId'] : null;
      if (chat == chatId || event.events.any((e) => e.contains('.delete'))) {
        fetch();
      }
    });
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get recent unread messages for AI summary
  Future<List<MessageModel>> getUnreadMessages(
    String chatId,
    String userId,
  ) async {
    try {
      final result = await _databases.listRows(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.messagesCollection,
        queries: [
          Query.equal('chatId', chatId),
          Query.orderDesc('\$createdAt'),
          Query.limit(50),
        ],
      );

      final allMessages = result.rows
          .map((doc) => MessageModel.fromMap(doc.data, doc.$id))
          .toList();

      // Filter out messages that the user has already read
      return allMessages.where((msg) {
        final readBy = msg.readBy;
        return !(readBy[userId] ?? false);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderPhotoUrl,
    required String text,
    MessageType type = MessageType.text,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    double? latitude,
    double? longitude,
  }) async {
    final messageId = ID.unique();
    final chatDoc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final unreadCount = _decodeJsonMap(chatDoc.data['unreadCount']);
    final participants = List<String>.from(chatDoc.data['participants'] ?? []);

    for (final participantId in participants) {
      if (participantId == senderId) {
        unreadCount[participantId] = 0;
        continue;
      }

      unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
    }

    final message = MessageModel(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      type: type,
      readBy: {senderId: true},
      fileName: fileName,
      fileSize: fileSize,
      audioDuration: audioDuration,
      latitude: latitude,
      longitude: longitude,
    );

    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      rowId: messageId,
      data: message.toMap(),
    );

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {
        'lastMessage': message.preview,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'lastMessageSenderId': senderId,
        'unreadCount': jsonEncode(unreadCount),
      },
    );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final result = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      queries: [
        Query.equal('chatId', chatId),
        Query.notEqual('senderId', userId),
        Query.equal('isRead', false),
        Query.limit(100),
      ],
    );

    for (final doc in result.rows) {
      final readBy = _decodeJsonMap(doc.data['readBy']);
      readBy[userId] = true;

      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.messagesCollection,
        rowId: doc.$id,
        data: {'isRead': true, 'readBy': jsonEncode(readBy)},
      );
    }

    // Reset unread count for user
    final chatDoc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final unreadCount = _decodeJsonMap(chatDoc.data['unreadCount']);
    unreadCount[userId] = 0;

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {'unreadCount': jsonEncode(unreadCount)},
    );
  }

  // ── Seen Status Management ──

  Future<void> toggleSeenEnabled(
    String chatId,
    String userId,
    bool enabled,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final seenEnabled = _decodeJsonMap(doc.data['seenEnabled']);
    seenEnabled[userId] = enabled;

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {'seenEnabled': jsonEncode(seenEnabled)},
    );
  }

  Future<void> requestSeenAccess({
    required String chatId,
    required String requesterId,
    required String targetId,
  }) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final requests = _decodeJsonList(doc.data['seenRequests']);
    requests.add({'from': requesterId, 'to': targetId});

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {'seenRequests': jsonEncode(requests)},
    );
  }

  Future<void> approveSeenRequest({
    required String chatId,
    required String approverId,
    required String requesterId,
  }) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );

    final requests = _decodeJsonList(doc.data['seenRequests']);
    requests.removeWhere(
      (r) => r['from'] == requesterId && r['to'] == approverId,
    );

    final seenEnabled = _decodeJsonMap(doc.data['seenEnabled']);
    seenEnabled[approverId] = true;

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {
        'seenRequests': jsonEncode(requests),
        'seenEnabled': jsonEncode(seenEnabled),
      },
    );
  }

  Future<void> denySeenRequest({
    required String chatId,
    required String requesterId,
    required String targetId,
  }) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final requests = _decodeJsonList(doc.data['seenRequests']);
    requests.removeWhere(
      (r) => r['from'] == requesterId && r['to'] == targetId,
    );

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {'seenRequests': jsonEncode(requests)},
    );
  }

  Future<void> toggleNotifyOnSeen(
    String chatId,
    String userId,
    bool enabled,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );
    final notifyOnSeen = _decodeJsonMap(doc.data['notifyOnSeen']);
    notifyOnSeen[userId] = enabled;

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {'notifyOnSeen': jsonEncode(notifyOnSeen)},
    );
  }

  Future<void> deleteMessage(String messageId, {String? chatId}) async {
    await _databases.deleteRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      rowId: messageId,
    );

    if (chatId != null && chatId.isNotEmpty) {
      await _refreshChatLastMessage(chatId);
    }
  }

  Future<void> _refreshChatLastMessage(String chatId) async {
    final latest = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      queries: [
        Query.equal('chatId', chatId),
        Query.orderDesc('\$createdAt'),
        Query.limit(1),
      ],
    );

    if (latest.rows.isEmpty) {
      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.chatsCollection,
        rowId: chatId,
        data: {'lastMessage': '', 'lastMessageSenderId': ''},
      );
      return;
    }

    final msg = MessageModel.fromMap(
      latest.rows.first.data,
      latest.rows.first.$id,
    );
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
      data: {
        'lastMessage': msg.preview,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'lastMessageSenderId': msg.senderId,
      },
    );
  }

  // Delete a chat
  Future<void> deleteChat(String chatId, List<String> participants) async {
    // Delete all messages for this chat
    final messages = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      queries: [Query.equal('chatId', chatId), Query.limit(500)],
    );

    await Future.wait(
      messages.rows.map(
        (doc) => _databases.deleteRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.messagesCollection,
          rowId: doc.$id,
        ),
      ),
    );

    // Delete chat document
    await _databases.deleteRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.chatsCollection,
      rowId: chatId,
    );

    // Remove chatId from users
    await Future.wait(
      participants.map(
        (userId) => _removeFromArray(
          AppwriteConstants.usersCollection,
          userId,
          'chatIds',
          chatId,
        ),
      ),
    );
  }

  // ── Helpers ──

  Map<String, dynamic> _decodeJsonMap(dynamic value) {
    if (value == null || value == '') return {};
    if (value is Map) return Map<String, dynamic>.from(value);
    try {
      return Map<String, dynamic>.from(jsonDecode(value));
    } catch (_) {
      return {};
    }
  }

  List<Map<String, dynamic>> _decodeJsonList(dynamic value) {
    if (value == null || value == '') return [];
    if (value is List) return List<Map<String, dynamic>>.from(value);
    try {
      return List<Map<String, dynamic>>.from(jsonDecode(value));
    } catch (_) {
      return [];
    }
  }

  Future<void> _addToArray(
    String collectionId,
    String docId,
    String field,
    String value,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: collectionId,
      rowId: docId,
    );
    final arr = List<String>.from(doc.data[field] ?? []);
    if (!arr.contains(value)) arr.add(value);
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: collectionId,
      rowId: docId,
      data: {field: arr},
    );
  }

  Future<void> _removeFromArray(
    String collectionId,
    String docId,
    String field,
    String value,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: collectionId,
      rowId: docId,
    );
    final arr = List<String>.from(doc.data[field] ?? []);
    arr.remove(value);
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: collectionId,
      rowId: docId,
      data: {field: arr},
    );
  }
}
