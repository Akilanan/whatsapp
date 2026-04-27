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
# This fixes ALL issues: model, paths, auth, binding, plugins, etc.
node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$CONFIG_PATH', 'utf8'));

// ==========================================
// 1. GOOGLE GEMINI - Free Cloud AI Model
// ==========================================
const apiKey = process.env.GEMINI_API_KEY || '';
if (!apiKey) {
  console.error('WARNING: GEMINI_API_KEY not set!');
}

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
// Remove ollama entirely - no local model server in the cloud
delete cfg.models.providers.ollama;

// ==========================================
// 2. SET DEFAULT MODEL TO GEMINI
// ==========================================
cfg.agents = cfg.agents || {};
cfg.agents.defaults = cfg.agents.defaults || {};
cfg.agents.defaults.model = { primary: 'google/gemini-1.5-flash-latest' };
cfg.agents.defaults.workspace = '/root/.openclaw/workspace';

// ==========================================
// 3. GATEWAY - Bind to all interfaces, disable auth for health checks
// ==========================================
const port = parseInt(process.env.PORT) || 10000;
cfg.gateway = cfg.gateway || {};
cfg.gateway.bind = 'lan';
cfg.gateway.port = port;
cfg.gateway.mode = 'local';
cfg.gateway.auth = { mode: 'none' };
delete cfg.gateway.tailscale;

// ==========================================
// 4. DISABLE ALL CRASHING PLUGINS
// ==========================================
cfg.plugins = cfg.plugins || {};
cfg.plugins.entries = cfg.plugins.entries || {};
cfg.plugins.entries.bonjour = { enabled: false };
cfg.plugins.entries.zalouser = { enabled: false };
cfg.plugins.entries.ollama = { enabled: false };

// ==========================================
// 5. DISABLE ZALOUSER CHANNEL
// ==========================================
if (cfg.channels && cfg.channels.zalouser) {
  cfg.channels.zalouser.enabled = false;
}

// Remove zalouser bindings
if (cfg.bindings) {
  cfg.bindings = cfg.bindings.filter(b => b.match.channel !== 'zalouser');
}

// ==========================================
// 6. FIX TOOLS - Remove ollama reference
// ==========================================
if (cfg.tools && cfg.tools.web && cfg.tools.web.search) {
  cfg.tools.web.search.provider = 'google';
}

// Write the patched config
fs.writeFileSync('$CONFIG_PATH', JSON.stringify(cfg, null, 2));
console.log('=== Config patched successfully ===');
console.log('Model: google/gemini-1.5-flash-latest');
console.log('Gateway port: ' + port);
console.log('Gateway bind: 0.0.0.0');
console.log('Auth: none (for health checks)');
console.log('Disabled plugins: bonjour, zalouser, ollama');
"

echo ""
echo "Final config:"
cat "$CONFIG_PATH"
echo ""

# Use Render's PORT env var (defaults to 10000)
PORT="${PORT:-10000}"

echo ""
echo "=== Starting OpenClaw Gateway on 0.0.0.0:$PORT ==="
echo ""

# Use exec so the process gets signals properly
# Use --allow-unconfigured to skip strict config validation
# Use --bind custom to allow 0.0.0.0 binding
# Use --auth none to allow Render health checks
exec openclaw gateway run \
  --port "$PORT" \
  --bind lan \
  --auth none \
  --allow-unconfigured \
  --verbose 2>&1
