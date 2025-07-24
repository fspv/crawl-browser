# Use a lightweight Debian-based image
FROM debian:bullseye-slim

# Define extension URLs as build arguments
ARG CURRENT_ISDCAC="v1.1.4"
ARG CURRENT_UBLOCK="uBOLite_2025.718.1921"
ARG CURRENT_BPC_URL="https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass-paywalls-chrome-clean-master.zip"
ARG ISDCAC_URL=https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies/releases/download/${CURRENT_ISDCAC}/ISDCAC-chrome-source.zip
ARG UBLOCK_URL=https://github.com/uBlockOrigin/uBOL-home/releases/download/${CURRENT_UBLOCK}/${CURRENT_UBLOCK}.chromium.mv3.zip
ARG BPC_URL=${CURRENT_BPC_URL}

RUN apt-get update
RUN apt-get install -y curl

COPY check-extension-versions.sh /tmp/check-extension-versions.sh
RUN chmod +x /tmp/check-extension-versions.sh
RUN /tmp/check-extension-versions.sh

# Install dependencies
RUN apt-get install -y wget socat procps netcat-openbsd net-tools iproute2 gnupg curl unzip dbus dbus-x11 xvfb upower x11vnc novnc python3-websockify fluxbox \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 \
    --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

RUN apt-get update
RUN apt-get install -y chromium
RUN apt-get install -y jq

# Create a non-root user
RUN groupadd -r chromiumuser && useradd -u 1000 -rm -g chromiumuser -G audio,video chromiumuser

RUN mkdir /run/dbus
RUN chmod 777 /run/dbus
RUN echo 01234567890123456789012345678901 > /etc/machine-id

# Copy scripts before switching to non-root user
COPY run-chrome.sh /tmp/run-chrome.sh
RUN chmod +x /tmp/run-chrome.sh


USER chromiumuser

# Create extension directory
RUN mkdir -p /tmp/chrome/extensions
RUN mkdir -p /tmp/chrome/profile

# Download and unzip "I Still Don't Care About Cookies"
RUN curl -L -o /tmp/isdcac.zip "${ISDCAC_URL}" && \
    unzip /tmp/isdcac.zip -d /tmp/chrome/extensions/isdcac && \
    rm /tmp/isdcac.zip

# Download and unzip uBlock Origin
RUN curl -L -o /tmp/ublock.zip "${UBLOCK_URL}" && \
    unzip /tmp/ublock.zip -d /tmp/chrome/extensions/ublock && \
    rm /tmp/ublock.zip

# Download and unzip Bypass Paywall Clean
RUN curl -L -o /tmp/bpc.zip "${BPC_URL}" && \
    unzip /tmp/bpc.zip -d /tmp/chrome/extensions/bpc && \
    rm /tmp/bpc.zip

RUN LATEST_CHROME_RELEASE=$(curl -s https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json | jq '.channels.Stable') && LATEST_CHROME_URL=$(echo "$LATEST_CHROME_RELEASE" | jq -r '.downloads.chrome[] | select(.platform == "linux64") | .url') && wget -N "$LATEST_CHROME_URL" -P ~/
RUN unzip ~/chrome-linux64.zip -d ~/
RUN mv ~/chrome-linux64 ~/chrome-for-testing
RUN chmod +x ~/chrome-for-testing
RUN rm ~/chrome-linux64.zip

ENV DBUS_SESSION_BUS_ADDRESS autolaunch:

RUN x11vnc -storepasswd 123 /tmp/vnc-password

# Set the entrypoint
ENTRYPOINT ["/tmp/run-chrome.sh"]
