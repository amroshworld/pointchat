const sdk = require('node-appwrite');

const DELETE_PHRASE = 'DELETE MY ACCOUNT';
const DEFAULT_SUPPORT_EMAIL = 'amrosh.world@gmail.com';

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function parseBody(req, log) {
  if (!req.body) {
    return {};
  }

  if (typeof req.body === 'object') {
    return req.body;
  }

  const raw = String(req.body || '').trim();
  if (!raw) {
    return {};
  }

  try {
    return JSON.parse(raw);
  } catch (_) {
    // Not JSON, try URL encoded form payload.
  }

  try {
    return Object.fromEntries(new URLSearchParams(raw).entries());
  } catch (error) {
    log(`Unable to parse body: ${error.message}`);
    return {};
  }
}

function pageTemplate(options = {}) {
  const { supportEmail = DEFAULT_SUPPORT_EMAIL } = options;
  const escapedSupportEmail = escapeHtml(supportEmail);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>PointChat Account Deletion</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f7f9fc;
      --card: #ffffff;
      --text: #101828;
      --muted: #475467;
      --danger: #b42318;
      --ok: #027a48;
      --border: #d0d5dd;
      --accent: #0b4cff;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: var(--text);
      background: linear-gradient(180deg, #eef4ff 0%, var(--bg) 50%, #fefefe 100%);
      min-height: 100vh;
      display: grid;
      place-items: center;
      padding: 24px;
    }
    .card {
      width: min(680px, 100%);
      background: var(--card);
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 24px;
      box-shadow: 0 10px 40px rgba(16, 24, 40, 0.08);
    }
    h1 {
      margin: 0 0 8px;
      font-size: 26px;
      line-height: 1.2;
    }
    p { color: var(--muted); margin: 0 0 12px; }
    .note {
      border: 1px solid var(--border);
      background: #f8fafc;
      border-radius: 10px;
      padding: 12px;
      margin: 14px 0;
      color: var(--muted);
      font-size: 14px;
    }
    .error {
      border: 1px solid #fecdca;
      background: #fef3f2;
      color: var(--danger);
      border-radius: 10px;
      padding: 12px;
      margin: 12px 0;
      font-size: 14px;
    }
    .success {
      border: 1px solid #abefc6;
      background: #ecfdf3;
      color: var(--ok);
      border-radius: 10px;
      padding: 12px;
      margin: 12px 0;
      font-size: 14px;
    }
    form {
      display: grid;
      gap: 12px;
      margin-top: 14px;
    }
    label {
      font-size: 14px;
      font-weight: 600;
      color: #344054;
      display: block;
      margin-bottom: 6px;
    }
    input {
      width: 100%;
      padding: 12px;
      border-radius: 10px;
      border: 1px solid var(--border);
      font-size: 14px;
      outline: none;
    }
    input:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(11, 76, 255, 0.15);
    }
    button {
      border: 0;
      background: var(--danger);
      color: #fff;
      font-weight: 700;
      font-size: 14px;
      border-radius: 10px;
      padding: 12px 14px;
      cursor: pointer;
    }
    button:hover { filter: brightness(0.96); }
    .small { font-size: 13px; color: var(--muted); }
    code {
      background: #f2f4f7;
      border: 1px solid #eaecf0;
      border-radius: 6px;
      padding: 1px 6px;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
      font-size: 12px;
      color: #111827;
    }
  </style>
</head>
<body>
  <main class="card">
    <h1>PointChat Account Deletion</h1>
    <p>Use the in-app flow to permanently delete your account.</p>

    <div class="note">
      <strong>How to delete your account in the app:</strong>
      <ul>
        <li>Open PointChat.</li>
        <li>Go to Settings.</li>
        <li>Tap Delete account.</li>
        <li>Type <code>${DELETE_PHRASE}</code> and confirm.</li>
      </ul>
    </div>

    <div class="note">
      <strong>What is deleted:</strong>
      <ul>
        <li>Your account data and sign-in access.</li>
        <li>Associated PointChat account data.</li>
      </ul>
      <strong>What may be retained:</strong>
      <ul>
        <li>Security and backup logs for up to 90 days.</li>
        <li>Store billing records required for legal/accounting obligations.</li>
      </ul>
    </div>

    <p class="small" style="margin-top: 14px;">
      If you cannot access the app, contact support: <a href="mailto:${escapedSupportEmail}">${escapedSupportEmail}</a>
    </p>
  </main>
</body>
</html>`;
}

function html(res, payload, status = 200) {
  const headers = {
    'Content-Type': 'text/html; charset=utf-8',
    'Cache-Control': 'no-store',
  };

  if (typeof res.text === 'function') {
    return res.text(payload, status, headers);
  }

  if (typeof res.send === 'function') {
    return res.send(payload, status, headers);
  }

  // Last resort for runtimes that only expose JSON helpers.
  return res.json({
    success: false,
    error: 'HTML response helper not available in runtime.',
    html: payload,
  }, status);
}

function jsonResponse(res, payload, status = 200) {
  if (typeof res.json === 'function') {
    return res.json(payload, status, {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    });
  }

  return res.send(JSON.stringify(payload), status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
}

module.exports = async function ({ req, res, log, error }) {
  const method = String(req.method || 'GET').toUpperCase();
  const requestHeaders = req.headers || {};
  const supportEmail = process.env.DELETION_SUPPORT_EMAIL || DEFAULT_SUPPORT_EMAIL;

  if (method === 'GET') {
    return html(res, pageTemplate({ supportEmail }));
  }

  if (method !== 'POST') {
    return jsonResponse(
      res,
      { success: false, error: 'Method not allowed. Use POST for deletion.' },
      405,
    );
  }

  const authUserId = String(requestHeaders['x-appwrite-user-id'] || '').trim();
  if (!authUserId) {
    return jsonResponse(
      res,
      {
        success: false,
        error:
          'Authentication required. Please delete your account from inside the PointChat app while signed in.',
      },
      401,
    );
  }

  const body = parseBody(req, log);
  const confirmText = String(body.confirmText || '').trim();

  if (!confirmText) {
    return jsonResponse(
      res,
      { success: false, error: 'Confirmation text is required.' },
      400,
    );
  }

  if (confirmText !== DELETE_PHRASE) {
    return jsonResponse(
      res,
      { success: false, error: `Please type exactly: ${DELETE_PHRASE}` },
      400,
    );
  }

  const endpoint = process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  const projectId = process.env.APPWRITE_FUNCTION_PROJECT_ID;
  const apiKey =
    requestHeaders['x-appwrite-key'] ||
    process.env.APPWRITE_FUNCTION_API_KEY ||
    process.env.APPWRITE_API_KEY;

  if (!endpoint || !projectId || !apiKey) {
    error(
      `Missing function credentials. endpoint=${!!endpoint} project=${!!projectId} key=${!!apiKey}`,
    );
    return jsonResponse(
      res,
      {
        success: false,
        error: 'Deletion service is not fully configured. Please try again later.',
      },
      500,
    );
  }

  try {
    const client = new sdk.Client()
      .setEndpoint(endpoint)
      .setProject(projectId)
      .setKey(apiKey);
    const users = new sdk.Users(client);

    try {
      await users.delete(authUserId);
    } catch (deleteErr) {
      const type = String(deleteErr?.type || '').toLowerCase();
      const code = Number(deleteErr?.code || 0);
      if (code === 404 || type.includes('user_not_found')) {
        log(`Account already deleted. userId=${authUserId}`);
        return jsonResponse(
          res,
          {
            success: true,
            message: 'Your PointChat account was already deleted.',
          },
          200,
        );
      }
      throw deleteErr;
    }

    log(`Account deleted in-app. userId=${authUserId}`);

    return jsonResponse(
      res,
      {
        success: true,
        message:
          'Your PointChat account was deleted successfully. Some backup/log records may be retained for up to 90 days for legal and security reasons.',
      },
      200,
    );
  } catch (err) {
    error(`Account deletion failed for userId=${authUserId}: ${err.message}`);
    return jsonResponse(
      res,
      {
        success: false,
        error:
          'Unable to delete this account automatically. Please contact support to complete deletion.',
      },
      500,
    );
  }
};
