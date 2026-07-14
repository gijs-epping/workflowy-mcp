#!/bin/sh
# Entrypoint for the wf-cli based Workflowy MCP server.
#
# - Logs in on first boot (or whenever no config exists yet) using
#   WORKFLOWY_API_KEY, piped over stdin so the key never touches argv/history.
# - Runs a cache sync so reads are served from the local SQLite cache
#   from the very first request.
# - Starts wf mcp bound to loopback only (wf's own security default),
#   and spins up a tiny socat forwarder so the container's published
#   port (WF_MCP_PUBLIC_PORT, default 3001) actually reaches it. This
#   keeps the existing nginx reverse-proxy config (proxy_pass to
#   localhost:3001) working unchanged.
set -e

WF_MCP_PORT="${WF_MCP_PORT:-3399}"
WF_MCP_PUBLIC_PORT="${WF_MCP_PUBLIC_PORT:-3001}"
CONFIG_FILE="$HOME/.workflowy/config.json"

if [ -z "$WORKFLOWY_API_KEY" ] && [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: WORKFLOWY_API_KEY is not set and no existing wf config was found at $CONFIG_FILE" >&2
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "No wf config found at $CONFIG_FILE — logging in..."
  printf '%s' "$WORKFLOWY_API_KEY" | wf login --stdin
fi

echo "Syncing Workflowy cache..."
wf cache:sync || echo "WARN: cache:sync failed, continuing with existing cache (if any)"

echo "Starting TCP forwarder 0.0.0.0:${WF_MCP_PUBLIC_PORT} -> 127.0.0.1:${WF_MCP_PORT}"
socat TCP-LISTEN:"${WF_MCP_PUBLIC_PORT}",fork,reuseaddr TCP:127.0.0.1:"${WF_MCP_PORT}" &

echo "Starting wf mcp on 127.0.0.1:${WF_MCP_PORT}"
exec wf mcp --port "${WF_MCP_PORT}"
