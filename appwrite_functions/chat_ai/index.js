const sdk = require('node-appwrite');
const { generateText } = require('ai');

module.exports = async function ({ req, res, log, error }) {
  // Setup Client using Environment Variables
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const apiKey = req.headers['x-appwrite-key'] || process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const vercelAiToken = process.env.VERCEL_AI_SDK_TOKEN;
  
  if (!endpoint || !apiKey || !vercelAiToken) {
    error("Environment variables are not set. API_KEY present: " + !!apiKey + " ENDPOINT present: " + !!endpoint + " VERCEL_TOKEN: " + !!vercelAiToken);
    return res.json({ success: false, message: "Missing environment variables" });
  }

  // Set the AI Gateway key for the ai SDK to use
  process.env.AI_GATEWAY_API_KEY = vercelAiToken;

  try {
    let promptText = "Hello!";
    if (req.body) {
       try {
           const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
           promptText = body.prompt || promptText;
       } catch (e) {
           log("Body parse error: " + e);
       }
    }

    log(`Generating response for prompt: ${promptText}`);

    const result = await generateText({
      model: 'google/gemini-2.5-flash-lite',
      system: req.body.systemPrompt || 'You are a helpful AI assistant.',
      prompt: promptText,
    });

    log(`Generated response length: ${result.text.length}`);
    return res.json({ success: true, text: result.text });
  } catch (err) {
    error(`Error generating text: ${err.message}`);
    return res.json({ success: false, error: err.message });
  }
};