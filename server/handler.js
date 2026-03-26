// ═══════════════════════════════════════════
//  MYZR — RunPod Serverless Handler
//  Wraps the game engine for RunPod's job API
//
//  Jobs are submitted via RunPod's /runsync endpoint.
//  Game state persists in-memory on the worker.
//  With min_workers=1, the worker stays alive and
//  the tick loop runs continuously.
// ═══════════════════════════════════════════

const http = require('http');
const { GameEngine, fmt } = require('./game-engine');
const { PairCodeStore } = require('./pair-codes');
const crypto = require('crypto');

// In-memory session store (persists while worker lives)
const sessions = new Map();
const pairCodes = new PairCodeStore();

const TICK_INTERVAL = 100;

function createSession() {
  const sessionId = crypto.randomBytes(16).toString('hex');
  const apiToken = crypto.randomBytes(24).toString('base64url');
  const engine = new GameEngine();

  const session = {
    engine,
    apiToken,
    createdAt: Date.now(),
    lastActivity: Date.now(),
    pendingEvents: [], // accumulate events between polls
    tickTimer: null,
  };

  // Start tick loop
  session.tickTimer = setInterval(() => {
    engine.tick();
    const events = engine.drainEvents();
    if (events.length > 0) {
      session.pendingEvents.push(...events);
      // Cap pending events to prevent memory bloat
      if (session.pendingEvents.length > 500) {
        session.pendingEvents = session.pendingEvents.slice(-200);
      }
    }
  }, TICK_INTERVAL);

  sessions.set(sessionId, session);
  return { sessionId, apiToken };
}

function getSession(sessionId) {
  const session = sessions.get(sessionId);
  if (session) session.lastActivity = Date.now();
  return session;
}

function getSessionByToken(token) {
  for (const [sessionId, session] of sessions) {
    if (session.apiToken === token) {
      session.lastActivity = Date.now();
      return { sessionId, session };
    }
  }
  return null;
}

// Cleanup stale sessions every 10 min
setInterval(() => {
  const now = Date.now();
  for (const [id, session] of sessions) {
    if (now - session.lastActivity > 60 * 60 * 1000) {
      clearInterval(session.tickTimer);
      sessions.delete(id);
    }
  }
  pairCodes.cleanup();
}, 10 * 60 * 1000);

// ── Handler: processes RunPod jobs ──
// Input format: { action: "...", sessionId: "...", token: "...", ... }
function handler(event) {
  const input = event.input || {};
  const action = input.action;

  try {
    // ── new-game ──
    if (action === 'new-game') {
      const { sessionId, apiToken } = createSession();
      const pairCode = pairCodes.generate(sessionId);
      return { sessionId, pairCode };
    }

    // ── pair ──
    if (action === 'pair') {
      const sessionId = pairCodes.redeem(input.pairCode);
      if (!sessionId) return { error: 'Invalid or expired pair code' };
      const session = getSession(sessionId);
      if (!session) return { error: 'Session not found' };
      return { sessionId, token: session.apiToken };
    }

    // ── poll (get state + drain events) ──
    if (action === 'poll') {
      const session = getSession(input.sessionId);
      if (!session) return { error: 'Session not found' };
      const events = session.pendingEvents.splice(0);
      return {
        state: session.engine.getState(),
        events,
        summary: session.engine.getSummary(),
      };
    }

    // ── state (for MCP server) ──
    if (action === 'state') {
      const result = getSessionByToken(input.token);
      if (!result) return { error: 'Invalid token' };
      return {
        state: result.session.engine.getState(),
        summary: result.session.engine.getSummary(),
        availableActions: result.session.engine.getAvailableActions(),
      };
    }

    // ── game-action (player or MCP) ──
    if (action === 'game-action') {
      let session;
      if (input.sessionId) {
        session = getSession(input.sessionId);
      } else if (input.token) {
        const result = getSessionByToken(input.token);
        session = result ? result.session : null;
      }
      if (!session) return { error: 'Session not found' };
      const success = session.engine.executeAction(input.gameAction, input.params || {});
      return { success };
    }

    // ── word (typed easter egg) ──
    if (action === 'word') {
      const session = getSession(input.sessionId);
      if (!session) return { error: 'Session not found' };
      session.engine.checkWordEgg(input.word);
      return { ok: true };
    }

    // ── game-data (quotes, model names) ──
    if (action === 'game-data') {
      const { _quotes, _modelNames } = require('./game-engine');
      return { quotes: _quotes, modelNames: _modelNames };
    }

    // ── health ──
    if (action === 'health') {
      return { status: 'ok', sessions: sessions.size };
    }

    return { error: 'Unknown action: ' + action };
  } catch (e) {
    return { error: e.message };
  }
}

// ── RunPod Serverless HTTP Server ──
// RunPod proxies HTTP to port 8000 on serverless workers.
// We serve a simple handler API + static client files.

const fs = require('path');
const path = require('path');

const PORT = process.env.PORT || 8000;

const server = http.createServer((req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') { res.writeHead(200); res.end(); return; }

  // API endpoint — all game actions go through POST /api
  if (req.method === 'POST' && req.url === '/api') {
    let body = '';
    req.on('data', chunk => body += chunk);
    req.on('end', () => {
      try {
        const input = JSON.parse(body);
        const result = handler({ input });
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(result));
      } catch (e) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: e.message }));
      }
    });
    return;
  }

  // Health check
  if (req.url === '/health' || req.url === '/api/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', sessions: sessions.size }));
    return;
  }

  // Serve static client files
  const clientDir = path.join(__dirname, '..', 'client');
  let filePath = req.url === '/' ? '/index.html' : req.url;
  const fullPath = path.join(clientDir, filePath);

  // Prevent directory traversal
  if (!fullPath.startsWith(clientDir)) {
    res.writeHead(403); res.end(); return;
  }

  const fsModule = require('fs');
  fsModule.readFile(fullPath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found');
      return;
    }
    const ext = path.extname(fullPath);
    const types = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css', '.json': 'application/json' };
    res.writeHead(200, { 'Content-Type': types[ext] || 'application/octet-stream' });
    res.end(data);
  });
});

server.listen(PORT, () => {
  console.log(`Myzr serverless handler running on port ${PORT}`);
});
