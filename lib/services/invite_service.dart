import 'dart:async';

import 'package:appwrite/appwrite.dart';

import '../appwrite_client.dart';

class InviteService {
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;

  Future<void> createPendingInvites({
    required String groupId,
    required String invitedBy,
    required List<String> userIds,
  }) async {
    for (final userId in userIds.toSet()) {
      final rowId = await _findInviteRowId(groupId: groupId, userId: userId);
      if (rowId != null) {
        await _databases.updateRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupInvitesCollection,
          rowId: rowId,
          data: {'invitedBy': invitedBy, 'status': 'pending', 'actedAt': null},
        );
      } else {
        await _databases.createRow(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupInvitesCollection,
          rowId: ID.unique(),
          data: {
            'groupId': groupId,
            'userId': userId,
            'invitedBy': invitedBy,
            'status': 'pending',
          },
        );
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getPendingInvitesForUser(String userId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();

    Future<void> fetch() async {
      try {
        final rows = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.groupInvitesCollection,
          queries: [
            Query.equal('userId', userId),
            Query.equal('status', 'pending'),
            Query.limit(500),
          ],
        );

        if (!controller.isClosed) {
          controller.add(
            rows.rows
                .map((row) => {'rowId': row.$id, ...row.data})
                .toList(growable: false),
          );
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.groupInvitesCollection}.documents',
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  Future<void> approveInvite({
    required String groupId,
    required String userId,
  }) async {
    await _setInviteStatus(
      groupId: groupId,
      userId: userId,
      status: 'approved',
    );
  }

  Future<void> exitInvite({
    required String groupId,
    required String userId,
  }) async {
    await _setInviteStatus(groupId: groupId, userId: userId, status: 'exited');
  }

  Future<void> _setInviteStatus({
    required String groupId,
    required String userId,
    required String status,
  }) async {
    final rowId = await _findInviteRowId(groupId: groupId, userId: userId);
    if (rowId == null) {
      return;
    }

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupInvitesCollection,
      rowId: rowId,
      data: {
        'status': status,
        'actedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<String?> _findInviteRowId({
    required String groupId,
    required String userId,
  }) async {
    final rows = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.groupInvitesCollection,
      queries: [
        Query.equal('groupId', groupId),
        Query.equal('userId', userId),
        Query.limit(1),
      ],
    );

    if (rows.rows.isEmpty) {
      return null;
    }

    return rows.rows.first.$id;
  }
}
