import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

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

  /// Downloads [url] into a temp file with the given [extension] and returns
  /// its path. Needed for voice notes: the Appwrite view endpoint replies with
  /// `Content-Type: text/plain` and no file extension, which makes AVPlayer
  /// reject both the URL and the cache-manager file (stored as `.txt`).
  static Future<String?> downloadWithExtension(
    String url,
    String extension,
  ) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/pointchat_media_'
        '${DateTime.now().microsecondsSinceEpoch}.$extension',
      );
      await response.pipe(file.openWrite());
      return file.path;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
