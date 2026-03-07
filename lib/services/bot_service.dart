import 'package:appwrite/appwrite.dart';
import '../appwrite_client.dart';
import '../models/bot_model.dart';
import '../models/user_model.dart';

class BotService {
  final TablesDB _databases = appwriteTablesDB;

  Future<BotModel> createBot({
    required String name,
    required String ownerId,
    required String instructions,
  }) async {
    final botId = ID.unique();
    final bot = BotModel(
      botId: botId,
      name: name,
      ownerId: ownerId,
      instructions: instructions,
    );

    // 1. Create Bot document
    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.botsCollection,
      rowId: botId,
      data: bot.toMap(),
    );

    // 2. Create User document for the bot
    final botUser = UserModel(
      uid: botId,
      displayName: name,
      email: 'bot-$botId@pointchat.ai', // Dummy email
      isBot: true,
      status: 'Custom AI Bot',
    );

    await _databases.createRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.usersCollection,
      rowId: botId,
      data: botUser.toMap(),
    );

    return bot;
  }

  Future<void> updateBot(String botId, Map<String, dynamic> data) async {
    await _databases.updateRow(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.botsCollection,
      rowId: botId,
      data: data,
    );
  }

  Future<List<BotModel>> getMyBots(String ownerId) async {
    final result = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.botsCollection,
      queries: [Query.equal('ownerId', ownerId), Query.limit(100)],
    );
    return result.rows
        .map((doc) => BotModel.fromMap(doc.data, doc.$id))
        .toList();
  }

  Future<BotModel?> getBotByName(String name) async {
    final result = await _databases.listRows(
      databaseId: AppwriteConstants.databaseId,
      tableId: AppwriteConstants.botsCollection,
      queries: [Query.equal('name', name), Query.limit(1)],
    );
    if (result.rows.isNotEmpty) {
      return BotModel.fromMap(result.rows.first.data, result.rows.first.$id);
    }
    return null;
  }
}
