# Use Kimi K3 in Xcode 27

This is the short setup guide for using Kimi K3 in Xcode through OpenCode. It was verified with Xcode 27 beta and OpenCode `1.18.3`.

> Xcode 27 beta needs a small compatibility layer. The exact scripts are kept in the [full Kimi K3 guide](KimiK3Agent.md) so this page can stay short.

## 1. Get the Requirements

You need:

- Xcode 27
- A [Kimi API Platform](https://platform.kimi.ai/console/account) account and API key
- Python 3 at `/usr/bin/python3`
- OpenCode `1.18.3` or newer

Never save your Kimi API key in this repository or an Xcode project.

## 2. Install OpenCode and Sign In

```bash
curl -fsSL https://opencode.ai/install | bash
~/.opencode/bin/opencode auth login
```

Choose **Moonshot AI** and enter your Kimi API key. Then check the installation:

```bash
~/.opencode/bin/opencode --version
~/.opencode/bin/opencode auth list
```

## 3. Select Kimi K3

Add the following to `~/.config/opencode/opencode.json`. If the file already has settings, merge the `model` property instead of replacing everything.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "moonshotai/kimi-k3"
}
```

Test Kimi before configuring Xcode:

```bash
~/.opencode/bin/opencode run \
  --model moonshotai/kimi-k3 \
  'Reply with exactly: KIMI_OK'
```

Continue only after it returns `KIMI_OK`.

## 4. Install the Xcode 27 Compatibility Layer

Create these three files by copying the code from the linked sections:

1. [`~/.opencode/xcode-mcp-schema-proxy.py`](KimiK3Agent.md#4-install-the-xcode-mcp-schema-proxy)
2. [`~/.opencode/xcode-acp-request-filter.py`](KimiK3Agent.md#5-install-the-acp-request-filter)
3. [`~/.opencode/xcode-acp-wrapper.sh`](KimiK3Agent.md#6-install-the-xcode-acp-wrapper)

Make them executable and validate the wrapper:

```bash
chmod 755 \
  ~/.opencode/xcode-mcp-schema-proxy.py \
  ~/.opencode/xcode-acp-request-filter.py \
  ~/.opencode/xcode-acp-wrapper.sh

/bin/zsh -n ~/.opencode/xcode-acp-wrapper.sh
```

These scripts fix Xcode's invalid `XcodeMV` tool schema. The request filter must handle both `session/new` and `session/resume`.

## 5. Add OpenCode to Xcode

Open **Xcode → Settings → Intelligence → Agents → Add an Agent…**, then enter:

| Field | Value |
| --- | --- |
| Name | `OpenCode` |
| Executable | `/Users/your-name/.opencode/xcode-acp-wrapper.sh` |
| Interpreter | Leave blank |
| Arguments | Leave empty |
| Environment Variables | Leave empty |

Replace `your-name` with your macOS username. Use the full path—do not use `~` and do not add an `acp` argument.

## 6. Create Xcode's Login Marker

After saving the agent, paste this complete block into Terminal:

```zsh
defaults write \
  com.apple.dt.Xcode \
  IDEChatUseFileForCLIAuthCredentialsStore \
  -bool true

AGENT_ID=$(
  for plist in "${HOME}"/Library/Developer/Xcode/CodingAssistant/ACP/*.plist(N); do
    if [[ "$(/usr/bin/plutil -extract name raw "${plist}" 2>/dev/null)" == "OpenCode" ]]; then
      /usr/bin/basename "${plist}" .plist
      break
    fi
  done
)

[[ -n "${AGENT_ID}" ]] || {
  echo "OpenCode agent not found. Add it in Xcode first."
  exit 1
}

CREDENTIAL_DIRECTORY="${HOME}/Library/Developer/Xcode/CodingAssistant/ACP/${AGENT_ID}"
umask 077
/bin/mkdir -p "${CREDENTIAL_DIRECTORY}"
/usr/bin/printf '%s\n' '{"methodId":"opencode-login"}' \
  > "${CREDENTIAL_DIRECTORY}/credentials.json"
/bin/chmod 600 "${CREDENTIAL_DIRECTORY}/credentials.json"

echo "Xcode login marker created for ${AGENT_ID}."
```

This file contains only the OpenCode login method—not your Kimi API key.

## 7. Start Using Kimi K3

1. Quit and reopen Xcode.
2. Open the coding assistant navigator.
3. Click **New Conversation**.
4. Select **OpenCode** under **Agents**.
5. Send `Reply with exactly: KIMI_XCODE_OK`.
6. Allow `opencode` and the Apple-signed Python proxy to access Xcode when prompted.

If Xcode returns `KIMI_XCODE_OK`, the setup is complete. You can now ask Kimi to explain, edit, build, and test the open Xcode project.

## Quick Troubleshooting

- **This provider requires authentication:** repeat Step 6, then restart Xcode.
- **JSON-RPC error `-32603`:** confirm the request filter handles both `session/new` and `session/resume`, then restart Xcode.
- **`no such column replacement_seq`:** Xcode is using an old OpenCode binary. Make sure the wrapper uses `~/.opencode/bin/opencode`.
- **More detail:** see [KimiK3Agent.md](KimiK3Agent.md#troubleshooting).
