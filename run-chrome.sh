#!/bin/bash -uex
socat TCP-LISTEN:9222,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:59222 & 
Xvfb :1 -screen 0 1024x768x16 -ac -nolisten tcp -nolisten unix & 
DISPLAY=:1 fluxbox & 
DISPLAY=:1 x11vnc -nopw -forever -localhost -shared -rfbport 5900 -rfbportv6 5900 & 
DISPLAY=:1 websockify -D --web=/usr/share/novnc 7900 localhost:5900 & 
dbus-daemon --system --fork --print-address 1 > /tmp/dbus-session-addr.txt && 
export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/dbus-session-addr.txt) && 
DISPLAY=:1 google-chrome --disable-gpu --no-default-browser-check --no-first-run --disable-3d-apis --disable-dev-shm-usage 
--load-extension=/tmp/chrome/extensions/isdcac,/tmp/chrome/extensions/ublock,/tmp/chrome/extensions/bpc/bypass-paywalls-chrome-clean-master 
--remote-debugging-address=0.0.0.0 --remote-debugging-port=59222 --remote-allow-origins=* --user-data-dir=$(mktemp -d) 
"$@"