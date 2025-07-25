# Use a lightweight Debian-based image
FROM debian:bullseye-slim

# Define extension URLs as build arguments
ARG CURRENT_ISDCAC="v1.1.4"
ARG CURRENT_UBLOCK="uBOLite_2025.725.1450"
ARG ISDCAC_URL=https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies/releases/download/${CURRENT_ISDCAC}/ISDCAC-chrome-source.zip
ARG UBLOCK_URL=https://github.com/uBlockOrigin/uBOL-home/releases/download/${CURRENT_UBLOCK}/${CURRENT_UBLOCK}.chromium.mv3.zip

# Hardcoded Chrome version
ARG CHROME_VERSION="138.0.7204.168"
ARG CHROME_URL="https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chrome-linux64.zip"

RUN apt-get update
RUN apt-get install -y curl

COPY check-extension-versions.sh /tmp/check-extension-versions.sh
RUN chmod +x /tmp/check-extension-versions.sh
RUN /tmp/check-extension-versions.sh

# Install dependencies
RUN apt-get install -y wget \
    socat \
    procps \
    netcat-openbsd \
    net-tools \
    iproute2 \
    gnupg \
    curl \
    unzip \
    dbus \
    dbus-x11 \
    xvfb \
    upower \
    x11vnc \
    novnc \
    python3-websockify \
    fluxbox \
    chromium \
    jq
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list
RUN apt-get update
RUN apt-get install -y google-chrome-stable \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    libxss1 \
    --no-install-recommends

# Verify this is still the latest version
RUN LATEST_CHROME_RELEASE=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json | jq '.channels.Stable') && \
    LATEST_VERSION=$(echo "$LATEST_CHROME_RELEASE" | jq -r '.version') && \
    echo "Latest Chrome version: $LATEST_VERSION" && \
    echo "Hardcoded Chrome version: $CHROME_VERSION" && \
    if [ "$LATEST_VERSION" != "$CHROME_VERSION" ]; then \
        echo "ERROR: Chrome version mismatch! Latest is $LATEST_VERSION but using $CHROME_VERSION" && \
        echo "Please update the CHROME_VERSION in the Dockerfile" && \
        exit 1; \
    fi && \
    echo "Chrome version check passed: $CHROME_VERSION is the latest"

# Download the specific Chrome version
RUN wget -N "$CHROME_URL" -P /tmp/
RUN unzip /tmp/chrome-linux64.zip -d /tmp/
RUN mv /tmp/chrome-linux64 /tmp/chrome-for-testing
RUN rm /tmp/chrome-linux64.zip
RUN chmod +x /tmp/chrome-for-testing
RUN ln -sf /tmp/chrome-for-testing/chrome /bin/chrome-for-testing

# Create extension directory
RUN mkdir -p /tmp/chrome/extensions

# Download and unzip "I Still Don't Care About Cookies"
RUN curl -L -o /tmp/isdcac.zip "${ISDCAC_URL}" && \
    unzip /tmp/isdcac.zip -d /tmp/chrome/extensions/isdcac && \
    rm /tmp/isdcac.zip

# Download and unzip uBlock Origin
RUN curl -L -o /tmp/ublock.zip "${UBLOCK_URL}" && \
    unzip /tmp/ublock.zip -d /tmp/chrome/extensions/ublock && \
    rm /tmp/ublock.zip



RUN groupadd -r chromiumuser && useradd -u 1000 -rm -g chromiumuser -G audio,video chromiumuser
RUN chown -R chromiumuser:chromiumuser /tmp/chrome

RUN mkdir /run/dbus
RUN chmod 777 /run/dbus
RUN echo 01234567890123456789012345678901 > /etc/machine-id

COPY run-chrome.sh /tmp/run-chrome.sh
RUN chmod +x /tmp/run-chrome.sh

USER chromiumuser

ENV DBUS_SESSION_BUS_ADDRESS=autolaunch:

RUN x11vnc -storepasswd 123 /tmp/vnc-password

HEALTHCHECK --interval=5s --timeout=5s --start-period=30s --retries=15 \
  CMD curl -f http://localhost:9222/json/version | grep -q 'Browser'

ENTRYPOINT ["/tmp/run-chrome.sh"]
