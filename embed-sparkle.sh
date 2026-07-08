#!/bin/bash
# Copies the SwiftPM-resolved Sparkle.framework into an .app bundle's
# Contents/Frameworks. The executable links Sparkle with an
# @executable_path/../Frameworks rpath (see Package.swift), so the app will not
# launch without this.
#
# The framework keeps Sparkle's own Developer ID signature; the app's
# disable-library-validation entitlement lets our ad-hoc app load it. The
# caller must code-sign the app bundle AFTER this runs so the app seals a
# reference to the embedded framework.
#
# Usage: ./embed-sparkle.sh "Path/To/App.app"
set -e

APP="$1"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "embed-sparkle: expected a path to an .app bundle" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRAMEWORK_SRC="$(find "$SCRIPT_DIR/.build" -type d -name 'Sparkle.framework' -path '*macos*' | head -1)"
if [ -z "$FRAMEWORK_SRC" ]; then
    echo "embed-sparkle: Sparkle.framework not found under .build (run 'swift build' first)" >&2
    exit 1
fi

echo "Embedding Sparkle.framework from $FRAMEWORK_SRC"
mkdir -p "$APP/Contents/Frameworks"
rm -rf "$APP/Contents/Frameworks/Sparkle.framework"
# ditto preserves the framework's symlinks and code signature exactly.
ditto "$FRAMEWORK_SRC" "$APP/Contents/Frameworks/Sparkle.framework"
