#!/usr/bin/env python3

import json
from pathlib import Path
import sys


PROXY_COMMAND = "/usr/bin/python3"
PROXY_SCRIPT = str(Path(__file__).with_name("xcode-mcp-schema-proxy.py"))


for raw_line in sys.stdin:
    line = raw_line
    try:
        message = json.loads(raw_line)
        if message.get("method") in {"session/new", "session/resume"}:
            servers = message.get("params", {}).get("mcpServers", [])
            for server in servers:
                if server.get("command") == "xcrun" and server.get("args") == ["mcpbridge"]:
                    server["command"] = PROXY_COMMAND
                    server["args"] = [PROXY_SCRIPT]
        line = json.dumps(message, separators=(",", ":")) + "\n"
    except (AttributeError, json.JSONDecodeError, TypeError):
        pass

    sys.stdout.write(line)
    sys.stdout.flush()
