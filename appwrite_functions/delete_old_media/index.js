const sdk = require('node-appwrite');

/*
  Appwrite Cloud Function: Delete Old Media
  This function queries your messages collection for messages older than a specified amount of days.
  If the message contains an image, file, or audio, it will:
    1. Delete the actual file from your Appwrite Storage bucket to save cloud space.
    2. Update the message document to reflect that the media has expired.
*/

module.exports = async function (context) {
  const client = new sdk.Client();
  const storage = new sdk.Storage(client);
  const tablesDB = new sdk.TablesDB(client);

  // Setup Client using Environment Variables
  if (
    !context.req.variables['APPWRITE_FUNCTION_ENDPOINT'] ||
    !context.req.variables['APPWRITE_FUNCTION_API_KEY']
  ) {
    context.error("Environment variables are not set.");
    return context.res.json({ success: false, message: "Missing environment variables" });
  }

  client
    .setEndpoint(context.req.variables['APPWRITE_FUNCTION_ENDPOINT'])
    .setProject(context.req.variables['APPWRITE_FUNCTION_PROJECT_ID'])
    .setKey(context.req.variables['APPWRITE_FUNCTION_API_KEY']);

  // Add these as Environment Variables in the Appwrite Console
  const DATABASE_ID = context.req.variables['DATABASE_ID'];
  const MESSAGES_TABLE_ID =
    context.req.variables['MESSAGES_TABLE_ID'] ||
    context.req.variables['MESSAGES_COLLECTION_ID'];
  const BUCKET_ID = context.req.variables['BUCKET_ID'];
  const DAYS_TO_KEEP = parseInt(
    context.req.variables['DAYS_TO_KEEP'] || '14',
    10,
  );

  if (!DATABASE_ID || !MESSAGES_TABLE_ID || !BUCKET_ID) {
    return context.res.json({
      success: false,
      message:
        'Missing DATABASE_ID, MESSAGES_TABLE_ID (or MESSAGES_COLLECTION_ID), or BUCKET_ID variables.',
    });
  }

  // Calculate the cutoff date (e.g., 14 days ago)
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - DAYS_TO_KEEP);
  const dateString = cutoffDate.toISOString();

  context.log(`Starting media cleanup. Deleting media older than ${dateString}`);

  try {
    let hasMore = true;
    let queries = [sdk.Query.lessThan('$createdAt', dateString), sdk.Query.limit(100)];

    let deletedCount = 0;
    let updatedRowsCount = 0;

    while (hasMore) {
      const messages = await tablesDB.listRows(DATABASE_ID, MESSAGES_TABLE_ID, queries);

      if (messages.rows.length === 0) {
        hasMore = false;
        break;
      }

      for (const msg of messages.rows) {
        // If message has file, audio, or image, delete from storage
        if (msg.type === 'file' || msg.type === 'audio' || msg.type === 'image') {
          // We extract the fileId from the Appwrite file URL stored in message text.
          const match = typeof msg.text === 'string' ? msg.text.match(/\/files\/([^\/]+)\//) : null;
          if (match && match[1]) {
            const fileId = match[1];
            try {
              await storage.deleteFile(BUCKET_ID, fileId);
              context.log(`Deleted file: ${fileId}`);
              deletedCount++;
            } catch (err) {
              // Ignore not found errors so old or manually deleted files do not fail the run.
              if (err.code !== 404) {
                context.error(`Failed to delete file ${fileId}: ${err.message}`);
              }
            }
          }

          // Update row to avoid repeated storage delete attempts on next schedule run.
          await tablesDB.updateRow(DATABASE_ID, MESSAGES_TABLE_ID, msg.$id, {
            text: 'This media has expired and was removed from cloud storage.',
            type: 'system',
            fileName: null,
            fileSize: null,
            audioDuration: null,
            latitude: null,
            longitude: null,
          });
          updatedRowsCount++;
        }
      }

      const lastId = messages.rows[messages.rows.length - 1].$id;
      queries = [
        sdk.Query.lessThan('$createdAt', dateString),
        sdk.Query.cursorAfter(lastId),
        sdk.Query.limit(100),
      ];
    }
    context.log(`Cleanup complete. Deleted ${deletedCount} files. Updated ${updatedRowsCount} rows.`);
    return context.res.json({
      success: true,
      deletedFiles: deletedCount,
      updatedRows: updatedRowsCount,
    });
  } catch (error) {
    context.error(`Error during cleanup: ${error.message}`);
    return context.res.json({ success: false, error: error.message });
  }
};