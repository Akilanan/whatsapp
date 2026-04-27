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
    openclaw config set models.providers.google.apiKey "$GEMINI_API_KEY"
    openclaw config set agents.defaults.model.primary "google/gemini-1.5-flash-latest"
elif [ ! -z "$GROQ_API_KEY" ]; then
    echo "Configuring Groq Cloud Model..."
    openclaw config set models.providers.groq.apiKey "$GROQ_API_KEY"
    openclaw config set agents.defaults.model.primary "groq/llama3-8b-8192"
else
    echo "WARNING: No Cloud API Key provided! Please set GEMINI_API_KEY or GROQ_API_KEY in your cloud dashboard."
fi

# Disable bonjour since it crashes in strict cloud networking environments
openclaw plugins disable bonjour

# Start the gateway, binding to 0.0.0.0 so the cloud platform can route to it
echo "Launching OpenClaw Gateway..."
openclaw gateway --hostname 0.0.0.0 --port 18789
