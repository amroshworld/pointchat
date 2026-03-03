import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get or create a chat between two users
  Future<String> getOrCreateChat(
    String currentUserId,
    String otherUserId,
  ) async {
    // Check if chat already exists
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (final doc in existingChats.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId) && participants.length == 2) {
        return doc.id;
      }
    }

    // Create new chat with default seen settings (both users have seen enabled)
    final chatDoc = _firestore.collection('chats').doc();
    final chat = ChatModel(
      chatId: chatDoc.id,
      participants: [currentUserId, otherUserId],
      seenEnabled: {currentUserId: true, otherUserId: true},
      notifyOnSeen: {currentUserId: false, otherUserId: false},
    );
    await chatDoc.set(chat.toMap());

    // Update both users' chatIds
    await _firestore.collection('users').doc(currentUserId).update({
      'chatIds': FieldValue.arrayUnion([chatDoc.id]),
    });
    await _firestore.collection('users').doc(otherUserId).update({
      'chatIds': FieldValue.arrayUnion([chatDoc.id]),
    });

    return chatDoc.id;
  }

  // Get user's chats stream
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Get a single chat stream
  Stream<ChatModel?> getChatStream(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return ChatModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  // Get messages stream for a chat
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
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
    final messageDoc = _firestore
        .collection('chats')
        .doc(chatId)
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

    // Write message and update chat's last message in a batch
    final batch = _firestore.batch();
    batch.set(messageDoc, message.toMap());
    batch.update(_firestore.collection('chats').doc(chatId), {
      'lastMessage': message.preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
    });
    await batch.commit();
  }

  // Mark messages as read AND update seen status
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    final unreadMessages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true, 'readBy.$userId': true});
    }

    // Reset unread count
    batch.update(_firestore.collection('chats').doc(chatId), {
      'unreadCount.$userId': 0,
    });

    await batch.commit();
  }

  // ── Seen Status Management ──

  /// Toggle seen status for current user in a chat
  Future<void> toggleSeenEnabled(
    String chatId,
    String userId,
    bool enabled,
  ) async {
    await _firestore.collection('chats').doc(chatId).update({
      'seenEnabled.$userId': enabled,
    });
  }

  /// Request seen access from another user
  /// Amr wants to see Sara's read receipts → sends request to Sara
  Future<void> requestSeenAccess({
    required String chatId,
    required String requesterId,
    required String targetId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'seenRequests': FieldValue.arrayUnion([
        {'from': requesterId, 'to': targetId},
      ]),
    });
  }

  /// Approve a seen request
  Future<void> approveSeenRequest({
    required String chatId,
    required String approverId,
    required String requesterId,
  }) async {
    final batch = _firestore.batch();
    final chatRef = _firestore.collection('chats').doc(chatId);

    // Remove the request
    batch.update(chatRef, {
      'seenRequests': FieldValue.arrayRemove([
        {'from': requesterId, 'to': approverId},
      ]),
    });

    // Enable seen for the approver (so requester can see their read receipts)
    batch.update(chatRef, {'seenEnabled.$approverId': true});

    await batch.commit();
  }

  /// Deny / cancel a seen request
  Future<void> denySeenRequest({
    required String chatId,
    required String requesterId,
    required String targetId,
  }) async {
    await _firestore.collection('chats').doc(chatId).update({
      'seenRequests': FieldValue.arrayRemove([
        {'from': requesterId, 'to': targetId},
      ]),
    });
  }

  /// Toggle "notify on seen" — get notified when your message is read
  Future<void> toggleNotifyOnSeen(
    String chatId,
    String userId,
    bool enabled,
  ) async {
    await _firestore.collection('chats').doc(chatId).update({
      'notifyOnSeen.$userId': enabled,
    });
  }

  // Delete a chat
  Future<void> deleteChat(String chatId, List<String> participants) async {
    // Delete all messages
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    // Delete chat document
    batch.delete(_firestore.collection('chats').doc(chatId));

    // Remove chatId from users
    for (final userId in participants) {
      batch.update(_firestore.collection('users').doc(userId), {
        'chatIds': FieldValue.arrayRemove([chatId]),
      });
    }

    await batch.commit();
  }
}
