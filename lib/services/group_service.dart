import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new group
  Future<String> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required List<String> members,
    String photoUrl = '',
    bool isPublic = false,
  }) async {
    final groupDoc = _firestore.collection('groups').doc();

    // Include creator in members and admins
    final allMembers = {...members, createdBy}.toList();

    final group = GroupModel(
      groupId: groupDoc.id,
      name: name,
      description: description,
      photoUrl: photoUrl,
      createdBy: createdBy,
      members: allMembers,
      admins: [createdBy],
      isPublic: isPublic,
    );

    await groupDoc.set(group.toMap());

    // Update all members' groupIds
    final batch = _firestore.batch();
    for (final memberId in allMembers) {
      batch.update(_firestore.collection('users').doc(memberId), {
        'groupIds': FieldValue.arrayUnion([groupDoc.id]),
      });
    }
    await batch.commit();

    // Send system message
    await sendGroupMessage(
      groupId: groupDoc.id,
      senderId: createdBy,
      senderName: 'System',
      text: 'Group "$name" created',
      type: MessageType.system,
    );

    return groupDoc.id;
  }

  // Get user's groups stream
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Get group by ID
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _firestore.collection('groups').doc(groupId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return GroupModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Get popular / public groups stream (ordered by member count desc)
  Stream<List<GroupModel>> getPopularGroups() {
    return _firestore
        .collection('groups')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
              .toList();
          // Sort by member count descending
          groups.sort((a, b) => b.memberCount.compareTo(a.memberCount));
          return groups;
        });
  }

  // Get messages stream for a group
  Stream<List<MessageModel>> getGroupMessages(String groupId) {
    return _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
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
    final messageDoc = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .doc();

    final message = MessageModel(
      messageId: messageDoc.id,
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

    final batch = _firestore.batch();
    batch.set(messageDoc, message.toMap());
    batch.update(_firestore.collection('groups').doc(groupId), {
      'lastMessage': message.preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'lastMessageSenderName': senderName,
    });
    await batch.commit();
  }

  // Add members to group
  Future<void> addMembers(
    String groupId,
    List<String> newMembers,
    String addedByName,
  ) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('groups').doc(groupId), {
      'members': FieldValue.arrayUnion(newMembers),
    });

    for (final memberId in newMembers) {
      batch.update(_firestore.collection('users').doc(memberId), {
        'groupIds': FieldValue.arrayUnion([groupId]),
      });
    }

    await batch.commit();

    // Send system message about added members
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
    final batch = _firestore.batch();

    batch.update(_firestore.collection('groups').doc(groupId), {
      'members': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([memberId]),
    });

    batch.update(_firestore.collection('users').doc(memberId), {
      'groupIds': FieldValue.arrayRemove([groupId]),
    });

    await batch.commit();

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
    final batch = _firestore.batch();

    batch.update(_firestore.collection('groups').doc(groupId), {
      'members': FieldValue.arrayUnion([userId]),
    });

    batch.update(_firestore.collection('users').doc(userId), {
      'groupIds': FieldValue.arrayUnion([groupId]),
    });

    await batch.commit();

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
    await _firestore.collection('groups').doc(groupId).update({
      'isPublic': isPublic,
    });
  }

  // Make admin
  Future<void> makeAdmin(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayUnion([userId]),
    });
  }

  // Remove admin
  Future<void> removeAdmin(String groupId, String userId) async {
    await _firestore.collection('groups').doc(groupId).update({
      'admins': FieldValue.arrayRemove([userId]),
    });
  }

  // Update group info
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    await _firestore.collection('groups').doc(groupId).update(data);
  }

  // Delete group
  Future<void> deleteGroup(String groupId, List<String> members) async {
    // Delete all messages
    final messages = await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete group
    batch.delete(_firestore.collection('groups').doc(groupId));

    // Remove groupId from all members
    for (final memberId in members) {
      batch.update(_firestore.collection('users').doc(memberId), {
        'groupIds': FieldValue.arrayRemove([groupId]),
      });
    }

    await batch.commit();
  }
}
