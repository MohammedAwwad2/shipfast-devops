
#!/bin/bash
set -euo pipefail

MIN_NODE_MAJOR=22

log() {
    echo "[$(date +%H:%M:%S)] $*"
}

# TODO 3: Change to the directory containing this script
cd "$(dirname "${BASH_SOURCE[0]}")"

# TODO 4: Install Node.js LTS with nvm if Node is missing
if ! command -v node >/dev/null 2>&1; then
    echo "Node not found. Installing nvm and Node LTS..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

    export NVM_DIR="$HOME/.nvm"
    source "$NVM_DIR/nvm.sh"

    nvm install --lts
    nvm alias default 'lts/*'
else
    echo "Node is already installed: $(node --version)"
fi

# TODO 5: Check the Node.js major version
NODE_MAJOR="$(node --version | sed 's/^v//' | cut -d. -f1)"

if [ "$NODE_MAJOR" -lt "$MIN_NODE_MAJOR" ]; then
    log "ERROR: Node.js ${MIN_NODE_MAJOR}+ required, found $(node --version)"
    exit 1
fi

# TODO 6: Log the installed Node.js version
log "Node.js: $(node --version)"


#
# TODO 7: Check Docker
if ! command -v docker >/dev/null 2>&1; then
    log "WARNING: Docker is not installed. Install it from https://docs.docker.com/engine/install/"
else
    log "Docker: $(docker --version)"
fi

# TODO 8: Check Git
if ! command -v git >/dev/null 2>&1; then
    log "ERROR: Git is not installed. Install it using: sudo apt install git"
    exit 1
else
    log "Git: $(git --version)"
fi