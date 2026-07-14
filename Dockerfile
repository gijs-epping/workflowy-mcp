# syntax=docker/dockerfile:1
#
# Workflowy MCP server, backed by the `wf` CLI (https://github.com/rodolfo-terriquez/workflowy-cli).
# Replaces the previous custom Node/better-sqlite3 server. Domain-specific tools
# (daily_review, inbox_triage, insert_content, manage_procedures, resolve_link,
# node_at_path, export_subtree, mark_important, list_shortcuts) have no equivalent
# in `wf` yet and are tracked for a follow-up port on top of `wf`'s CLI/cache.

# ── Stage 1: fetch the wf binary ────────────────────────────────
FROM debian:bookworm-slim AS wf-install

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Pin the version explicitly in production so image rebuilds are reproducible.
ARG WF_VERSION=latest
RUN if [ "$WF_VERSION" = "latest" ]; then \
      curl -fsSL https://github.com/rodolfo-terriquez/workflowy-cli/releases/latest/download/install.sh | WF_INSTALL_DIR=/usr/local/bin bash; \
    else \
      curl -fsSL https://github.com/rodolfo-terriquez/workflowy-cli/releases/latest/download/install.sh | WF_VERSION="$WF_VERSION" WF_INSTALL_DIR=/usr/local/bin bash; \
    fi

# ── Stage 2: runtime ─────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates socat \
    && rm -rf /var/lib/apt/lists/*

COPY --from=wf-install /usr/local/bin/wf /usr/local/bin/wf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/wf

ENV HOME=/root
ENV WF_MCP_PORT=3399
ENV WF_MCP_PUBLIC_PORT=3001

# ~/.workflowy holds config.json (API key) and the per-account SQLite cache —
# must be a persistent volume or every restart requires a re-login + full resync.
VOLUME ["/root/.workflowy"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wf account:current --agent || exit 1

EXPOSE 3001

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
