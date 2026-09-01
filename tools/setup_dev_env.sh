#!/usr/bin/env bash
# ==============================================================================
# Arma AI - Developer Environment Setup Script
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Setting up Arma AI Developer Environment ==="
echo "Repo root: ${REPO_ROOT}"

# 1. Setup VS Code Configuration
VSCODE_DIR="${REPO_ROOT}/.vscode"
mkdir -p "${VSCODE_DIR}"

if [ -f "${SCRIPT_DIR}/vscode/settings.json" ]; then
    cp -v "${SCRIPT_DIR}/vscode/settings.json" "${VSCODE_DIR}/settings.json"
fi

if [ -f "${SCRIPT_DIR}/vscode/extensions.json" ]; then
    cp -v "${SCRIPT_DIR}/vscode/extensions.json" "${VSCODE_DIR}/extensions.json"
fi

echo "✓ VS Code settings and extension recommendations configured."

# 2. Check for HEMTT
if command -v hemtt >/dev/null 2>&1; then
    echo "✓ HEMTT detected: $(hemtt --version 2>/dev/null || echo 'installed')"
else
    echo "! HEMTT not found in PATH."
    echo "  To install HEMTT on macOS/Linux:"
    echo "    cargo install hemtt"
    echo "  Or download from: https://github.com/BrettMayson/HEMTT/releases"
fi

echo "=== Setup Complete ==="
