#!/usr/bin/env python3

import json
import subprocess
import sys
import threading


LOG_PATH = "/tmp/xcode-mcp-schema-fixes.log"


def json_type(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    if isinstance(value, dict):
        return "object"
    return None


def sanitize_schema(node, path="$"):
    fixes = []
    if isinstance(node, dict):
        enum_values = node.get("enum")
        declared_type = node.get("type")
        if isinstance(enum_values, list) and enum_values and declared_type is not None:
            declared_types = (
                {declared_type} if isinstance(declared_type, str) else set(declared_type)
            )
            enum_types = {json_type(value) for value in enum_values}
            enum_types.discard(None)
            if enum_types and not enum_types.issubset(declared_types):
                replacement = (
                    next(iter(enum_types)) if len(enum_types) == 1 else sorted(enum_types)
                )
                node["type"] = replacement
                fixes.append({"path": path, "from": declared_type, "to": replacement})

        for key, value in node.items():
            fixes.extend(sanitize_schema(value, f"{path}.{key}"))
    elif isinstance(node, list):
        for index, value in enumerate(node):
            fixes.extend(sanitize_schema(value, f"{path}[{index}]"))
    return fixes


def sanitize_message(raw_line):
    try:
        message = json.loads(raw_line)
    except json.JSONDecodeError:
        return raw_line

    tools = message.get("result", {}).get("tools")
    if not isinstance(tools, list):
        return raw_line

    log_entries = []
    for tool in tools:
        schema = tool.get("inputSchema")
        if not isinstance(schema, dict):
            continue
        for fix in sanitize_schema(schema):
            log_entries.append({"tool": tool.get("name"), **fix})

    if log_entries:
        with open(LOG_PATH, "a", encoding="utf-8") as log:
            for entry in log_entries:
                log.write(json.dumps(entry, separators=(",", ":")) + "\n")
        return (json.dumps(message, separators=(",", ":")) + "\n").encode()

    return raw_line


bridge = subprocess.Popen(
    ["/usr/bin/xcrun", "mcpbridge"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
)


def forward_requests():
    try:
        for line in sys.stdin.buffer:
            bridge.stdin.write(line)
            bridge.stdin.flush()
    except (BrokenPipeError, OSError):
        pass
    finally:
        try:
            bridge.stdin.close()
        except OSError:
            pass


request_thread = threading.Thread(target=forward_requests, daemon=True)
request_thread.start()

try:
    for line in bridge.stdout:
        sys.stdout.buffer.write(sanitize_message(line))
        sys.stdout.buffer.flush()
finally:
    bridge.terminate()
    try:
        bridge.wait(timeout=2)
    except subprocess.TimeoutExpired:
        bridge.kill()
        bridge.wait()
