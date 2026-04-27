#!/bin/bash
# Don't exit on non-critical errors
set +e
echo "=== OpenClaw Cloud Startup ==="

CONFIG_PATH="/root/.openclaw/openclaw.json"

# Verify config exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo "FATAL: $CONFIG_PATH not found!"
    ls -laR /root/.openclaw/
    exit 1
fi

echo "Config file found. Patching for cloud environment..."

# Patch the config for cloud deployment using Node.js
node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));

// 1. GOOGLE GEMINI
const apiKey = process.env.GEMINI_API_KEY || '';
if (!apiKey) console.error('WARNING: GEMINI_API_KEY not set!');

cfg.models = cfg.models || {};
cfg.models.mode = 'merge';
cfg.models.providers = {
  google: {
    api: 'google',
    apiKey: apiKey,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    models: [{
      id: 'gemini-1.5-flash-latest',
      name: 'Gemini 1.5 Flash',
      contextWindow: 1048576,
      maxTokens: 8192,
      input: ['text', 'image'],
      reasoning: false,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
    }]
  }
};

// 2. SET DEFAULT MODEL
cfg.agents = cfg.agents || {};
cfg.agents.defaults = cfg.agents.defaults || {};
cfg.agents.defaults.model = { primary: 'google/gemini-1.5-flash-latest' };
cfg.agents.defaults.workspace = '/root/.openclaw/workspace';

// 3. GATEWAY CONFIG
const port = parseInt(process.env.PORT) || 10000;
cfg.gateway = cfg.gateway || {};
cfg.gateway.bind = 'lan';
cfg.gateway.port = port;
cfg.gateway.mode = 'local';
cfg.gateway.auth = { mode: 'token', token: 'render-cloud-token-2026' };
delete cfg.gateway.tailscale;

// 4. DISABLE CRASHING PLUGINS
cfg.plugins = cfg.plugins || {};
cfg.plugins.entries = cfg.plugins.entries || {};
cfg.plugins.entries.bonjour = { enabled: false };
cfg.plugins.entries.zalouser = { enabled: false };
cfg.plugins.entries.ollama = { enabled: false };
cfg.plugins.entries.browser = { enabled: false };
cfg.plugins.entries['device-pair'] = { enabled: false };
cfg.plugins.entries['phone-control'] = { enabled: false };
cfg.plugins.entries['talk-voice'] = { enabled: false };

// 5. DISABLE ZALOUSER CHANNEL
if (cfg.channels && cfg.channels.zalouser) cfg.channels.zalouser.enabled = false;
if (cfg.bindings) cfg.bindings = cfg.bindings.filter(b => b.match.channel !== 'zalouser');

// 6. FIX TOOLS
if (cfg.tools && cfg.tools.web && cfg.tools.web.search) cfg.tools.web.search.provider = 'google';

fs.writeFileSync('$CONFIG_PATH', JSON.stringify(cfg, null, 2));
console.log('Config patched. Model: google/gemini-1.5-flash-latest, Port: ' + port);
"

if [ $? -ne 0 ]; then
    echo "FATAL: Config patching failed!"
    exit 1
fi

# Use Render's PORT
PORT="${PORT:-10000}"

echo "=== Starting OpenClaw Gateway on 0.0.0.0:$PORT ==="

# Start gateway - use node directly to run openclaw to get proper error output
# Find the actual openclaw entry point
OPENCLAW_BIN=$(which openclaw)
echo "OpenClaw binary: $OPENCLAW_BIN"

# Run with node directly for better error reporting
node --no-warnings "$OPENCLAW_BIN" gateway \
  --port "$PORT" \
  --bind lan \
  --auth token \
  --token "render-cloud-token-2026" \
  --allow-unconfigured \
  --verbose
