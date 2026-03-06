const sdk = require('node-appwrite');
const { generateText } = require('ai');
const { createOpenAI } = require('@ai-sdk/openai');

module.exports = async function ({ req, res, log, error }) {
  // Setup Client using Environment Variables
  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const apiKey = req.headers['x-appwrite-key'] || process.env.APPWRITE_FUNCTION_API_KEY || process.env.APPWRITE_API_KEY;
  const vercelAiToken = process.env.VERCEL_AI_SDK_TOKEN;
  
  if (!endpoint || !apiKey || !vercelAiToken) {
    error("Environment variables are not set. API_KEY present: " + !!apiKey + " ENDPOINT present: " + !!endpoint + " VERCEL_TOKEN: " + !!vercelAiToken);
    return res.json({ success: false, message: "Missing environment variables" });
  }

  // Set up OpenAI instance routing through Vercel AI Gateway
  const openai = createOpenAI({
    baseURL: 'https://gateway.ai.vercel.com/v1',
    apiKey: 'dummy-api-key-for-vercel-proxy', // Requires a key even if we proxy
    headers: {
      'Authorization': `Bearer ${vercelAiToken}`,
    },
  });

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
      model: openai('openai/gpt-5.2'),
      prompt: promptText,
    });

    log(`Generated response length: ${result.text.length}`);
    return res.json({ success: true, text: result.text });
  } catch (err) {
    error(`Error generating text: ${err.message}`);
    return res.json({ success: false, error: err.message });
  }
};