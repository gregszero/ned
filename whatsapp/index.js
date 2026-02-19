const http = require('http');
const crypto = require('crypto');
const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  makeCacheableSignalKeyStore,
} = require('@whiskeysockets/baileys');

const WEBHOOK_URL = process.env.WHATSAPP_WEBHOOK_URL || 'http://localhost:3000/webhooks/whatsapp';
const WEBHOOK_SECRET = process.env.WHATSAPP_WEBHOOK_SECRET || '';
const LISTEN_PORT = parseInt(process.env.WHATSAPP_BRIDGE_PORT || '3001', 10);
const USE_PAIRING_CODE = process.env.WHATSAPP_PAIRING_CODE === 'true';
const PHONE_NUMBER = process.env.WHATSAPP_PHONE_NUMBER || '';

let sock = null;
let connectionState = 'disconnected';

function sign(body) {
  if (!WEBHOOK_SECRET) return '';
  return crypto.createHmac('sha256', WEBHOOK_SECRET).update(body).digest('hex');
}

async function forwardToWebhook(payload) {
  const body = JSON.stringify(payload);
  const url = new URL(WEBHOOK_URL);

  const options = {
    hostname: url.hostname,
    port: url.port || (url.protocol === 'https:' ? 443 : 80),
    path: url.pathname,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(body),
      'X-Webhook-Signature': sign(body),
    },
  };

  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      res.resume();
      resolve(res.statusCode);
    });
    req.on('error', reject);
    req.end(body);
  });
}

async function startWhatsApp() {
  const { state, saveCreds } = await useMultiFileAuthState('./auth');

  sock = makeWASocket({
    auth: {
      creds: state.creds,
      keys: makeCacheableSignalKeyStore(state.keys, { level: 'silent', child: () => ({ level: 'silent' }) }),
    },
    printQRInTerminal: !USE_PAIRING_CODE,
    logger: { level: 'silent', child: () => ({ level: 'silent' }) },
  });

  if (USE_PAIRING_CODE && !state.creds.registered) {
    if (!PHONE_NUMBER) {
      console.error('WHATSAPP_PHONE_NUMBER required when using pairing code mode');
      process.exit(1);
    }
    setTimeout(async () => {
      const code = await sock.requestPairingCode(PHONE_NUMBER);
      console.log(`Pairing code: ${code}`);
    }, 3000);
  }

  sock.ev.on('creds.update', saveCreds);

  sock.ev.on('connection.update', ({ connection, lastDisconnect }) => {
    connectionState = connection || connectionState;

    if (connection === 'open') {
      console.log('WhatsApp connected');
    }

    if (connection === 'close') {
      const statusCode = lastDisconnect?.error?.output?.statusCode;
      const shouldReconnect = statusCode !== DisconnectReason.loggedOut;

      if (shouldReconnect) {
        console.log('Reconnecting...');
        startWhatsApp();
      } else {
        console.log('Logged out. Delete auth/ folder and restart to re-link.');
        process.exit(0);
      }
    }
  });

  sock.ev.on('messages.upsert', async ({ messages, type }) => {
    if (type !== 'notify') return;

    for (const msg of messages) {
      if (msg.key.fromMe) continue;
      if (!msg.message) continue;

      const text =
        msg.message.conversation ||
        msg.message.extendedTextMessage?.text ||
        null;

      if (!text) continue;

      const payload = {
        message: {
          id: msg.key.id,
          from: msg.key.remoteJid,
          text,
          conversation: msg.message.conversation,
          extendedTextMessage: msg.message.extendedTextMessage,
        },
      };

      try {
        await forwardToWebhook(payload);
      } catch (err) {
        console.error('Webhook forward failed:', err.message);
      }
    }
  });
}

// HTTP server for outbound messages and status
const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/status') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: connectionState }));
    return;
  }

  if (req.method === 'POST' && req.url === '/send/message') {
    let body = '';
    req.on('data', (chunk) => (body += chunk));
    req.on('end', async () => {
      try {
        const { phone, message } = JSON.parse(body);

        if (!phone || !message) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: 'phone and message required' }));
          return;
        }

        const jid = phone.includes('@') ? phone : `${phone}@s.whatsapp.net`;
        await sock.sendMessage(jid, { text: message });

        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ success: true }));
      } catch (err) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
      }
    });
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not found' }));
});

server.listen(LISTEN_PORT, () => {
  console.log(`WhatsApp bridge listening on port ${LISTEN_PORT}`);
  startWhatsApp();
});
