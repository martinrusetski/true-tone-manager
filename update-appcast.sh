#!/bin/bash
# Signs a release DMG with the Sparkle EdDSA key and prepends a new <item> to
# appcast.xml (newest first). Existing entries are preserved.
#
# The private signing key is read, in order of preference:
#   1. $SPARKLE_PRIVATE_KEY  (base64 string; used in CI via a GitHub secret)
#   2. the login Keychain    (local machine, where generate_keys stored it)
#
# Usage:
#   ./update-appcast.sh <short-version> <build-version> <dmg-path> <download-url>
# Example:
#   ./update-appcast.sh 0.4.0 7 TrueToneManager-v0.4.0.dmg \
#       https://github.com/martinrusetski/true-tone-manager/releases/download/v0.4.0/TrueToneManager-v0.4.0.dmg
set -e

SHORT_VERSION="$1"
BUILD_VERSION="$2"
DMG_PATH="$3"
DOWNLOAD_URL="$4"
MIN_SYSTEM_VERSION="13.0"

if [ -z "$SHORT_VERSION" ] || [ -z "$BUILD_VERSION" ] || [ -z "$DMG_PATH" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "usage: update-appcast.sh <short-version> <build-version> <dmg-path> <download-url>" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPCAST="${SCRIPT_DIR}/appcast.xml"
SIGN_UPDATE="$(find "${SCRIPT_DIR}/.build" -name sign_update -type f -path '*bin*' | head -1)"

if [ -z "$SIGN_UPDATE" ]; then
    echo "update-appcast: sign_update tool not found under .build (run 'swift build' first)" >&2
    exit 1
fi

# sign_update prints:  sparkle:edSignature="..." length="..."
if [ -n "$SPARKLE_PRIVATE_KEY" ]; then
    SIG_ATTRS="$("$SIGN_UPDATE" "$DMG_PATH" -s "$SPARKLE_PRIVATE_KEY")"
else
    SIG_ATTRS="$("$SIGN_UPDATE" "$DMG_PATH")"
fi

PUB_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

ITEM="    <item>
      <title>${SHORT_VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD_VERSION}</sparkle:version>
      <sparkle:shortVersionString>${SHORT_VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
      <enclosure url=\"${DOWNLOAD_URL}\" ${SIG_ATTRS} type=\"application/octet-stream\" />
    </item>"

# Insert the new item immediately after the marker so the newest release is
# first. Use a Python one-liner for a reliable multi-line insert.
MARKER="<!-- BEGIN ITEMS -->"
export ITEM MARKER
python3 - "$APPCAST" <<'PY'
import os, sys
path = sys.argv[1]
marker = os.environ["MARKER"]
item = os.environ["ITEM"]
with open(path, "r", encoding="utf-8") as f:
    content = f.read()
if marker not in content:
    sys.exit(f"marker {marker!r} not found in {path}")
content = content.replace(marker, marker + "\n" + item, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(content)
PY

echo "Appcast updated with ${SHORT_VERSION} (build ${BUILD_VERSION})"
