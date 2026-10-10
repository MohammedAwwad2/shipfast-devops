#!/usr/bin/env bash
set -euo pipefail

MIN_NODE_MAJOR=22
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

cd "$ROOT_DIR"

if ! command -v node >/dev/null 2>&1; then
    log "Node.js not found. Installing nvm and Node.js LTS..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    nvm install --lts
    nvm alias default 'lts/*'
fi

NODE_MAJOR="$(node --version | sed 's/^v//' | cut -d. -f1)"

if [[ "$NODE_MAJOR" -lt "$MIN_NODE_MAJOR" ]]; then
    log "ERROR: Node.js ${MIN_NODE_MAJOR}+ required, found $(node --version)"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    log "ERROR: npm is not installed. Reinstall Node.js with nvm."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    log "WARNING: Docker is not installed. Install it from https://docs.docker.com/engine/install/"
else
    log "Docker: $(docker --version)"
fi

if ! command -v git >/dev/null 2>&1; then
    log "ERROR: Git is not installed. Install it using: sudo apt install git"
    exit 1
fi

log "Node.js: $(node --version)"
log "npm: $(npm --version)"
log "Git: $(git --version)"

log "Installing app dependencies..."
npm --prefix "$ROOT_DIR/app" ci
log "Bootstrap complete. Start the app with: cd app && npm start"
