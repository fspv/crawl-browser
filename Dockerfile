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


# Create a non-root user
RUN groupadd -r chromiumuser && useradd -u 1000 -rm -g chromiumuser -G audio,video chromiumuser

RUN mkdir /run/dbus
RUN chmod 777 /run/dbus
RUN echo 01234567890123456789012345678901 > /etc/machine-id

# Copy the run script before switching to non-root user
COPY run-chrome.sh /tmp/run-chrome.sh
RUN chmod +x /tmp/run-chrome.sh && chown chromiumuser:chromiumuser /tmp/run-chrome.sh

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

# Set the entrypoint
ENTRYPOINT ["/tmp/run-chrome.sh"]
