# Use Kimi K3 in Xcode 27 with OpenCode

This guide documents a working Kimi K3 integration for Xcode 27 through OpenCode and the Agent Client Protocol (ACP). It also covers two Xcode 27 beta compatibility problems that can prevent an otherwise valid OpenCode installation from working:

1. Xcode reports `This provider requires authentication` before it creates the ACP session.
2. After authentication succeeds, Kimi rejects an invalid JSON Schema supplied by one of Xcode's MCP tools.

The configuration in this guide was verified on July 19, 2026 with:

- Xcode 27.0 beta, build `27A5218f`
- OpenCode `1.18.3`
- Provider and model ID `moonshotai/kimi-k3`
- A successful Xcode response of `KIMI_XCODE_OK`
- An ACP result with `stopReason: end_turn`

These workarounds are specific to the tested Xcode 27 beta. Recheck whether they are still necessary after installing a newer Xcode or OpenCode release.

## Architecture

The request path is:

```text
Xcode coding assistant
    -> custom ACP wrapper
    -> OpenCode ACP server
    -> Moonshot AI / Kimi K3
```

Xcode also gives the agent access to its project tools through an MCP server:

```text
OpenCode
    -> schema-correcting MCP proxy
    -> xcrun mcpbridge
    -> XcodeRead, XcodeWrite, XcodeGlob, XcodeBuild, and other Xcode tools
```

Apple supports adding custom ACP agents from Xcode's Intelligence settings. OpenCode supports ACP by running `opencode acp`, which starts a JSON-RPC subprocess over standard input and output.

- [Apple: Setting up coding intelligence](https://developer.apple.com/documentation/xcode/setting-up-coding-intelligence)
- [OpenCode: ACP support](https://opencode.ai/docs/acp/)
- [ACP authentication methods](https://agentclientprotocol.com/rfds/auth-methods)
- [Kimi K3 model and pricing](https://platform.kimi.ai/docs/pricing/chat-k3)

## Why the Compatibility Layer Is Needed

### Xcode's custom-agent authentication gate

OpenCode advertises an ACP authentication method named `opencode-login`. Its provider credentials are already managed by OpenCode, but the tested Xcode 27 beta still requires its own stored ACP credential record before it sends `session/new`.

The custom-agent settings UI does not expose a login button that can create this record. Without it, Xcode stops after ACP initialization and displays:

```text
Failed: This provider requires authentication.
```

The workaround enables Xcode's file-backed credential store and creates a non-secret marker containing only:

```json
{"methodId":"opencode-login"}
```

The Kimi API key is not copied into this file. It remains in OpenCode's credential store.

### Xcode's malformed `XcodeMV` tool schema

After the authentication gate was fixed, Xcode successfully created the OpenCode session and connected its `xcode-tools` MCP server. Kimi then rejected the request with:

```text
Invalid request: tools.function.parameters is not a valid moonshot flavored json schema
At path 'properties.operation.enum': enum value (move) does not match any type in [object]
```

The invalid schema came from the `XcodeMV` tool. Xcode declared `operation` as an `object`, but its enum values such as `move` are strings.

The MCP proxy installed below makes the narrow correction:

```json
{"tool":"XcodeMV","path":"$.properties.operation","from":"object","to":"string"}
```

The proxy preserves the Xcode tool instead of disabling all Xcode MCP tools. It only changes a declared JSON type when that type conflicts with the concrete values in the same enum.

## Prerequisites

- Xcode 27 on macOS
- A Kimi API Platform account with API access and sufficient balance
- A Kimi API key
- OpenCode `1.18.3` or a newer compatible release
- Python 3 supplied by Xcode or macOS at `/usr/bin/python3`

Create and manage Kimi API keys in the [Kimi API Platform console](https://platform.kimi.ai/console/account). Never put the API key in this repository, an Xcode project file, or any script shown in this guide.

Kimi's current documentation describes K3 as a long-horizon coding and knowledge-work model with a 1M-token context window, tool calling, automatic context caching, and always-on reasoning. Consult the [official K3 page](https://platform.kimi.ai/docs/pricing/chat-k3) for current capabilities and pricing.

## 1. Install and Verify OpenCode

Install OpenCode using its official installer:

```bash
curl -fsSL https://opencode.ai/install | bash
```

Check every installed copy before configuring Xcode:

```bash
which -a opencode
opencode --version
```

The verified setup uses:

```text
~/.opencode/bin/opencode
```

Use the newest working binary consistently. During diagnosis, `/opt/homebrew/bin/opencode` was an older `1.17.7` installation and failed against a newer OpenCode database with `no such column replacement_seq`. The `~/.opencode/bin/opencode` binary was version `1.18.3` and worked.

## 2. Store the Kimi Credential in OpenCode

Run OpenCode's provider authentication flow:

```bash
~/.opencode/bin/opencode auth login
```

Select **Moonshot AI**, then paste the Kimi API key when prompted.

Confirm that OpenCode can see the credential:

```bash
~/.opencode/bin/opencode auth list
```

OpenCode's documentation recommends `opencode auth login` for provider credentials and uses the full `provider_id/model_id` form for model selection.

- [OpenCode provider configuration](https://opencode.ai/docs/providers)
- [OpenCode model configuration](https://opencode.ai/docs/models)

## 3. Make Kimi K3 the Default Model

Add the model to `~/.config/opencode/opencode.json`. If the file already contains other settings, merge the `model` property instead of replacing the complete file.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "moonshotai/kimi-k3"
}
```

Pinning the model matters because a custom ACP session may not use the model most recently selected in the OpenCode terminal interface.

Verify Kimi independently of Xcode:

```bash
~/.opencode/bin/opencode run \
  --model moonshotai/kimi-k3 \
  --format json \
  'Reply with exactly: KIMI_OK'
```

Do not continue until this command returns a valid Kimi response. If it fails here, the remaining problem is in the Kimi account, API key, OpenCode provider configuration, or model ID rather than Xcode.

## 4. Install the Xcode MCP Schema Proxy

Create `~/.opencode/xcode-mcp-schema-proxy.py` with the following content:

```python
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
            if isinstance(declared_type, str):
                declared_types = {declared_type}
            elif isinstance(declared_type, list):
                declared_types = set(declared_type)
            else:
                declared_types = set()
            enum_types = {json_type(value) for value in enum_values}
            enum_types.discard(None)
            if enum_types and not enum_types.issubset(declared_types):
                replacement = (
                    next(iter(enum_types))
                    if len(enum_types) == 1
                    else sorted(enum_types)
                )
                node["type"] = replacement
                fixes.append(
                    {"path": path, "from": declared_type, "to": replacement}
                )

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
```

Make it executable:

```bash
chmod 755 ~/.opencode/xcode-mcp-schema-proxy.py
```

## 5. Install the ACP Request Filter

Xcode normally tells OpenCode to launch this MCP server:

```json
{"command":"xcrun","args":["mcpbridge"]}
```

The request filter changes only that command so OpenCode launches the schema proxy, which then launches the real `xcrun mcpbridge` process. Xcode includes the MCP server configuration in both `session/new` and `session/resume`, so both methods must be filtered. Otherwise, reopening an existing conversation bypasses the proxy and produces JSON-RPC error `-32603`.

Create `~/.opencode/xcode-acp-request-filter.py`:

```python
#!/usr/bin/env python3

import json
from pathlib import Path
import sys


PROXY_COMMAND = "/usr/bin/python3"
PROXY_SCRIPT = str(Path.home() / ".opencode" / "xcode-mcp-schema-proxy.py")


for raw_line in sys.stdin:
    line = raw_line
    try:
        message = json.loads(raw_line)
        if message.get("method") in {"session/new", "session/resume"}:
            servers = message.get("params", {}).get("mcpServers", [])
            for server in servers:
                if (
                    server.get("command") == "xcrun"
                    and server.get("args") == ["mcpbridge"]
                ):
                    server["command"] = PROXY_COMMAND
                    server["args"] = [PROXY_SCRIPT]
        line = json.dumps(message, separators=(",", ":")) + "\n"
    except (AttributeError, json.JSONDecodeError, TypeError):
        pass

    sys.stdout.write(line)
    sys.stdout.flush()
```

Make it executable:

```bash
chmod 755 ~/.opencode/xcode-acp-request-filter.py
```

## 6. Install the Xcode ACP Wrapper

If an OpenCode wrapper already exists, preserve it before replacing it:

```bash
if [[ -f ~/.opencode/xcode-acp-wrapper.sh ]]; then
  cp -p \
    ~/.opencode/xcode-acp-wrapper.sh \
    ~/.opencode/xcode-acp-wrapper.sh.pre-kimi-k3-schema-fix
fi
```

Create `~/.opencode/xcode-acp-wrapper.sh`:

```zsh
#!/bin/zsh

# Adapt Xcode 27 beta's MCP schemas for strict Kimi validation.
OPENCODE_ROOT="${HOME}/.opencode"
LOG_DIR=/tmp

exec /usr/bin/tee -a "${LOG_DIR}/xcode-acp-in.log" | \
  /usr/bin/python3 "${OPENCODE_ROOT}/xcode-acp-request-filter.py" | \
  "${OPENCODE_ROOT}/bin/opencode" acp \
    2>>"${LOG_DIR}/xcode-acp-err.log" | \
  /usr/bin/tee -a "${LOG_DIR}/xcode-acp-out.log"
```

Make it executable and validate its syntax:

```bash
chmod 755 ~/.opencode/xcode-acp-wrapper.sh
/bin/zsh -n ~/.opencode/xcode-acp-wrapper.sh
```

This wrapper records ACP input, output, and errors in `/tmp` for troubleshooting. Those logs can contain prompts and project structure. Do not share them publicly. To avoid retaining ACP traffic after setup is stable, remove the two `tee` stages and connect the request filter directly to OpenCode.

## 7. Register OpenCode in Xcode 27

1. Open **Xcode → Settings → Intelligence**.
2. Under **Agents**, click **Add an Agent…**.
3. Configure the agent:

   | Field | Value |
   | --- | --- |
   | Name | `OpenCode` |
   | Executable | Absolute path to `~/.opencode/xcode-acp-wrapper.sh` |
   | Interpreter | Leave blank |
   | Arguments | Leave empty |
   | Environment Variables | Leave empty |

For example, the executable field should contain a fully expanded path such as:

```text
/Users/your-name/.opencode/xcode-acp-wrapper.sh
```

Do not use `~` in Xcode's executable field. Do not add the `acp` argument here because the wrapper already starts `opencode acp`.

4. Save the agent.

Xcode stores each custom ACP agent in a UUID-named property list under:

```text
~/Library/Developer/Xcode/CodingAssistant/ACP/
```

## 8. Create Xcode's Non-Secret Login Marker

Enable Xcode's file-backed CLI-agent credential store:

```bash
defaults write \
  com.apple.dt.Xcode \
  IDEChatUseFileForCLIAuthCredentialsStore \
  -bool true
```

Find the UUID belonging to the agent named `OpenCode`:

```zsh
AGENT_ID=$(
  for plist in "${HOME}"/Library/Developer/Xcode/CodingAssistant/ACP/*.plist; do
    if [[ "$(/usr/bin/plutil -extract name raw "${plist}" 2>/dev/null)" == "OpenCode" ]]; then
      /usr/bin/basename "${plist}" .plist
      break
    fi
  done
)

[[ -n "${AGENT_ID}" ]] || {
  echo "OpenCode agent plist not found. Add the agent in Xcode first."
  exit 1
}

echo "OpenCode agent ID: ${AGENT_ID}"
```

Create the marker with owner-only permissions:

```zsh
CREDENTIAL_DIRECTORY="${HOME}/Library/Developer/Xcode/CodingAssistant/ACP/${AGENT_ID}"

umask 077
/bin/mkdir -p "${CREDENTIAL_DIRECTORY}"
/usr/bin/printf '%s\n' \
  '{"methodId":"opencode-login"}' \
  > "${CREDENTIAL_DIRECTORY}/credentials.json"
/bin/chmod 600 "${CREDENTIAL_DIRECTORY}/credentials.json"
```

Validate it:

```bash
defaults read \
  com.apple.dt.Xcode \
  IDEChatUseFileForCLIAuthCredentialsStore

jq -e \
  '.methodId == "opencode-login" and (keys | length == 1)' \
  "${CREDENTIAL_DIRECTORY}/credentials.json"
```

The first command should print `1`; the second should print `true`.

Quit and reopen Xcode after creating the marker so it reloads the custom agent's credentials before starting a new conversation.

## 9. Use Kimi K3 in Xcode

1. Open an Xcode project or workspace.
2. Show the coding assistant navigator.
3. Click **New Conversation**.
4. Select **OpenCode** under **Agents**.
5. Enter a simple verification prompt:

   ```text
   Reply with exactly: KIMI_XCODE_OK
   ```

6. Xcode may show permission dialogs the first time the integration runs:

   - Allow the OpenCode binary at `~/.opencode/bin/opencode` to access Xcode.
   - Allow the Apple-signed Python process used by the schema proxy. In the tested Xcode beta, its path was inside `Xcode-beta.app/Contents/Developer/Library/Frameworks/Python3.framework`.

Only approve the dialogs when the paths match the components configured in this guide.

A successful conversation displays:

```text
KIMI_XCODE_OK
```

The verified ACP exchange ended with:

```json
{
  "result": {
    "stopReason": "end_turn"
  }
}
```

After setup, use OpenCode in Xcode like any other coding agent. It can use Xcode's project-aware tools, OpenCode's built-in tools, project instructions from `AGENTS.md`, configured MCP servers, and the permission system. Review Xcode's **Intelligence → Permissions** settings before allowing destructive commands or broad project changes.

## Installed Components and Responsibilities

| Path | Purpose |
| --- | --- |
| `~/.config/opencode/opencode.json` | Pins `moonshotai/kimi-k3` as the model |
| OpenCode's credential store | Holds the actual Kimi API key |
| `~/.opencode/xcode-acp-wrapper.sh` | Starts the ACP request filter and OpenCode |
| `~/.opencode/xcode-acp-request-filter.py` | Replaces only the Xcode `mcpbridge` launch command |
| `~/.opencode/xcode-mcp-schema-proxy.py` | Forwards MCP traffic and corrects enum/type schema conflicts |
| `~/Library/Developer/Xcode/CodingAssistant/ACP/<UUID>/credentials.json` | Tells Xcode to use OpenCode's `opencode-login` ACP method |
| `~/.opencode/xcode-acp-wrapper.sh.pre-kimi-k3-schema-fix` | Preserves the previous wrapper for rollback, when one existed |

## Security and Privacy Notes

- The Xcode credential marker contains no Kimi API key, bearer token, or account information.
- The marker should remain mode `0600`, readable and writable only by its owner.
- `IDEChatUseFileForCLIAuthCredentialsStore` changes credential storage for Xcode CLI agents, not just OpenCode. Reassess this workaround after an Xcode update.
- The schema proxy does not need the Kimi API key. It only sees local MCP JSON-RPC traffic between OpenCode and Xcode.
- The proxy changes schemas only when an enum's concrete JSON value types contradict the schema's declared type.
- The diagnostic `tee` stages in the wrapper write ACP traffic to `/tmp`. Remove them if you do not need persistent troubleshooting logs.
- Xcode sends project context to the selected third-party model. Do not use this configuration with repositories whose policies prohibit sending source code to Kimi or another external provider.

## Troubleshooting

### `This provider requires authentication`

Confirm all of the following:

```bash
~/.opencode/bin/opencode auth list

defaults read \
  com.apple.dt.Xcode \
  IDEChatUseFileForCLIAuthCredentialsStore

rg --files \
  "${HOME}/Library/Developer/Xcode/CodingAssistant/ACP" | \
  rg '/credentials\.json$'
```

Then verify that the marker is in the directory matching the UUID of the `OpenCode` plist and contains exactly the `opencode-login` method ID.

This error occurs before `session/new`. Re-running `opencode auth login` alone does not repair Xcode's missing marker in the affected beta.

### Moonshot reports an invalid schema containing `operation.enum` and `move`

The ACP wrapper or MCP proxy is not active. Check:

```bash
/bin/zsh -n ~/.opencode/xcode-acp-wrapper.sh
/usr/bin/python3 -m py_compile \
  ~/.opencode/xcode-acp-request-filter.py \
  ~/.opencode/xcode-mcp-schema-proxy.py

tail -n 20 /tmp/xcode-mcp-schema-fixes.log
```

The schema log should contain an `XcodeMV` correction from `object` to `string`.

### JSON-RPC internal error `-32603` after reopening a conversation

Inspect the error details in `/tmp/xcode-acp-out.log`. If they mention the invalid `properties.operation.enum` schema, Xcode resumed an existing conversation without the schema proxy. Confirm that `~/.opencode/xcode-acp-request-filter.py` handles both ACP methods:

```python
if message.get("method") in {"session/new", "session/resume"}:
    ...
```

Quit and reopen Xcode after updating the filter, then retry the conversation. A new conversation is not required once the resume path is filtered.

### OpenCode reports `no such column replacement_seq`

Xcode is launching an older OpenCode binary against a database created by a newer release. Compare all installed copies:

```bash
which -a opencode
/opt/homebrew/bin/opencode --version
~/.opencode/bin/opencode --version
```

Update the wrapper to use the newest working binary.

### Xcode launches OpenCode but uses the wrong model

Pin the full model ID in `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "moonshotai/kimi-k3"
}
```

Then inspect OpenCode's log for the actual provider and model:

```bash
rg 'providerID=moonshotai modelID=kimi-k3' \
  ~/.local/share/opencode/log/opencode.log
```

### `401 Unauthorized` or provider authentication errors

Run `opencode auth login` again and select **Moonshot AI**. Confirm that the API key belongs to the Kimi API Platform account and that the account has sufficient balance.

### Agent fails to launch

- Xcode's Executable field must contain an absolute path.
- The wrapper must be executable.
- Leave Xcode's Arguments field empty when using this wrapper.
- Confirm that `/usr/bin/python3`, `/usr/bin/xcrun`, and `~/.opencode/bin/opencode` exist.

## Diagnostic Files

| File | Contents |
| --- | --- |
| `/tmp/xcode-acp-in.log` | ACP requests from Xcode to OpenCode |
| `/tmp/xcode-acp-out.log` | ACP responses and session updates from OpenCode |
| `/tmp/xcode-acp-err.log` | OpenCode ACP errors |
| `/tmp/xcode-mcp-schema-fixes.log` | Tool name, schema path, and type correction only |
| `~/.local/share/opencode/log/opencode.log` | OpenCode runtime, provider, model, and request errors |

These files may contain project paths, project structure, and prompt content. Redact them before sharing excerpts.

## Roll Back the Workaround

Use the exact OpenCode agent UUID found earlier. Do not delete the entire `CodingAssistant` or `ACP` directory.

Restore a preserved wrapper, if available:

```zsh
if [[ -f ~/.opencode/xcode-acp-wrapper.sh.pre-kimi-k3-schema-fix ]]; then
  cp -p \
    ~/.opencode/xcode-acp-wrapper.sh.pre-kimi-k3-schema-fix \
    ~/.opencode/xcode-acp-wrapper.sh
fi
```

Disable the file-backed credential store:

```bash
defaults delete \
  com.apple.dt.Xcode \
  IDEChatUseFileForCLIAuthCredentialsStore
```

Remove only the OpenCode marker and adapter files:

```zsh
[[ -n "${AGENT_ID}" ]] || {
  echo "AGENT_ID is empty; stopping rollback."
  exit 1
}

/bin/rm \
  "${HOME}/Library/Developer/Xcode/CodingAssistant/ACP/${AGENT_ID}/credentials.json"

/bin/rm \
  "${HOME}/.opencode/xcode-acp-request-filter.py" \
  "${HOME}/.opencode/xcode-mcp-schema-proxy.py"
```

Restart Xcode after rolling back.

## Result

With the authentication marker and schema adapter installed, Xcode 27 can:

1. Initialize the OpenCode ACP process.
2. Send `authenticate` using `opencode-login`.
3. Create an OpenCode session with Xcode's MCP server.
4. Present valid Xcode tool schemas to Kimi K3.
5. Complete Kimi K3 prompts inside Xcode's coding assistant.
