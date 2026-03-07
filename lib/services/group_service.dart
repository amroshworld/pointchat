import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';

class GroupService {
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required List<String> members,
    String photoUrl = '',
    bool isPublic = false,
  }) async {
    final groupId = ID.unique();

    // Include creator in members and admins
    final allMembers = {...members, createdBy}.toList();

    final group = GroupModel(
      groupId: groupId,
      name: name,
      description: description,
      photoUrl: photoUrl,
      createdBy: createdBy,
      members: allMembers,
      admins: [createdBy],
      isPublic: isPublic,
    );

    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: group.toMap(),
    );

    // Update all members' groupIds
    for (final memberId in allMembers) {
      await _addToArray(
        AppwriteConstants.usersCollection,
        memberId,
        'groupIds',
        groupId,
      );
    }

    // Send system message
    await sendGroupMessage(
      groupId: groupId,
      senderId: createdBy,
      senderName: 'System',
      text: 'Group "$name" created',
      type: MessageType.system,
    );

    return groupId;
  }

  // Get user's groups stream
  Stream<List<GroupModel>> getUserGroups(String userId) {
    final controller = StreamController<List<GroupModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupsCollection,
          queries: [
            Query.contains('members', [userId]),
            Query.orderDesc('lastMessageTime'),
            Query.limit(100),
          ],
        );
        if (!controller.isClosed) {
          controller.add(
            result.rows
                .map((doc) => GroupModel.fromMap(doc.data, doc.$id))
                .toList(),
          );
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.groupsCollection}.documents',
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get group by ID stream
  Stream<GroupModel?> getGroupStream(String groupId) {
    final controller = StreamController<GroupModel?>.broadcast();

    Future<void> fetch() async {
      try {
        final doc = await _databases.getRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupsCollection,
          rowId: groupId,
        );
        if (!controller.isClosed) {
          controller.add(GroupModel.fromMap(doc.data, doc.$id));
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
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.groupsCollection}.documents.$groupId',
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get popular / public groups stream
  Stream<List<GroupModel>> getPopularGroups() {
    final controller = StreamController<List<GroupModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupsCollection,
          queries: [Query.equal('isPublic', true), Query.limit(100)],
        );
        if (!controller.isClosed) {
          final groups = result.rows
              .map((doc) => GroupModel.fromMap(doc.data, doc.$id))
              .toList();
          groups.sort((a, b) => b.memberCount.compareTo(a.memberCount));
          controller.add(groups);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.groupsCollection}.documents',
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get messages stream for a group
  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    final controller = StreamController<List<MessageModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.messagesCollection,
          queries: [
            Query.equal('groupId', groupId),
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
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.messagesCollection}.documents',
    ]);
    sub.stream.listen((event) {
      if (event.payload['groupId'] == groupId ||
          event.events.any((e) => e.contains('.delete'))) {
        fetch();
      }
    });
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Get recent unread messages for AI summary
  Future<List<MessageModel>> getUnreadGroupMessages(
    String groupId,
    String userId,
  ) async {
    try {
      final result = await _databases.listRows(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.messagesCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.orderDesc('\$createdAt'),
          Query.limit(50),
        ],
      );

      final allMessages = result.rows
          .map((doc) => MessageModel.fromMap(doc.data, doc.$id))
          .toList();

      return allMessages.where((msg) {
        final readBy = msg.readBy;
        return !(readBy[userId] ?? false);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Send a group message
  Future<void> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String text,
    String senderPhotoUrl = '',
    MessageType type = MessageType.text,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    double? latitude,
    double? longitude,
  }) async {
    final messageId = ID.unique();
    final message = MessageModel(
      messageId: messageId,
      groupId: groupId,
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
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'lastMessage': message.preview,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'lastMessageSenderId': senderId,
        'lastMessageSenderName': senderName,
      },
    );
  }

  Future<void> deleteMessage(String messageId, {String? groupId}) async {
    await _databases.deleteRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      rowId: messageId,
    );

    if (groupId != null && groupId.isNotEmpty) {
      await _refreshGroupLastMessage(groupId);
    }
  }

  Future<void> _refreshGroupLastMessage(String groupId) async {
    final latest = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.orderDesc('\$createdAt'),
        Query.limit(1),
      ],
    );

    if (latest.rows.isEmpty) {
      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.groupsCollection,
        rowId: groupId,
        data: {
          'lastMessage': '',
          'lastMessageSenderId': '',
          'lastMessageSenderName': '',
        },
      );
      return;
    }

    final msg = MessageModel.fromMap(
      latest.rows.first.data,
      latest.rows.first.$id,
    );
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'lastMessage': msg.preview,
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'lastMessageSenderId': msg.senderId,
        'lastMessageSenderName': msg.senderName,
      },
    );
  }

  // Add members to group
  Future<void> addMembers(
    String groupId,
    List<String> newMembers,
    String addedByName,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final members = List<String>.from(doc.data['members'] ?? []);
    for (final m in newMembers) {
      if (!members.contains(m)) members.add(m);
    }

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'members': members},
    );

    for (final memberId in newMembers) {
      await _addToArray(
        AppwriteConstants.usersCollection,
        memberId,
        'groupIds',
        groupId,
      );
    }

    await sendGroupMessage(
      groupId: groupId,
      senderId: 'system',
      senderName: 'System',
      text: '$addedByName added ${newMembers.length} member(s)',
      type: MessageType.system,
    );
  }

  // Remove member from group (admin action)
  Future<void> removeMember(
    String groupId,
    String memberId, {
    String? removedByName,
  }) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final members = List<String>.from(doc.data['members'] ?? []);
    final admins = List<String>.from(doc.data['admins'] ?? []);
    members.remove(memberId);
    admins.remove(memberId);

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'members': members, 'admins': admins},
    );

    await _removeFromArray(
      AppwriteConstants.usersCollection,
      memberId,
      'groupIds',
      groupId,
    );

    if (removedByName != null) {
      await sendGroupMessage(
        groupId: groupId,
        senderId: 'system',
        senderName: 'System',
        text: '$removedByName removed a member',
        type: MessageType.system,
      );
    }
  }

  // Leave group (user action)
  Future<void> leaveGroup(
    String groupId,
    String userId,
    String userName,
  ) async {
    await removeMember(groupId, userId);

    await sendGroupMessage(
      groupId: groupId,
      senderId: 'system',
      senderName: 'System',
      text: '$userName left the group',
      type: MessageType.system,
    );
  }

  // Join a public group
  Future<void> joinGroup(String groupId, String userId, String userName) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final members = List<String>.from(doc.data['members'] ?? []);
    if (!members.contains(userId)) members.add(userId);

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'members': members},
    );

    await _addToArray(
      AppwriteConstants.usersCollection,
      userId,
      'groupIds',
      groupId,
    );

    await sendGroupMessage(
      groupId: groupId,
      senderId: 'system',
      senderName: 'System',
      text: '$userName joined the group',
      type: MessageType.system,
    );
  }

  // Toggle group public/private
  Future<void> togglePublic(String groupId, bool isPublic) async {
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'isPublic': isPublic},
    );
  }

  // Make admin
  Future<void> makeAdmin(String groupId, String userId) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );
    final admins = List<String>.from(doc.data['admins'] ?? []);
    if (!admins.contains(userId)) admins.add(userId);
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'admins': admins},
    );
  }

  // Remove admin
  Future<void> removeAdmin(String groupId, String userId) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );
    final admins = List<String>.from(doc.data['admins'] ?? []);
    admins.remove(userId);
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {'admins': admins},
    );
  }

  // Update group info
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: data,
    );
  }

  // Delete group
  Future<void> deleteGroup(String groupId, List<String> members) async {
    // Delete all messages for this group
    final messages = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.messagesCollection,
      queries: [Query.equal('groupId', groupId), Query.limit(500)],
    );

    for (final doc in messages.rows) {
      await _databases.deleteRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.messagesCollection,
        rowId: doc.$id,
      );
    }

    // Delete group
    await _databases.deleteRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    // Remove groupId from all members
    for (final memberId in members) {
      await _removeFromArray(
        AppwriteConstants.usersCollection,
        memberId,
        'groupIds',
        groupId,
      );
    }
  }

  // ── Helpers ──

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
