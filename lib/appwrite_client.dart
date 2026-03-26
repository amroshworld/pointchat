import 'package:appwrite/appwrite.dart';

class AppwriteConstants {
  static const String projectId = '69a6d89d0007909f06f7';
  static const String endpoint = 'https://fra.cloud.appwrite.io/v1';

  // Database
  static const String databaseId = 'pointchat_db';

  // Table IDs (Tables DB)
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String groupsCollection = 'groups';
  static const String groupInvitesCollection = 'group_invites';
  static const String botsCollection = 'bots';

  // Storage
  static const String chatFilesBucket = 'chat_files';

  /// Used by [Account.createEmailVerification]. Must be an authorized URL in
  /// Appwrite Console → Auth → URLs. Replace with your deployed verify page or deep link.
  static const String emailVerificationRedirectUrl =
      'https://pointchat.app/verify';
}

/// Realtime paths for [TablesDB] rows. Legacy `collections.*.documents` channels
/// do not fire for table row updates.
class AppwriteRealtimeChannels {
  AppwriteRealtimeChannels._();

  static String tableRows(String tableId) =>
      'databases.${AppwriteConstants.databaseId}.collections.$tableId.documents';

  static String tableRow(String tableId, String rowId) =>
      'databases.${AppwriteConstants.databaseId}.collections.$tableId.documents.$rowId';
}

final Client appwriteClient = Client()
    .setEndpoint(AppwriteConstants.endpoint)
    .setProject(AppwriteConstants.projectId);

final Account appwriteAccount = Account(appwriteClient);
final TablesDB appwriteTablesDB = TablesDB(appwriteClient);
final Storage appwriteStorage = Storage(appwriteClient);
final Realtime appwriteRealtime = Realtime(appwriteClient);
final Functions appwriteFunctions = Functions(appwriteClient);

List<String> signedInReadPermissions() => [Permission.read(Role.users())];

List<String> publicReadPermissions() => [Permission.read(Role.any())];

String buildStorageFileUrl(String fileId, {String? bucketId}) {
  final resolvedBucketId = bucketId ?? AppwriteConstants.chatFilesBucket;
  return '${AppwriteConstants.endpoint}/storage/buckets/$resolvedBucketId/files/$fileId/view?project=${AppwriteConstants.projectId}';
}

String buildStoragePreviewUrl(
  String fileId, {
  String? bucketId,
  int width = 320,
  int height = 320,
  int quality = 90,
}) {
  final resolvedBucketId = bucketId ?? AppwriteConstants.chatFilesBucket;
  return '${AppwriteConstants.endpoint}/storage/buckets/$resolvedBucketId/files/$fileId/preview?project=${AppwriteConstants.projectId}&width=$width&height=$height&gravity=center&quality=$quality';
}

// Cached current user info (populated after login)
String cachedUserId = '';
String cachedUserName = '';
String cachedUserPhotoUrl = '';
String cachedUserEmail = '';
