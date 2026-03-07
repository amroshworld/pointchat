const { GoogleGenAI, ThinkingLevel } = require('@google/genai');

const MODEL_NAME = 'gemini-3.1-flash-lite-preview';
const DEFAULT_SYSTEM_PROMPT = 'You are a helpful AI assistant for PointChat.';

function parseBody(req, log) {
  if (!req.body) {
    return {};
  }

  try {
    return typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
  } catch (error) {
    log(`Body parse error: ${error.message}`);
    return {};
  }
}

module.exports = async function ({ req, res, log }) {
  const apiKey = process.env.GEMINI_API_KEY;

  if (!apiKey) {
    log('Missing GEMINI_API_KEY function variable');
    return res.json({
      success: false,
      error: 'Missing GEMINI_API_KEY function variable.',
    });
  }

  try {
    const body = parseBody(req, log);
    const promptText = String(body.prompt || '').trim();
    const systemPrompt = String(
      body.systemPrompt || DEFAULT_SYSTEM_PROMPT,
    ).trim();

    if (!promptText) {
      return res.json({ success: false, error: 'Prompt is required.' });
    }

    log(`Generating response with locked model ${MODEL_NAME}`);

    const ai = new GoogleGenAI({ apiKey });
    const response = await ai.models.generateContentStream({
      model: MODEL_NAME,
      config: {
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.MINIMAL,
        },
        tools: [{ googleSearch: {} }],
        systemInstruction: systemPrompt,
      },
      contents: [
        {
          role: 'user',
          parts: [{ text: promptText }],
        },
      ],
    });

    let text = '';
    for await (const chunk of response) {
      text += chunk.text || '';
    }

    log(`Generated ${text.length} characters successfully`);
    return res.json({ success: true, text: text.trim() });
  } catch (error) {
    log(`Error generating text: ${error.message}`);
    return res.json({ success: false, error: error.message });
  }
};
