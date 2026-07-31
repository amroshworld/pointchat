const { GoogleGenAI, ThinkingLevel } = require('@google/genai');

const MODEL_NAME = 'gemini-3.6-flash';
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
      error: 'AI service is temporarily unavailable.',
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
    // No googleSearch / grounding — paid tier charges ~$14/1k queries after free quota.
    const response = await ai.models.generateContentStream({
      model: MODEL_NAME,
      config: {
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.MINIMAL,
        },
        systemInstruction: systemPrompt,
        maxOutputTokens: 250,
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
    return res.json({
      success: false,
      error: 'AI service is temporarily unavailable.',
    });
  }
};
