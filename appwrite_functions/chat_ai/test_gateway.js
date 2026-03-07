const { generateText } = require('ai');

async function testVercelGateway() {
  process.env.AI_GATEWAY_API_KEY = 'vck_5gLfkzF36z3N2U0qn2jVSU1fHrSPQnNiiSJ9fTcQapKTTxjRuT23NTj7';

  try {
    const result = await generateText({
      model: 'google/gemini-2.5-flash-lite',
      prompt: 'Hello',
    });
    console.log('Gateway direct Success:', result.text);
  } catch (e) {
    console.log('Gateway direct Error:', e.message);
  }
}

testVercelGateway();