#!/bin/bash
# prepare_reth_env.sh - Prepare reth runtime environment and export variables
# This script loads versions.env from a project directory, builds op-node and reth if needed,
# and sets up reth runtime environment variables
#
# Usage: prepare_reth_env.sh <project_directory>
# Example: prepare_reth_env.sh /path/to/base-node-deploy

set -eu

# Check if project directory is provided
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <project_directory>" >&2
    echo "Example: $0 /path/to/base-node-deploy" >&2
    exit 1
fi

PROJECT_DIR="$1"
CURRENT_DIR="$(pwd)"

# Validate project directory
if [[ ! -d "$PROJECT_DIR" ]]; then
    echo "Error: Project directory '$PROJECT_DIR' does not exist" >&2
    exit 1
fi

# Get absolute path
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
CURRENT_DIR="$(cd "$CURRENT_DIR" && pwd)"

echo "Project directory: $PROJECT_DIR"
echo "Current directory (where binaries will be placed): $CURRENT_DIR"

# Load versions.env from project directory
VERSIONS_ENV="$PROJECT_DIR/versions.env"
if [[ ! -f "$VERSIONS_ENV" ]]; then
    echo "Error: versions.env not found at $VERSIONS_ENV" >&2
    exit 1
fi

echo "Loading versions.env from $VERSIONS_ENV..."
# shellcheck source=/dev/null
. "$VERSIONS_ENV"

# Check required environment variables from versions.env
if [[ -z "${OP_NODE_REPO:-}" ]] || [[ -z "${OP_NODE_TAG:-}" ]] || [[ -z "${OP_NODE_COMMIT:-}" ]]; then
    echo "Error: OP_NODE_REPO, OP_NODE_TAG, or OP_NODE_COMMIT not set in versions.env" >&2
    exit 1
fi

if [[ -z "${BASE_RETH_NODE_REPO:-}" ]] || [[ -z "${BASE_RETH_NODE_TAG:-}" ]] || [[ -z "${BASE_RETH_NODE_COMMIT:-}" ]]; then
    echo "Error: BASE_RETH_NODE_REPO, BASE_RETH_NODE_TAG, or BASE_RETH_NODE_COMMIT not set in versions.env" >&2
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to build op-node
build_op_node() {
    echo "Building op-node..."
    
    # Check for Go
    if ! command_exists go; then
        echo "Error: Go is not installed. Please install Go 1.24 or later." >&2
        exit 1
    fi
    
    # Check for make
    if ! command_exists make; then
        echo "Error: make is not installed. Please install make." >&2
        exit 1
    fi
    
    # Install just if not available
    if ! command_exists just; then
        echo "Installing just..."
        curl -sSfL 'https://just.systems/install.sh' | bash -s -- --to "$HOME/.local/bin"
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Create temporary build directory
    BUILD_DIR="$CURRENT_DIR/.build-op-node"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Clone and checkout
    echo "Cloning op-node from $OP_NODE_REPO (tag: $OP_NODE_TAG)..."
    git clone "$OP_NODE_REPO" --branch "$OP_NODE_TAG" --single-branch .
    git switch -c "branch-$OP_NODE_TAG"
    
    # Verify commit
    ACTUAL_COMMIT=$(git rev-parse HEAD)
    if [[ "$ACTUAL_COMMIT" != "$OP_NODE_COMMIT" ]]; then
        echo "Error: Commit hash mismatch. Expected $OP_NODE_COMMIT, got $ACTUAL_COMMIT" >&2
        exit 1
    fi
    
    # Build op-node
    echo "Compiling op-node..."
    cd op-node
    make VERSION="$OP_NODE_TAG" op-node
    
    # Copy binary to current directory
    if [[ -f "bin/op-node" ]]; then
        cp "bin/op-node" "$CURRENT_DIR/op-node"
        chmod +x "$CURRENT_DIR/op-node"
        echo "op-node built successfully: $CURRENT_DIR/op-node"
    else
        echo "Error: op-node binary not found after build" >&2
        exit 1
    fi
    
    # Cleanup
    cd "$CURRENT_DIR"
    rm -rf "$BUILD_DIR"
}

# Function to build base-reth-node
build_reth() {
    echo "Building base-reth-node..."
    
    # Check for Rust and cargo
    if ! command_exists cargo; then
        echo "Error: Rust/Cargo is not installed. Please install Rust 1.88 or later." >&2
        exit 1
    fi
    
    # Create temporary build directory
    BUILD_DIR="$CURRENT_DIR/.build-reth"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Clone and checkout
    echo "Cloning base-reth-node from $BASE_RETH_NODE_REPO (tag: $BASE_RETH_NODE_TAG)..."
    git clone "$BASE_RETH_NODE_REPO" .
    git checkout "tags/$BASE_RETH_NODE_TAG"
    
    # Verify commit
    ACTUAL_COMMIT=$(git rev-parse HEAD)
    if [[ "$ACTUAL_COMMIT" != "$BASE_RETH_NODE_COMMIT" ]]; then
        echo "Error: Commit hash mismatch. Expected $BASE_RETH_NODE_COMMIT, got $ACTUAL_COMMIT" >&2
        exit 1
    fi
    
    # Build with maxperf profile
    echo "Compiling base-reth-node with maxperf profile (this may take a while)..."
    cargo build --bin base-reth-node --profile maxperf
    
    # Copy binary to current directory
    if [[ -f "target/maxperf/base-reth-node" ]]; then
        cp "target/maxperf/base-reth-node" "$CURRENT_DIR/base-reth-node"
        chmod +x "$CURRENT_DIR/base-reth-node"
        echo "base-reth-node built successfully: $CURRENT_DIR/base-reth-node"
    else
        echo "Error: base-reth-node binary not found after build" >&2
        exit 1
    fi
    
    # Cleanup
    cd "$CURRENT_DIR"
    rm -rf "$BUILD_DIR"
}

# Check for op-node binary
if [[ ! -f "$CURRENT_DIR/op-node" ]]; then
    echo "op-node not found in current directory, building..."
    build_op_node
else
    echo "op-node found: $CURRENT_DIR/op-node"
fi

# Check for base-reth-node binary
if [[ ! -f "$CURRENT_DIR/base-reth-node" ]]; then
    echo "base-reth-node not found in current directory, building..."
    build_reth
else
    echo "base-reth-node found: $CURRENT_DIR/base-reth-node"
fi

# Set default values for reth runtime environment variables
# These can be overridden by environment variables set before running this script

# Port configurations (with defaults from reth-entrypoint)
export RPC_PORT="${RPC_PORT:-8545}"
export WS_PORT="${WS_PORT:-8546}"
export AUTHRPC_PORT="${AUTHRPC_PORT:-8551}"
export METRICS_PORT="${METRICS_PORT:-6060}"
export DISCOVERY_PORT="${DISCOVERY_PORT:-30303}"
export P2P_PORT="${P2P_PORT:-30303}"

# Data directory and paths
export RETH_DATA_DIR="${RETH_DATA_DIR:-/data}"
export IPC_PATH="${IPC_PATH:-/data/reth.ipc}"
export RETH_LOG_FILE="${RETH_LOG_FILE:-/data/}"

# Binary paths (pointing to current directory)
export BINARY="$CURRENT_DIR/base-reth-node"
export OP_NODE_BINARY="$CURRENT_DIR/op-node"

# Required variables (will be checked but not set with defaults)
# RETH_CHAIN - must be set by user
# OP_NODE_L2_ENGINE_AUTH - must be set by user
# OP_NODE_L2_ENGINE_AUTH_RAW - must be set by user
# RETH_SEQUENCER_HTTP - must be set by user

# Optional variables
export RETH_FB_WEBSOCKET_URL="${RETH_FB_WEBSOCKET_URL:-}"
export RETH_PRUNING_ARGS="${RETH_PRUNING_ARGS:-}"

# Export all variables for use in child processes
echo ""
echo "=========================================="
echo "Reth environment variables prepared:"
echo "=========================================="
echo "  RPC_PORT=$RPC_PORT"
echo "  WS_PORT=$WS_PORT"
echo "  AUTHRPC_PORT=$AUTHRPC_PORT"
echo "  METRICS_PORT=$METRICS_PORT"
echo "  DISCOVERY_PORT=$DISCOVERY_PORT"
echo "  P2P_PORT=$P2P_PORT"
echo "  RETH_DATA_DIR=$RETH_DATA_DIR"
echo "  IPC_PATH=$IPC_PATH"
echo "  RETH_LOG_FILE=$RETH_LOG_FILE"
echo "  BINARY=$BINARY"
echo "  OP_NODE_BINARY=$OP_NODE_BINARY"
if [[ -n "$RETH_FB_WEBSOCKET_URL" ]]; then
    echo "  RETH_FB_WEBSOCKET_URL=$RETH_FB_WEBSOCKET_URL"
fi
if [[ -n "$RETH_PRUNING_ARGS" ]]; then
    echo "  RETH_PRUNING_ARGS=$RETH_PRUNING_ARGS"
fi

# Check for required variables (warnings only, not errors)
echo ""
echo "Required variables check:"
if [[ -z "${RETH_CHAIN:-}" ]]; then
    echo "  ⚠️  Warning: RETH_CHAIN is not set (required for reth-entrypoint)" >&2
else
    echo "  ✓ RETH_CHAIN=$RETH_CHAIN"
fi

if [[ -z "${OP_NODE_L2_ENGINE_AUTH:-}" ]]; then
    echo "  ⚠️  Warning: OP_NODE_L2_ENGINE_AUTH is not set (required for reth-entrypoint)" >&2
else
    echo "  ✓ OP_NODE_L2_ENGINE_AUTH=$OP_NODE_L2_ENGINE_AUTH"
fi

if [[ -z "${OP_NODE_L2_ENGINE_AUTH_RAW:-}" ]]; then
    echo "  ⚠️  Warning: OP_NODE_L2_ENGINE_AUTH_RAW is not set (required for reth-entrypoint)" >&2
else
    echo "  ✓ OP_NODE_L2_ENGINE_AUTH_RAW is set"
fi

if [[ -z "${RETH_SEQUENCER_HTTP:-}" ]]; then
    echo "  ⚠️  Warning: RETH_SEQUENCER_HTTP is not set (required for reth-entrypoint)" >&2
else
    echo "  ✓ RETH_SEQUENCER_HTTP=$RETH_SEQUENCER_HTTP"
fi

echo ""
echo "=========================================="
echo "Environment setup complete!"
echo "=========================================="
echo ""
echo "Binaries are available at:"
echo "  - op-node: $OP_NODE_BINARY"
echo "  - base-reth-node: $BINARY"
echo ""
echo "To use these variables in your current shell, source this script:"
echo "  source $0 $PROJECT_DIR"
echo ""
echo "Or to run reth-entrypoint:"
echo "  source $0 $PROJECT_DIR"
echo "  bash $PROJECT_DIR/reth/reth-entrypoint"
