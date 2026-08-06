#!/bin/zsh

# Xcode does not inherit the user's login-shell environment.
source "${ZDOTDIR:-$HOME}/.zprofile" >/dev/null 2>&1

SCRIPT_DIRECTORY="${0:A:h}"
export OPENCODE_CONFIG="${SCRIPT_DIRECTORY}/opencode-meta-muse-spark.json"

# Xcode 27 beta advertises one malformed MCP tool schema. Route only the
# xcrun mcpbridge connection through the narrow schema-correcting proxy.
/usr/bin/tee -a /tmp/meta-muse-xcode-acp-in.log | \
  /usr/bin/python3 "${SCRIPT_DIRECTORY}/xcode-acp-request-filter.py" | \
  "$HOME/.opencode/bin/opencode" acp \
    2>>/tmp/meta-muse-xcode-acp-err.log | \
  /usr/bin/tee -a /tmp/meta-muse-xcode-acp-out.log
