#!/bin/bash
echo "Starting OpenClaw in the Cloud..."

# Ensure the config directory exists
mkdir -p ~/.openclaw

# If a config zip is provided, extract it
if [ -f "openclaw_config.zip" ]; then
    echo "Restoring OpenClaw configuration and WhatsApp session..."
    unzip -o openclaw_config.zip -d ~/
fi

# Set cloud AI models to avoid local compute requirement
if [ ! -z "$GEMINI_API_KEY" ]; then
    echo "Configuring Google Gemini Cloud Model..."

    # Write the full provider config as JSON directly into openclaw.json
    node -e "
      const fs = require('fs');
      const cfgPath = require('os').homedir() + '/.openclaw/openclaw.json';
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

      // Remove ollama provider since we don't need it in the cloud
      delete cfg.models.providers.ollama;

      fs.writeFileSync(cfgPath, JSON.stringify(cfg, null, 2));
      console.log('Gemini configuration written successfully.');
    "
elif [ ! -z "$GROQ_API_KEY" ]; then
    echo "Configuring Groq Cloud Model..."
    openclaw config set models.providers.groq.apiKey "$GROQ_API_KEY"
    openclaw config set agents.defaults.model.primary "groq/llama3-8b-8192"
else
    echo "WARNING: No Cloud API Key provided! Please set GEMINI_API_KEY or GROQ_API_KEY in your cloud dashboard."
fi

# Disable bonjour since it crashes in strict cloud networking environments
openclaw plugins disable bonjour 2>/dev/null || true

# Use PORT env variable from Render, default to 18789
export OPENCLAW_PORT="${PORT:-18789}"

# Start the gateway, binding to 0.0.0.0 so the cloud platform can route to it
echo "Launching OpenClaw Gateway on port $OPENCLAW_PORT..."
openclaw gateway --port "$OPENCLAW_PORT"
