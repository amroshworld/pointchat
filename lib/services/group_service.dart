import 'dart:async';
import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import 'invite_service.dart';

class GroupService {
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;
  final InviteService _inviteService = InviteService();

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

    final invitees =
        members.where((id) => id != createdBy).toList(growable: false);
    final memberList = [createdBy];
    final unreadInit = {createdBy: 0};

    final group = GroupModel(
      groupId: groupId,
      name: name,
      description: description,
      photoUrl: photoUrl,
      createdBy: createdBy,
      members: memberList,
      pendingMemberIds: invitees,
      admins: [createdBy],
      isPublic: isPublic,
      unreadCount: unreadInit,
    );

    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: group.toMap(),
    );

    await _addToArray(
      AppwriteConstants.usersCollection,
      createdBy,
      'groupIds',
      groupId,
    );

    if (invitees.isNotEmpty) {
      await _inviteService.createPendingInvites(
        groupId: groupId,
        invitedBy: createdBy,
        userIds: invitees,
      );
    }

    await sendGroupMessage(
      groupId: groupId,
      senderId: createdBy,
      senderName: 'System',
      text: invitees.isEmpty
          ? 'Group "$name" created'
          : 'Group "$name" created — ${invitees.length} invite(s) pending',
      type: MessageType.system,
    );

    return groupId;
  }

  // Get user's groups stream
  Stream<List<GroupModel>> getUserGroups(String userId) {
    final controller = StreamController<List<GroupModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final memberRows = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupsCollection,
          queries: [
            Query.contains('members', userId),
            Query.orderDesc('lastMessageTime'),
            Query.limit(100),
          ],
        );
        final pendingRows = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupsCollection,
          queries: [
            Query.contains('pendingMemberIds', userId),
            Query.orderDesc('lastMessageTime'),
            Query.limit(100),
          ],
        );

        final byId = <String, GroupModel>{};
        for (final doc in memberRows.rows) {
          byId[doc.$id] = GroupModel.fromMap(doc.data, doc.$id);
        }
        for (final doc in pendingRows.rows) {
          byId[doc.$id] = GroupModel.fromMap(doc.data, doc.$id);
        }

        final merged = byId.values.toList()
          ..sort((a, b) {
            final ta =
                a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            final tb =
                b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
            return tb.compareTo(ta);
          });

        if (!controller.isClosed) {
          controller.add(merged);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.groupsCollection),
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  /// Adds [userId] from [pendingMemberIds] into [members] and links [groupIds] on the user.
  Future<void> approvePendingMembership(String groupId, String userId) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final members = List<String>.from(doc.data['members'] ?? []);
    final pending = List<String>.from(doc.data['pendingMemberIds'] ?? []);
    if (!pending.contains(userId)) return;

    pending.remove(userId);
    if (!members.contains(userId)) members.add(userId);

    final unread = Map<String, int>.from(
      GroupModel.decodeUnreadCount(doc.data['unreadCount']),
    );
    unread[userId] = 0;

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'members': members,
        'pendingMemberIds': pending,
        'unreadCount': jsonEncode(unread),
      },
    );

    await _addToArray(
      AppwriteConstants.usersCollection,
      userId,
      'groupIds',
      groupId,
    );
  }

  /// Removes an invitee who declined (not a full member yet).
  Future<void> declinePendingMembership(String groupId, String userId) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final pending = List<String>.from(doc.data['pendingMemberIds'] ?? []);
    if (!pending.contains(userId)) return;

    pending.remove(userId);
    final unread = Map<String, int>.from(
      GroupModel.decodeUnreadCount(doc.data['unreadCount']),
    );
    unread.remove(userId);

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'pendingMemberIds': pending,
        'unreadCount': jsonEncode(unread),
      },
    );
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
      AppwriteRealtimeChannels.tableRow(
        AppwriteConstants.groupsCollection,
        groupId,
      ),
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
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.groupsCollection),
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
      AppwriteRealtimeChannels.tableRows(AppwriteConstants.messagesCollection),
    ]);
    sub.stream.listen((event) {
      final payload = event.payload;
      final gid = payload['groupId'];
      if (gid == groupId || event.events.any((e) => e.contains('.delete'))) {
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
    String? skipUnreadIncrementFor,
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

    final unreadExtra = await _incrementGroupUnreadPayload(
      groupId,
      senderId,
      skipIncrementForUserId: skipUnreadIncrementFor,
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
        ...unreadExtra,
      },
    );
  }

  /// Returns map with `unreadCount` key for merging into a group [updateRow].
  Future<Map<String, dynamic>> _incrementGroupUnreadPayload(
    String groupId,
    String senderId, {
    String? skipIncrementForUserId,
  }) async {
    try {
      final doc = await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.groupsCollection,
        rowId: groupId,
      );
      final members = List<String>.from(doc.data['members'] ?? []);
      final unread = Map<String, int>.from(
        GroupModel.decodeUnreadCount(doc.data['unreadCount']),
      );
      for (final m in members) {
        if (m == senderId) continue;
        if (skipIncrementForUserId != null && m == skipIncrementForUserId) {
          continue;
        }
        unread[m] = (unread[m] ?? 0) + 1;
      }
      return {'unreadCount': jsonEncode(unread)};
    } catch (_) {
      return {};
    }
  }

  /// Clears unread count for [userId] when they open the group chat.
  Future<void> markGroupAsRead(String groupId, String userId) async {
    try {
      final doc = await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.groupsCollection,
        rowId: groupId,
      );
      final unread = Map<String, int>.from(
        GroupModel.decodeUnreadCount(doc.data['unreadCount']),
      );
      if ((unread[userId] ?? 0) == 0) return;
      unread[userId] = 0;
      await _databases.updateRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.groupsCollection,
        rowId: groupId,
        data: {'unreadCount': jsonEncode(unread)},
      );
    } catch (_) {}
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

  // Add members to group (invited as pending until they approve)
  Future<void> addMembers(
    String groupId,
    List<String> newMembers,
    String addedByName, {
    String? actorUserId,
  }) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    final members = List<String>.from(doc.data['members'] ?? []);
    final pending = List<String>.from(doc.data['pendingMemberIds'] ?? []);
    final toInvite = <String>[];

    for (final m in newMembers) {
      if (members.contains(m) || pending.contains(m)) continue;
      pending.add(m);
      toInvite.add(m);
    }

    if (toInvite.isEmpty) return;

    final unread = Map<String, int>.from(
      GroupModel.decodeUnreadCount(doc.data['unreadCount']),
    );
    for (final m in toInvite) {
      unread.putIfAbsent(m, () => 0);
    }

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'pendingMemberIds': pending,
        'unreadCount': jsonEncode(unread),
      },
    );

    final inviter = actorUserId != null && actorUserId.isNotEmpty
        ? actorUserId
        : doc.data['createdBy']?.toString() ?? '';
    if (inviter.isNotEmpty) {
      await _inviteService.createPendingInvites(
        groupId: groupId,
        invitedBy: inviter,
        userIds: toInvite,
      );
    }

    await sendGroupMessage(
      groupId: groupId,
      senderId: 'system',
      senderName: 'System',
      text: '$addedByName invited ${toInvite.length} member(s)',
      type: MessageType.system,
      skipUnreadIncrementFor: actorUserId,
    );
  }

  // Remove member from group (admin action)
  Future<void> removeMember(
    String groupId,
    String memberId, {
    String? removedByName,
    String? skipUnreadIncrementForActor,
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

    final unread = Map<String, int>.from(
      GroupModel.decodeUnreadCount(doc.data['unreadCount']),
    );
    unread.remove(memberId);

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'members': members,
        'admins': admins,
        'unreadCount': jsonEncode(unread),
      },
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
        skipUnreadIncrementFor: skipUnreadIncrementForActor,
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

    final unread = Map<String, int>.from(
      GroupModel.decodeUnreadCount(doc.data['unreadCount']),
    );
    unread.putIfAbsent(userId, () => 0);

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
      data: {
        'members': members,
        'unreadCount': jsonEncode(unread),
      },
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
      skipUnreadIncrementFor: userId,
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

  /// Deletes the group, its messages (batched), invite rows, and clears [groupIds] on every
  /// affected user (members + pending invitees).
  Future<void> deleteGroup(String groupId) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );
    final members = List<String>.from(doc.data['members'] ?? []);
    final pending = List<String>.from(doc.data['pendingMemberIds'] ?? []);
    final affected = <String>{...members, ...pending};

    final invites = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupInvitesCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.limit(500),
      ],
    );
    await Future.wait(
      invites.rows.map((row) => _databases.deleteRow(
            databaseId: AppwriteConstants.databaseId,
            tableId: AppwriteConstants.groupInvitesCollection,
            rowId: row.$id,
          )),
    );

    while (true) {
      final batch = await _databases.listRows(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.messagesCollection,
        queries: [
          Query.equal('groupId', groupId),
          Query.limit(100),
        ],
      );
      if (batch.rows.isEmpty) break;
      await Future.wait(
        batch.rows.map((m) => _databases.deleteRow(
              databaseId: AppwriteConstants.databaseId,
              tableId: AppwriteConstants.messagesCollection,
              rowId: m.$id,
            )),
      );
    }

    await _databases.deleteRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupsCollection,
      rowId: groupId,
    );

    await Future.wait(
      affected.map((uid) => _removeFromArray(
            AppwriteConstants.usersCollection,
            uid,
            'groupIds',
            groupId,
          )),
    );
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
