#!/bin/bash
echo "Starting OpenClaw in the Cloud..."

# Ensure the config directory exists
mkdir -p /root/.openclaw

# Extract the config zip into the correct .openclaw directory
if [ -f "/app/openclaw_config.zip" ]; then
    echo "Restoring OpenClaw configuration and WhatsApp session..."
    unzip -o /app/openclaw_config.zip -d /root/.openclaw/
    echo "Config files extracted:"
    ls -la /root/.openclaw/
fi

# Set cloud AI models to avoid local compute requirement
if [ ! -z "$GEMINI_API_KEY" ]; then
    echo "Configuring Google Gemini Cloud Model..."

    # Write the full provider config directly into openclaw.json
    node -e "
      const fs = require('fs');
      const cfgPath = '/root/.openclaw/openclaw.json';
      if (!fs.existsSync(cfgPath)) {
        console.error('ERROR: openclaw.json not found at ' + cfgPath);
        process.exit(1);
      }
      const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));

      // Add Google Gemini provider
      cfg.models = cfg.models || {};
      cfg.models.providers = cfg.models.providers || {};
      cfg.models.providers.google = {
        api: 'google',
        apiKey: process.env.GEMINI_API_KEY,
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
      };

      // Set default model to Gemini
      cfg.agents = cfg.agents || {};
      cfg.agents.defaults = cfg.agents.defaults || {};
      cfg.agents.defaults.model = { primary: 'google/gemini-1.5-flash-latest' };

      // Fix workspace path for Linux
      cfg.agents.defaults.workspace = '/root/.openclaw/workspace';

      // Remove ollama provider since we don't need it in the cloud
      if (cfg.models.providers.ollama) delete cfg.models.providers.ollama;

      // Disable problematic plugins
      cfg.plugins = cfg.plugins || {};
      cfg.plugins.entries = cfg.plugins.entries || {};
      cfg.plugins.entries.bonjour = { enabled: false };
      cfg.plugins.entries.zalouser = { enabled: false };

      // Set gateway to bind on all interfaces
      cfg.gateway = cfg.gateway || {};
      cfg.gateway.bind = '0.0.0.0';

      fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
      console.log('Gemini configuration written successfully.');
      console.log('Model: google/gemini-1.5-flash-latest');
    "
else
    echo "WARNING: No GEMINI_API_KEY provided! Set it in your Render Environment tab."
fi

# Use PORT env variable from Render (Render assigns port 10000), default to 18789
export PORT="${PORT:-18789}"

# Start the gateway
echo "Launching OpenClaw Gateway on port $PORT..."
exec openclaw gateway --port "$PORT"
