#!/bin/bash -uex
socat TCP-LISTEN:9222,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:59222 & 
Xvfb :1 -screen 0 1024x768x16 -ac -nolisten tcp -nolisten unix & 
DISPLAY=:1 fluxbox & 
DISPLAY=:1 x11vnc -nopw -forever -localhost -shared -rfbport 5900 -rfbportv6 5900 & 
DISPLAY=:1 websockify -D --web=/usr/share/novnc 7900 localhost:5900 & 

dbus-daemon --system --fork --print-address 1 > /tmp/dbus-session-addr.txt

export DBUS_SESSION_BUS_ADDRESS=$(cat /tmp/dbus-session-addr.txt)

# Function to download and extract extension
download_extension() {
    local url="$1"
    local name="$2"
    local subdir="$3"
    local ext_dir="/tmp/chrome/extensions/$name"
    
    echo "Downloading extension $name from $url"
    mkdir -p "$ext_dir"
    
    # Download the extension
    if curl -L -o "/tmp/${name}.zip" "$url"; then
        # Extract the extension
        if unzip "/tmp/${name}.zip" -d "$ext_dir"; then
            # If subdir is specified and exists, move contents up one level
            if [[ -n "$subdir" && -d "$ext_dir/$subdir" ]]; then
                mv "$ext_dir/$subdir"/* "$ext_dir/"
                rmdir "$ext_dir/$subdir"
            fi
            rm "/tmp/${name}.zip"
            echo "Successfully installed extension $name"
            return 0
        else
            echo "Failed to extract extension $name"
            rm -f "/tmp/${name}.zip"
            return 1
        fi
    else
        echo "Failed to download extension $name from $url"
        return 1
    fi
}

# Process custom extensions from environment variables
EXTENSION_PATHS=""
if [[ -n "${CHROME_EXTENSIONS:-}" ]]; then
    IFS=',' read -ra EXTENSIONS <<< "$CHROME_EXTENSIONS"
    for ext_spec in "${EXTENSIONS[@]}"; do
        # Format: name|url|subdir (subdir is optional)
        IFS='|' read -ra EXT_PARTS <<< "$ext_spec"
        if [[ ${#EXT_PARTS[@]} -ge 2 ]]; then
            ext_name="${EXT_PARTS[0]}"
            ext_url="${EXT_PARTS[1]}"
            ext_subdir="${EXT_PARTS[2]:-}"  # Optional subdir, empty if not provided
            
            if download_extension "$ext_url" "$ext_name" "$ext_subdir"; then
                if [[ -n "$EXTENSION_PATHS" ]]; then
                    EXTENSION_PATHS="$EXTENSION_PATHS,/tmp/chrome/extensions/$ext_name"
                else
                    EXTENSION_PATHS="/tmp/chrome/extensions/$ext_name"
                fi
            fi
        else
            echo "Invalid extension specification: $ext_spec (expected format: name|url[|subdir])"
        fi
    done
fi

# Add default extensions that are always present
DEFAULT_EXTENSIONS="/tmp/chrome/extensions/isdcac,/tmp/chrome/extensions/ublock"
if [[ -n "$EXTENSION_PATHS" ]]; then
    EXTENSION_PATHS="$DEFAULT_EXTENSIONS,$EXTENSION_PATHS"
else
    EXTENSION_PATHS="$DEFAULT_EXTENSIONS"
fi

# https://winaero.com/google-releases-chrome-137-with-new-features-and-security-enhancements/#Removal_of_--load-extension_CLI_Flag
# DISPLAY=:1 google-chrome \
# DISPLAY=:1 chromium \
DISPLAY=:1 chrome-for-testing \
    --disable-gpu \
    --no-default-browser-check \
    --no-first-run \
    --no-sandbox \
    --disable-3d-apis \
    --disable-dev-shm-usage \
    --disable-features=DisableLoadExtensionCommandLineSwitch \
    --load-extension="$EXTENSION_PATHS" \
    --remote-debugging-address=0.0.0.0 \
    --remote-debugging-port=59222 \
    --remote-allow-origins=* \
    --user-data-dir=$(mktemp -d) \
    "$@"
