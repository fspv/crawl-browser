# Use a lightweight Debian-based image
FROM debian:bullseye-slim

# Install dependencies
RUN apt-get update \
  && apt-get install -y wget socat curl procps netcat-openbsd net-tools iproute2 gnupg curl unzip dbus dbus-x11 xvfb upower x11vnc novnc python3-websockify fluxbox \
  && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
  && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
  && apt-get update \
  && apt-get install -y google-chrome-stable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxss1 \
    --no-install-recommends \
  && rm -rf /var/lib/apt/lists/*

# RUN mkdir -p /etc/chromium/policies/managed/
# RUN echo '{"ExtensionInstallForcelist": ["edibdbjcniadpccecjdfdjjppcpchdlm"]}' > /etc/chromium/policies/managed/policy.json

# Create a non-root user
RUN groupadd -r chromiumuser && useradd -u 1000 -rm -g chromiumuser -G audio,video chromiumuser

RUN mkdir /run/dbus
RUN chmod 777 /run/dbus
RUN echo 01234567890123456789012345678901 > /etc/machine-id

USER chromiumuser

# Create extension directory
RUN mkdir -p /tmp/chrome/extensions
RUN mkdir -p /tmp/chrome/profile

# Download and unzip "I Still Don't Care About Cookies"
RUN curl -L -o /tmp/isdcac.zip https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies/releases/download/v1.1.4/ISDCAC-chrome-source.zip && \
    unzip /tmp/isdcac.zip -d /tmp/chrome/extensions/isdcac && \
    rm /tmp/isdcac.zip

# Download and unzip uBlock Origin
RUN curl -L -o /tmp/ublock.zip https://github.com/uBlockOrigin/uBOL-home/releases/download/uBOLite_2025.4.13.1188/uBOLite_2025.4.13.1188.chromium.mv3.zip && \
    unzip /tmp/ublock.zip -d /tmp/chrome/extensions/ublock && \
    rm /tmp/ublock.zip

# Download and unzip Bypass Paywall Clean
RUN curl -L -o /tmp/bpc.zip "https://gitflic.ru/project/magnolia1234/bpc_uploads/blob/raw?file=bypass-paywalls-chrome-clean-master.zip" && \
    unzip /tmp/bpc.zip -d /tmp/chrome/extensions/bpc && \
    rm /tmp/bpc.zip

ENV DBUS_SESSION_BUS_ADDRESS autolaunch:

RUN x11vnc -storepasswd 123 /tmp/vnc-password

RUN echo '#!/bin/bash -uex\n\
socat TCP-LISTEN:9222,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:59222 & \
Xvfb :1 -screen 0 1024x768x16 -ac -nolisten tcp -nolisten unix & \
DISPLAY=:1 fluxbox & \
DISPLAY=:1 x11vnc -nopw -forever -localhost -shared -rfbport 5900 -rfbportv6 5900 & \
DISPLAY=:1 websockify -D --web=/usr/share/novnc 7900 localhost:5900 & \
dbus-daemon --system --fork --print-address 1 > /tmp/dbus-session-addr.txt && \
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/dbus-session-addr.txt) && \
DISPLAY=:1 google-chrome --disable-gpu --no-default-browser-check --no-first-run --disable-3d-apis --disable-dev-shm-usage \
--load-extension=/tmp/chrome/extensions/isdcac,/tmp/chrome/extensions/ublock,/tmp/chrome/extensions/bpc/bypass-paywalls-chrome-clean-master \
--remote-debugging-address=0.0.0.0 --remote-debugging-port=59222 --remote-allow-origins=* --user-data-dir=$(mktemp -d) \
"$@"' > /tmp/run-chrome.sh && chmod +x /tmp/run-chrome.sh

# Set the entrypoint
ENTRYPOINT ["/tmp/run-chrome.sh"]
