FROM node:22-bullseye

# Install required dependencies
RUN apt-get update && apt-get install -y \
    unzip \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    wget \
    xdg-utils \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Install OpenClaw globally
RUN npm install -g openclaw@latest

# Create openclaw config directory
RUN mkdir -p /root/.openclaw/workspace /root/.openclaw/credentials /root/.openclaw/identity

WORKDIR /app

# Copy everything
COPY . /app/

# CRITICAL: Fix Windows CRLF line endings -> Unix LF
RUN dos2unix /app/start.sh && chmod +x /app/start.sh

# Extract the WhatsApp session and credentials into the correct directory
RUN if [ -f /app/openclaw_config.zip ]; then \
      unzip -o /app/openclaw_config.zip -d /root/.openclaw/ || true && \
      echo "Config extracted successfully:" && \
      ls -la /root/.openclaw/ ; \
    fi

# Expose the port Render will use (10000 is Render's default)
EXPOSE 10000

CMD ["/app/start.sh"]
