#!/usr/bin/env bash
# Compile the window-shadow shader for Qt Quick (needs qt6-shadertools). The
# result is checked in, so this only runs after editing shaders/shadow.frag.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
/usr/lib/qt6/bin/qsb --qt6 -o "$REPO/shadow.frag.qsb" "$REPO/shaders/shadow.frag"
echo "built shadow.frag.qsb"
