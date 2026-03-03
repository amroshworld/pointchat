import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Search users by name or email
  Future<List<UserModel>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();

    // Fetch all users once and filter locally for robust substring & case-insensitive search
    final snapshot = await _firestore.collection('users').get();

    final List<UserModel> results = [];

    for (final doc in snapshot.docs) {
      if (doc.id == currentUserId) continue; // Skip current user

      final user = UserModel.fromMap(doc.data());
      if (user.displayName.toLowerCase().contains(queryLower) ||
          user.email.toLowerCase().contains(queryLower)) {
        results.add(user);
      }
    }

    return results;
  }

  // Get all users (for creating groups and chat lists)
  Stream<List<UserModel>> getAllUsers(String currentUserId) {
    return _firestore.collection('users').snapshots().map((snapshot) {
      return snapshot.docs
          .where(
            (doc) => doc.id != currentUserId,
          ) // Filter out current user locally to avoid query limits/index constraints
          .map((doc) => UserModel.fromMap(doc.data()))
          .toList();
    });
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Update user status message
  Future<void> updateStatus(String uid, String status) async {
    await _firestore.collection('users').doc(uid).update({'status': status});
  }

  // Toggle favorite user/group
  Future<void> toggleFavorite(String uid, String favoriteId, bool isAdding) async {
    await _firestore.collection('users').doc(uid).update({
      'favorites': isAdding 
        ? FieldValue.arrayUnion([favoriteId])
        : FieldValue.arrayRemove([favoriteId])
    });
  }
}
