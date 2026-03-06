const sdk = require('node-appwrite');

/*
  Appwrite Cloud Function: Delete Old Media
  This function queries your messages collection for messages older than a specified amount of days.
  If the message contains an image, file, or audio, it will:
    1. Delete the actual file from your Appwrite Storage bucket to save cloud space.
    2. Update the message document to reflect that the media has expired.
*/

module.exports = async function ({ req, res, log, error }) {
  log("HEADERS:", JSON.stringify(req.headers));

  const client = new sdk.Client();
  const storage = new sdk.Storage(client);
  const databases = new sdk.Databases(client);

  // Setup Client using Environment Variables
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const apiKey = req.headers['x-appwrite-key'] || process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  
  if (!endpoint || !apiKey) {
    error("Environment variables are not set. API_KEY present: " + !!apiKey + " ENDPOINT present: " + !!endpoint);
    return res.json({ success: false, message: "Missing environment variables" });
  }

  client
    .setEndpoint(endpoint)
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID)
    .setKey(apiKey);

  // Add these as Environment Variables in the Appwrite Console
  const DATABASE_ID = process.env.DATABASE_ID;
  const MESSAGES_COLLECTION_ID =
    process.env.MESSAGES_TABLE_ID || process.env.MESSAGES_COLLECTION_ID;
  const BUCKET_ID = process.env.BUCKET_ID;
  const DAYS_TO_KEEP = parseInt(process.env.DAYS_TO_KEEP || '14', 10);

  if (!DATABASE_ID || !MESSAGES_COLLECTION_ID || !BUCKET_ID) {
    return res.json({
      success: false,
      message:
        'Missing DATABASE_ID, MESSAGES_TABLE_ID (or MESSAGES_COLLECTION_ID), or BUCKET_ID variables.',
    });
  }

  // Calculate the cutoff date (e.g., 14 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - DAYS_TO_KEEP);
  const dateString = cutoffDate.toISOString();

  log(`Starting media cleanup. Deleting media older than ${dateString}`);

  try {
    let hasMore = true;
    let queries = [sdk.Query.lessThan('$createdAt', dateString), sdk.Query.limit(100)];

    let deletedCount = 0;
    let updatedDocsCount = 0;

    while (hasMore) {
      const messages = await databases.listDocuments(DATABASE_ID, MESSAGES_COLLECTION_ID, queries);

      if (messages.documents.length === 0) {
        hasMore = false;
        break;
      }

      for (const msg of messages.documents) {
        // If message has file, audio, or image, delete from storage
        if (msg.type === 'file' || msg.type === 'audio' || msg.type === 'image') {
          // We extract the fileId from the Appwrite file URL stored in message text.
          const match = typeof msg.text === 'string' ? msg.text.match(/\/files\/([^\/]+)\//) : null;
          if (match && match[1]) {
            const fileId = match[1];
            try {
              await storage.deleteFile(BUCKET_ID, fileId);
              log(`Deleted file: ${fileId}`);
              deletedCount++;
            } catch (err) {
              // Ignore not found errors so old or manually deleted files do not fail the run.
              if (err.code !== 404) {
                error(`Failed to delete file ${fileId}: ${err.message}`);
              }
            }
          }

          // Update document to avoid repeated storage delete attempts on next schedule run.
          await databases.updateDocument(DATABASE_ID, MESSAGES_COLLECTION_ID, msg.$id, {
            text: 'This media has expired and was removed from cloud storage.',
            type: 'system',
            fileName: null,
            fileSize: null,
            audioDuration: null,
            latitude: null,
            longitude: null,
          });
          updatedDocsCount++;
        }
      }

      const lastId = messages.documents[messages.documents.length - 1].$id;
      queries = [
        sdk.Query.lessThan('$createdAt', dateString),
        sdk.Query.cursorAfter(lastId),
        sdk.Query.limit(100),
      ];
    }
    log(`Cleanup complete. Deleted ${deletedCount} files. Updated ${updatedDocsCount} documents.`);
    return res.json({
      success: true,
      deletedFiles: deletedCount,
      updatedDocuments: updatedDocsCount,
    });
  } catch (err) {
    error(`Error during cleanup: ${err.message}`);
    return res.json({ success: false, error: err.message });
  }
};
