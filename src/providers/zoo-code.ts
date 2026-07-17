import { readdir, readFile, stat } from 'fs/promises'
import { basename, join } from 'path'
import { homedir } from 'os'

import type { Provider, SessionSource, SessionParser, ParsedProviderCall } from './types.js'

/// Zoo Code (zoocodeorganization.zoo-code) VS Code extension.
/// Stores one task per directory under globalStorage/zoocodeorganization.zoo-code/tasks/.
/// Each task directory contains:
///   history_item.json          – session totals (tokensIn, tokensOut, cacheReads, cacheWrites,
///                                totalCost, workspace, task, mode, apiConfigName)
///   ui_messages.json           – event stream with ask=tool and ask=use_mcp_server entries
///   api_conversation_history.json – full prompt history; contains <model>...</model> tag
///
/// Token counts and cost come from history_item.json (exact, written by Zoo Code itself).
/// Model ID comes from api_conversation_history.json <model> tag (e.g. anthropic/claude-sonnet-4.6).
/// Falls back to history_item.apiConfigName (e.g. "Claude Architect") if no tag found.
/// Tools and MCP calls are extracted from ui_messages.json.
/// Schema verified against Zoo Code 3.68.0 on 2026-07-17.

const EXTENSION_ID = 'zoocodeorganization.zoo-code'

type HistoryItem = {
  id: string
  ts?: number
  task?: string
  tokensIn?: number
  tokensOut?: number
  cacheWrites?: number
  cacheReads?: number
  totalCost?: number
  workspace?: string
  mode?: string
  apiConfigName?: string
}

type UiMessage = {
  type?: string
  say?: string
  ask?: string
  text?: string
  ts?: number
}

type ToolEntry = {
  tool?: string
}

type McpEntry = {
  type?: string
  serverName?: string
  toolName?: string
}

function getGlobalStoragePaths(homeDir = homedir()): string[] {
  return [
    join(homeDir, '.config', 'Code', 'User', 'globalStorage', EXTENSION_ID),
    join(homeDir, '.config', 'Code - Insiders', 'User', 'globalStorage', EXTENSION_ID),
    join(homeDir, '.config', 'VSCodium', 'User', 'globalStorage', EXTENSION_ID),
  ]
}

async function discoverTasks(baseDirs: string[]): Promise<SessionSource[]> {
  const sources: SessionSource[] = []
  const seen = new Set<string>()

  for (const baseDir of baseDirs) {
    const tasksDir = join(baseDir, 'tasks')
    let taskIds: string[]
    try {
      taskIds = await readdir(tasksDir)
    } catch {
      continue
    }

    for (const taskId of taskIds) {
      const taskDir = join(tasksDir, taskId)
      const dirStat = await stat(taskDir).catch(() => null)
      if (!dirStat?.isDirectory()) continue

      // Require history_item.json (has exact totals) and ui_messages.json (has events)
      const hiStat = await stat(join(taskDir, 'history_item.json')).catch(() => null)
      if (!hiStat?.isFile()) continue
      const uiStat = await stat(join(taskDir, 'ui_messages.json')).catch(() => null)
      if (!uiStat?.isFile()) continue

      if (seen.has(taskDir)) continue
      seen.add(taskDir)
      sources.push({ path: taskDir, project: EXTENSION_ID, provider: 'zoo-code' })
    }
  }

  return sources
}

const MODEL_TAG_RE = /<model>([^<]+)<\/model>/

async function extractModelId(taskDir: string, fallback: string): Promise<string> {
  try {
    const raw = await readFile(join(taskDir, 'api_conversation_history.json'), 'utf-8')
    const msgs = JSON.parse(raw) as Array<{ role?: string; content?: Array<{ text?: string }> }>
    if (!Array.isArray(msgs)) return fallback
    for (const msg of msgs) {
      if (msg.role !== 'user' || !Array.isArray(msg.content)) continue
      for (const block of msg.content) {
        if (typeof block.text !== 'string') continue
        const m = MODEL_TAG_RE.exec(block.text)
        if (m) {
          // Strip provider prefix (e.g. "anthropic/claude-sonnet-4.6" → "claude-sonnet-4.6")
          const raw = m[1].trim()
          return raw.includes('/') ? raw.split('/').pop()! : raw
        }
      }
    }
  } catch {}
  return fallback
}

async function extractToolsAndMcp(taskDir: string): Promise<{ tools: string[]; mcpCalls: string[] }> {
  let raw: string
  try {
    raw = await readFile(join(taskDir, 'ui_messages.json'), 'utf-8')
  } catch {
    return { tools: [], mcpCalls: [] }
  }

  let messages: UiMessage[]
  try {
    messages = JSON.parse(raw)
  } catch {
    return { tools: [], mcpCalls: [] }
  }

  if (!Array.isArray(messages)) return { tools: [], mcpCalls: [] }

  const toolSet = new Set<string>()
  const mcpSet = new Set<string>()

  for (const msg of messages) {
    if (msg.type !== 'ask' || !msg.text) continue

    if (msg.ask === 'tool') {
      try {
        const entry = JSON.parse(msg.text) as ToolEntry
        if (typeof entry.tool === 'string' && entry.tool) {
          toolSet.add(entry.tool)
        }
      } catch {}
    } else if (msg.ask === 'use_mcp_server') {
      try {
        const entry = JSON.parse(msg.text) as McpEntry
        if (entry.type === 'use_mcp_tool' && typeof entry.serverName === 'string' && typeof entry.toolName === 'string') {
          mcpSet.add(`${entry.serverName}__${entry.toolName}`)
        }
      } catch {}
    }
  }

  return { tools: [...toolSet], mcpCalls: [...mcpSet] }
}

function createParser(source: SessionSource, seenKeys: Set<string>): SessionParser {
  return {
    async *parse(): AsyncGenerator<ParsedProviderCall> {
      const taskDir = source.path
      const taskId = basename(taskDir)

      const dedupKey = `zoo-code:${taskId}`
      if (seenKeys.has(dedupKey)) return
      seenKeys.add(dedupKey)

      let hiRaw: string
      try {
        hiRaw = await readFile(join(taskDir, 'history_item.json'), 'utf-8')
      } catch {
        return
      }

      let hi: HistoryItem
      try {
        hi = JSON.parse(hiRaw)
      } catch {
        return
      }

      const tokensIn = hi.tokensIn ?? 0
      const tokensOut = hi.tokensOut ?? 0
      const cacheReads = hi.cacheReads ?? 0
      const cacheWrites = hi.cacheWrites ?? 0
      const costUSD = hi.totalCost ?? 0

      // Skip tasks with no token activity
      if (tokensIn === 0 && tokensOut === 0 && cacheReads === 0 && cacheWrites === 0) return

      const [{ tools, mcpCalls }, model] = await Promise.all([
        extractToolsAndMcp(taskDir),
        extractModelId(taskDir, hi.apiConfigName ?? 'zoo-code-auto'),
      ])

      // Combine regular tools and MCP calls into the tools array.
      // MCP calls are prefixed with "mcp__" to distinguish them from built-in tools.
      const allTools = [
        ...tools,
        ...mcpCalls.map(c => `mcp__${c}`),
      ]

      const timestamp = hi.ts ? new Date(hi.ts).toISOString() : ''
      const project = hi.workspace ? basename(hi.workspace) || hi.workspace : undefined
      const projectPath = hi.workspace ?? undefined
      const userMessage = (hi.task ?? '').slice(0, 500)

      yield {
        provider: 'zoo-code',
        model,
        inputTokens: tokensIn,
        outputTokens: tokensOut,
        cacheCreationInputTokens: cacheWrites,
        cacheReadInputTokens: cacheReads,
        cachedInputTokens: cacheReads,
        reasoningTokens: 0,
        webSearchRequests: 0,
        costUSD,
        tools: allTools,
        bashCommands: [],
        timestamp,
        speed: 'standard',
        deduplicationKey: dedupKey,
        userMessage,
        sessionId: taskId,
        project,
        projectPath,
      }
    },
  }
}

export function createZooCodeProvider(overrideDir?: string | string[]): Provider {
  return {
    name: 'zoo-code',
    displayName: 'Zoo Code',

    modelDisplayName(model: string): string {
      return model
    },

    toolDisplayName(rawTool: string): string {
      return rawTool
    },

    async discoverSessions(): Promise<SessionSource[]> {
      const baseDirs = overrideDir
        ? (Array.isArray(overrideDir) ? overrideDir : [overrideDir])
        : getGlobalStoragePaths()
      return discoverTasks(baseDirs)
    },

    createSessionParser(source: SessionSource, seenKeys: Set<string>): SessionParser {
      return createParser(source, seenKeys)
    },
  }
}

export const zooCode = createZooCodeProvider()
