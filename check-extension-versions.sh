#!/bin/bash

# Script to check for latest extension versions
# Returns non-zero exit code if any extensions are outdated

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking extension versions..."
echo "=============================="

OUTDATED=0

# Check I Still Don't Care About Cookies
echo -n "I Still Don't Care About Cookies: "
LATEST_ISDCAC=$(curl -s https://api.github.com/repos/OhMyGuus/I-Still-Dont-Care-About-Cookies/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$LATEST_ISDCAC" = "$CURRENT_ISDCAC" ]; then
    echo -e "${GREEN}✓ Up to date${NC} ($CURRENT_ISDCAC)"
else
    echo -e "${RED}✗ Outdated${NC}"
    echo "  Current: $CURRENT_ISDCAC"
    echo "  Latest:  $LATEST_ISDCAC"
    echo "  New URL: https://github.com/OhMyGuus/I-Still-Dont-Care-About-Cookies/releases/download/${LATEST_ISDCAC}/ISDCAC-chrome-source.zip"
    OUTDATED=1
fi

# Check uBlock Origin Lite
echo -n "uBlock Origin Lite: "
# Get latest release (excluding betas)
LATEST_UBLOCK=$(curl -s https://api.github.com/repos/uBlockOrigin/uBOL-home/releases | grep '"tag_name":' | grep -v beta | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ "$LATEST_UBLOCK" = "$CURRENT_UBLOCK" ]; then
    echo -e "${GREEN}✓ Up to date${NC} ($CURRENT_UBLOCK)"
else
    echo -e "${RED}✗ Outdated${NC}"
    echo "  Current: $CURRENT_UBLOCK"
    echo "  Latest:  $LATEST_UBLOCK"
    echo "  New URL: https://github.com/uBlockOrigin/uBOL-home/releases/download/${LATEST_UBLOCK}/${LATEST_UBLOCK}.chromium.mv3.zip"
    OUTDATED=1
fi

# Check Bypass Paywalls Clean (limited check - just verify URL is accessible)
echo -n "Bypass Paywalls Clean: "
if curl -s -L --head "$CURRENT_BPC_URL" | head -1 | grep -q "200\|302"; then
    echo -e "${GREEN}✓ URL accessible${NC}"
    echo "  Note: Cannot automatically check for newer versions on GitFlic"
else
    echo -e "${RED}✗ URL not accessible${NC}"
    OUTDATED=1
fi

echo "=============================="

if [ "$OUTDATED" -eq 1 ]; then
    echo -e "${RED}Some extensions are outdated!${NC}"
    echo "Update the ARG values in the Dockerfile with the new URLs shown above."
    exit 1
else
    echo -e "${GREEN}All extensions are up to date!${NC}"
    exit 0
fi
