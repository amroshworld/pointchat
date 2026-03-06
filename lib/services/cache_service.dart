import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaCacheManager {
  static const key = 'pointchatMediaCache';

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30), // Keeps files for 30 days locally
      maxNrOfCacheObjects: 1000, // Maximum number of files to keep
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// Helper to get a file, leveraging the cache manager
  static Future<String> getLocalFilePath(String url) async {
    final fileInfo = await instance.downloadFile(url);
    return fileInfo.file.path;
  }
}
