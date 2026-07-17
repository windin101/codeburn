# Zoo Code

Zoo Code VS Code extension (`zoocodeorganization.zoo-code`).

- **Source:** `src/providers/zoo-code.ts`
- **Loading:** eager (`src/providers/index.ts`)
- **Test:** `tests/providers/zoo-code.test.ts`

## Where it reads from

VS Code extension globalStorage for `zoocodeorganization.zoo-code`.

| Source | Path |
|---|---|
| Task history | `~/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/tasks/<taskId>/history_item.json` |
| Event stream | `~/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/tasks/<taskId>/ui_messages.json` |
| Task index | `~/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/tasks/_index.json` (not used directly) |

Also checks `Code - Insiders` and `VSCodium` paths on Linux.

## Storage format

Per-task directories under `tasks/`. Each task directory contains:

```
tasks/<taskId>/
  history_item.json    # session totals written by Zoo Code
  ui_messages.json     # event stream (tools, MCP calls, API requests)
  api_conversation_history.json  # full prompt history (not used)
  checkpoints/         # checkpoint snapshots (not used)
```

### history_item.json schema

```json
{
  "id": "019f6a35-eced-75fb-8f63-95d2794e83f6",
  "ts": 1784193380677,
  "task": "user's initial message",
  "tokensIn": 58309,
  "tokensOut": 622,
  "cacheWrites": 0,
  "cacheReads": 0,
  "totalCost": 0.024342248,
  "workspace": "/home/user/myproject",
  "mode": "code",
  "apiConfigName": "Claude Sonnet"
}
```

### ui_messages.json tool entries

Regular tool calls appear as `type=ask, ask=tool`:
```json
{ "type": "ask", "ask": "tool", "text": "{\"tool\":\"readFile\",\"path\":\"/some/file\"}", "ts": 1784193380677 }
```

MCP tool calls appear as `type=ask, ask=use_mcp_server`:
```json
{ "type": "ask", "ask": "use_mcp_server", "text": "{\"type\":\"use_mcp_tool\",\"serverName\":\"outline\",\"toolName\":\"list_collections\",\"arguments\":\"{}\"}", "ts": 1784193380677 }
```

## What we extract

| codeburn field | Zoo Code source |
|---|---|
| `inputTokens` | `history_item.tokensIn` |
| `outputTokens` | `history_item.tokensOut` |
| `cacheCreationInputTokens` | `history_item.cacheWrites` |
| `cacheReadInputTokens` | `history_item.cacheReads` |
| `costUSD` | `history_item.totalCost` |
| `model` | `history_item.apiConfigName` (e.g. `"Claude Architect"`) |
| `timestamp` | `history_item.ts` (epoch ms) |
| `userMessage` | `history_item.task` (first 500 chars) |
| `project` | `basename(history_item.workspace)` |
| `projectPath` | `history_item.workspace` |
| `tools` | `ask=tool` entries from `ui_messages.json` (deduplicated) |
| `tools` (MCP) | `ask=use_mcp_server` entries with `type=use_mcp_tool`, prefixed `mcp__<server>__<tool>` |

## Caching

None at the provider level. One `ParsedProviderCall` is emitted per task (session-level totals from `history_item.json`), not per API turn.

## Deduplication

Per `zoo-code:<taskId>`. The task ID is the directory name (UUID).

## Quirks worth knowing

- **Session-level totals, not per-turn.** Unlike the Cline-family parser which yields one entry per `api_req_started` event, this provider yields one entry per task using the pre-aggregated totals in `history_item.json`. This avoids double-counting and is more accurate.
- **`model` is the API config name, not the model ID.** Zoo Code stores the user-facing config name (e.g. `"Claude Architect"`, `"DeepSeek Workhorse"`) rather than the underlying model ID. This is what the user sees in the UI.
- **MCP calls are prefixed `mcp__<server>__<tool>`.** This distinguishes them from built-in Zoo Code tools in the tools breakdown.
- **Only `use_mcp_tool` type MCP entries are tracked.** `access_mcp_resource` entries are ignored.
- **Tools are deduplicated per session.** If `readFile` is called 20 times in a session, it appears once in the tools list.

## When fixing a bug here

1. Confirm the schema against a real Zoo Code install at `~/.config/Code/User/globalStorage/zoocodeorganization.zoo-code/tasks/`.
2. If costs are $0, check that `history_item.totalCost` is present; older Zoo Code versions may not write it.
3. If tokens look wrong, verify `history_item.tokensIn` vs the per-turn `api_req_started` entries in `ui_messages.json` — they should match the session total.
4. New fixtures go inline in `tests/providers/zoo-code.test.ts`.
