import 'dart:async';
import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';
import '../models/user_model.dart';

class UserService {
  final TablesDB _databases = appwriteTablesDB;
  final Realtime _realtime = appwriteRealtime;

  // Get user by ID
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _databases.getRow(
        databaseId: AppwriteConstants.databaseId,
        tableId: AppwriteConstants.usersCollection,
        rowId: uid,
      );
      return UserModel.fromMap(doc.data);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow; // keep throwing so callers can handle it
    }
  }

  // Get user stream (realtime updates)
  Stream<UserModel?> getUserStream(String uid) {
    final controller = StreamController<UserModel?>.broadcast();

    getUserById(uid)
        .then((user) {
          if (!controller.isClosed) controller.add(user);
        })
        .catchError((e) {
          if (!controller.isClosed) controller.addError(e);
        });

    final sub = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.usersCollection}.documents.$uid',
    ]);

    sub.stream.listen((event) {
      if (event.payload.isNotEmpty) {
        controller.add(UserModel.fromMap(event.payload));
      }
    });

    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Search users by name or email
  Future<List<UserModel>> searchUsers(
    String query,
    String currentUserId,
  ) async {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();

    // Fetch all users and filter locally for substring search
    final result = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      queries: [Query.limit(500)],
    );

    return result.rows
        .where((doc) => doc.$id != currentUserId)
        .map((doc) => UserModel.fromMap(doc.data))
        .where(
          (user) =>
              user.displayName.toLowerCase().contains(queryLower) ||
              user.email.toLowerCase().contains(queryLower),
        )
        .toList();
  }

  // Get all users (for creating groups and chat lists)
  Stream<List<UserModel>> getAllUsers(String currentUserId) {
    final controller = StreamController<List<UserModel>>.broadcast();

    Future<void> fetch() async {
      try {
        final result = await _databases.listRows(
          databaseId: AppwriteConstants.databaseId,
          tableId: AppwriteConstants.usersCollection,
          queries: [Query.limit(500)],
        );
        if (!controller.isClosed) {
          controller.add(
            result.rows
                .where((doc) => doc.$id != currentUserId)
                .map((doc) => UserModel.fromMap(doc.data))
                .toList(),
          );
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetch();

    final sub = _realtime.subscribe([
      'databases.${AppwriteConstants.databaseId}.collections.${AppwriteConstants.usersCollection}.documents',
    ]);
    sub.stream.listen((_) => fetch());
    controller.onCancel = () => sub.close();

    return controller.stream;
  }

  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      rowId: uid,
      data: data,
    );
  }

  // Update user status message
  Future<void> updateStatus(String uid, String status) async {
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      rowId: uid,
      data: {'status': status},
    );
  }

  // Toggle favorite user/group
  Future<void> toggleFavorite(
    String uid,
    String favoriteId,
    bool isAdding,
  ) async {
    final doc = await _databases.getRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      rowId: uid,
    );

    final favorites = List<String>.from(doc.data['favorites'] ?? []);
    if (isAdding) {
      if (!favorites.contains(favoriteId)) favorites.add(favoriteId);
    } else {
      favorites.remove(favoriteId);
    }

    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      rowId: uid,
      data: {'favorites': favorites},
    );
  }
}
