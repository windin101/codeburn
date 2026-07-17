import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdtemp, mkdir, writeFile, rm } from 'fs/promises'
import { join } from 'path'
import { tmpdir } from 'os'

import { zooCode, createZooCodeProvider } from '../../src/providers/zoo-code.js'
import type { ParsedProviderCall } from '../../src/providers/types.js'

let tmpDir: string

function makeHistoryItem(opts: {
  id?: string
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
}): string {
  return JSON.stringify({
    id: opts.id ?? 'test-task-id',
    ts: opts.ts ?? 1700000001000,
    task: opts.task ?? 'test task',
    tokensIn: opts.tokensIn ?? 100,
    tokensOut: opts.tokensOut ?? 50,
    cacheWrites: opts.cacheWrites ?? 0,
    cacheReads: opts.cacheReads ?? 0,
    totalCost: opts.totalCost ?? 0.01,
    workspace: opts.workspace ?? '/home/user/myproject',
    mode: opts.mode ?? 'code',
    apiConfigName: opts.apiConfigName ?? 'Claude Sonnet',
  })
}

function makeUiMessages(entries: Array<{ ask?: string; say?: string; text?: string; ts?: number }>): string {
  return JSON.stringify(
    entries.map(e => ({
      type: e.ask ? 'ask' : 'say',
      ...(e.ask ? { ask: e.ask } : { say: e.say }),
      text: e.text ?? '',
      ts: e.ts ?? 1700000001000,
    })),
  )
}

async function writeTask(
  baseDir: string,
  taskId: string,
  historyItem: string,
  uiMessages: string,
): Promise<void> {
  const taskDir = join(baseDir, 'tasks', taskId)
  await mkdir(taskDir, { recursive: true })
  await writeFile(join(taskDir, 'history_item.json'), historyItem)
  await writeFile(join(taskDir, 'ui_messages.json'), uiMessages)
}

describe('zoo-code provider - parsing', () => {
  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'zoo-code-test-'))
  })

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true })
  })

  it('parses tokens and cost from history_item.json', async () => {
    await writeTask(
      tmpDir,
      'task-001',
      makeHistoryItem({
        tokensIn: 200,
        tokensOut: 100,
        cacheReads: 50,
        cacheWrites: 30,
        totalCost: 0.05,
        task: 'fix the bug',
        workspace: '/home/user/myproject',
        apiConfigName: 'Claude Sonnet',
      }),
      makeUiMessages([]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-001'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    const call = calls[0]!
    expect(call.provider).toBe('zoo-code')
    expect(call.inputTokens).toBe(200)
    expect(call.outputTokens).toBe(100)
    expect(call.cacheReadInputTokens).toBe(50)
    expect(call.cacheCreationInputTokens).toBe(30)
    expect(call.costUSD).toBe(0.05)
    expect(call.userMessage).toBe('fix the bug')
    expect(call.model).toBe('Claude Sonnet')
    expect(call.project).toBe('myproject')
    expect(call.projectPath).toBe('/home/user/myproject')
    expect(call.sessionId).toBe('task-001')
  })

  it('extracts regular tool names from ui_messages.json ask=tool entries', async () => {
    await writeTask(
      tmpDir,
      'task-002',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50 }),
      makeUiMessages([
        { ask: 'tool', text: JSON.stringify({ tool: 'readFile', path: '/some/file' }) },
        { ask: 'tool', text: JSON.stringify({ tool: 'searchFiles', regex: 'foo' }) },
        { ask: 'tool', text: JSON.stringify({ tool: 'readFile', path: '/other/file' }) }, // duplicate
      ]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-002'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    // readFile deduplicated, searchFiles present
    expect(calls[0]!.tools).toContain('readFile')
    expect(calls[0]!.tools).toContain('searchFiles')
    expect(calls[0]!.tools.filter(t => t === 'readFile')).toHaveLength(1)
  })

  it('extracts MCP calls from ui_messages.json ask=use_mcp_server entries', async () => {
    await writeTask(
      tmpDir,
      'task-003',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50 }),
      makeUiMessages([
        {
          ask: 'use_mcp_server',
          text: JSON.stringify({ type: 'use_mcp_tool', serverName: 'outline', toolName: 'list_collections', arguments: '{}' }),
        },
        {
          ask: 'use_mcp_server',
          text: JSON.stringify({ type: 'use_mcp_tool', serverName: 'cognee', toolName: 'recall', arguments: '{}' }),
        },
        {
          ask: 'use_mcp_server',
          text: JSON.stringify({ type: 'use_mcp_tool', serverName: 'outline', toolName: 'list_collections', arguments: '{}' }), // duplicate
        },
      ]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-003'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    expect(calls[0]!.tools).toContain('mcp__outline__list_collections')
    expect(calls[0]!.tools).toContain('mcp__cognee__recall')
    // deduplicated
    expect(calls[0]!.tools.filter(t => t === 'mcp__outline__list_collections')).toHaveLength(1)
  })

  it('combines regular tools and MCP calls in tools array', async () => {
    await writeTask(
      tmpDir,
      'task-004',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50 }),
      makeUiMessages([
        { ask: 'tool', text: JSON.stringify({ tool: 'readFile' }) },
        { ask: 'use_mcp_server', text: JSON.stringify({ type: 'use_mcp_tool', serverName: 'outline', toolName: 'read_document' }) },
      ]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-004'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    expect(calls[0]!.tools).toContain('readFile')
    expect(calls[0]!.tools).toContain('mcp__outline__read_document')
  })

  it('skips tasks with zero token activity', async () => {
    await writeTask(
      tmpDir,
      'task-005',
      makeHistoryItem({ tokensIn: 0, tokensOut: 0, cacheReads: 0, cacheWrites: 0 }),
      makeUiMessages([]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-005'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(0)
  })

  it('deduplicates across parser runs', async () => {
    await writeTask(
      tmpDir,
      'task-006',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50 }),
      makeUiMessages([]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-006'), project: 'zoo-code', provider: 'zoo-code' }
    const seenKeys = new Set<string>()
    const provider = createZooCodeProvider(tmpDir)

    const calls1: ParsedProviderCall[] = []
    for await (const call of provider.createSessionParser(source, seenKeys).parse()) calls1.push(call)

    const calls2: ParsedProviderCall[] = []
    for await (const call of provider.createSessionParser(source, seenKeys).parse()) calls2.push(call)

    expect(calls1).toHaveLength(1)
    expect(calls2).toHaveLength(0)
  })

  it('handles missing history_item.json gracefully', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-007')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(0)
  })

  it('handles invalid JSON in history_item.json gracefully', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-008')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'history_item.json'), 'not valid json')
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(0)
  })

  it('handles missing ui_messages.json gracefully (still yields token data)', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-009')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'history_item.json'), makeHistoryItem({ tokensIn: 100, tokensOut: 50 }))
    // no ui_messages.json

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    // Should still yield the call with empty tools
    expect(calls).toHaveLength(1)
    expect(calls[0]!.tools).toEqual([])
    expect(calls[0]!.inputTokens).toBe(100)
  })

  it('extracts model ID from api_conversation_history.json <model> tag', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-010a')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'history_item.json'), makeHistoryItem({ tokensIn: 100, tokensOut: 50, apiConfigName: 'Claude Architect' }))
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')
    await writeFile(
      join(taskDir, 'api_conversation_history.json'),
      JSON.stringify([
        { role: 'user', content: [{ type: 'text', text: 'hello\n<environment_details>\n<model>anthropic/claude-sonnet-4.6</model>\n</environment_details>' }] },
        { role: 'assistant', content: [{ type: 'text', text: 'hi' }] },
      ]),
    )

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    // Provider prefix stripped: "anthropic/claude-sonnet-4.6" → "claude-sonnet-4.6"
    expect(calls[0]!.model).toBe('claude-sonnet-4.6')
  })

  it('falls back to apiConfigName when no <model> tag in api_conversation_history.json', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-010b')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'history_item.json'), makeHistoryItem({ tokensIn: 100, tokensOut: 50, apiConfigName: 'Claude Architect' }))
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')
    await writeFile(
      join(taskDir, 'api_conversation_history.json'),
      JSON.stringify([{ role: 'user', content: [{ type: 'text', text: 'hello' }] }]),
    )

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    expect(calls[0]!.model).toBe('Claude Architect')
  })

  it('uses zoo-code-auto as fallback model when apiConfigName is missing', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-010c')
    await mkdir(taskDir, { recursive: true })
    await writeFile(
      join(taskDir, 'history_item.json'),
      JSON.stringify({ id: 'task-010c', tokensIn: 100, tokensOut: 50, totalCost: 0.01 }),
    )
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')

    const source = { path: taskDir, project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    expect(calls[0]!.model).toBe('zoo-code-auto')
  })

  it('sets correct timestamp from ts field', async () => {
    const ts = 1700000001000
    await writeTask(
      tmpDir,
      'task-011',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50, ts }),
      makeUiMessages([]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-011'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    expect(calls[0]!.timestamp).toBe(new Date(ts).toISOString())
  })

  it('ignores use_mcp_server entries that are not use_mcp_tool type', async () => {
    await writeTask(
      tmpDir,
      'task-012',
      makeHistoryItem({ tokensIn: 100, tokensOut: 50 }),
      makeUiMessages([
        {
          ask: 'use_mcp_server',
          text: JSON.stringify({ type: 'access_mcp_resource', serverName: 'outline', uri: 'some://uri' }),
        },
        {
          ask: 'use_mcp_server',
          text: JSON.stringify({ type: 'use_mcp_tool', serverName: 'cognee', toolName: 'recall' }),
        },
      ]),
    )

    const source = { path: join(tmpDir, 'tasks', 'task-012'), project: 'zoo-code', provider: 'zoo-code' }
    const calls: ParsedProviderCall[] = []
    const provider = createZooCodeProvider(tmpDir)
    for await (const call of provider.createSessionParser(source, new Set()).parse()) calls.push(call)

    expect(calls).toHaveLength(1)
    // access_mcp_resource is not tracked, only use_mcp_tool
    expect(calls[0]!.tools).toEqual(['mcp__cognee__recall'])
  })
})

describe('zoo-code provider - discovery', () => {
  beforeEach(async () => {
    tmpDir = await mkdtemp(join(tmpdir(), 'zoo-code-test-'))
  })

  afterEach(async () => {
    await rm(tmpDir, { recursive: true, force: true })
  })

  it('discovers task directories with both history_item.json and ui_messages.json', async () => {
    await writeTask(tmpDir, 'task-a', makeHistoryItem({}), makeUiMessages([]))
    await writeTask(tmpDir, 'task-b', makeHistoryItem({}), makeUiMessages([]))

    const provider = createZooCodeProvider(tmpDir)
    const sessions = await provider.discoverSessions()

    expect(sessions).toHaveLength(2)
    expect(sessions.every(s => s.provider === 'zoo-code')).toBe(true)
  })

  it('skips tasks without history_item.json', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-no-history')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'ui_messages.json'), '[]')

    const provider = createZooCodeProvider(tmpDir)
    const sessions = await provider.discoverSessions()

    expect(sessions).toHaveLength(0)
  })

  it('skips tasks without ui_messages.json', async () => {
    const taskDir = join(tmpDir, 'tasks', 'task-no-ui')
    await mkdir(taskDir, { recursive: true })
    await writeFile(join(taskDir, 'history_item.json'), makeHistoryItem({}))

    const provider = createZooCodeProvider(tmpDir)
    const sessions = await provider.discoverSessions()

    expect(sessions).toHaveLength(0)
  })

  it('returns empty for nonexistent directory', async () => {
    const provider = createZooCodeProvider('/nonexistent/path')
    const sessions = await provider.discoverSessions()
    expect(sessions).toHaveLength(0)
  })
})

describe('zoo-code provider - metadata', () => {
  it('has correct name and displayName', () => {
    expect(zooCode.name).toBe('zoo-code')
    expect(zooCode.displayName).toBe('Zoo Code')
  })

  it('passes through model display names', () => {
    expect(zooCode.modelDisplayName('claude-sonnet-4-5')).toBe('claude-sonnet-4-5')
  })

  it('passes through tool display names', () => {
    expect(zooCode.toolDisplayName('readFile')).toBe('readFile')
  })
})
