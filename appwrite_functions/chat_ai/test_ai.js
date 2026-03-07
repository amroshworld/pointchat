const { createOpenAI } = require('@ai-sdk/openai');
const { generateText } = require('ai');

async function testOpenAI() {
  const openai = createOpenAI({
    apiKey: 'vck_5gLfkzF36z3N2U0qn2jVSU1fHrSPQnNiiSJ9fTcQapKTTxjRuT23NTj7',
  });

  try {
    const result = await generateText({
      model: openai('gpt-4o-mini'),
      prompt: 'Hello',
    });
    console.log('OpenAI direct Success:', result.text);
  } catch (e) {
    console.log('OpenAI direct Error:', e.message);
  }
}

testOpenAI();