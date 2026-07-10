// @vitest-environment node
import { describe, it, expect, beforeEach, afterEach } from 'vitest'
import { mkdtempSync, writeFileSync, rmSync, chmodSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

import { spawnCli, CliError } from './cli'

let dir: string
const originalBin = process.env.CODEBURN_BIN

/** Writes an executable node script and points CODEBURN_BIN at it. */
function fakeBin(name: string, body: string): string {
  const p = join(dir, name)
  writeFileSync(p, `#!/usr/bin/env node\n${body}\n`, { mode: 0o755 })
  chmodSync(p, 0o755)
  process.env.CODEBURN_BIN = p
  return p
}

beforeEach(() => {
  dir = mkdtempSync(join(tmpdir(), 'codeburn-cli-'))
})

afterEach(() => {
  if (originalBin === undefined) delete process.env.CODEBURN_BIN
  else process.env.CODEBURN_BIN = originalBin
  rmSync(dir, { recursive: true, force: true })
})

describe('spawnCli', () => {
  it('resolves parsed JSON on success', async () => {
    fakeBin('ok.js', 'process.stdout.write(JSON.stringify({ ok: 1 }))')
    await expect(spawnCli(['status'])).resolves.toEqual({ ok: 1 })
  })

  it('rejects with kind "nonzero" on a non-zero exit', async () => {
    fakeBin('fail.js', 'process.stderr.write("boom"); process.exit(2)')
    await expect(spawnCli(['status'])).rejects.toMatchObject({ kind: 'nonzero' } satisfies Partial<CliError>)
  })

  it('rejects with kind "bad-json" on non-JSON stdout', async () => {
    fakeBin('garbage.js', 'process.stdout.write("not json at all")')
    await expect(spawnCli(['status'])).rejects.toMatchObject({ kind: 'bad-json' })
  })

  it('rejects with kind "timeout" when the binary hangs', async () => {
    fakeBin('hang.js', 'setInterval(() => {}, 1000)')
    await expect(spawnCli(['status'], { timeoutMs: 150 })).rejects.toMatchObject({ kind: 'timeout' })
  })

  it('rejects with kind "not-found" when no binary resolves', async () => {
    delete process.env.CODEBURN_BIN
    process.env.CODEBURN_PATH_DIRS = '' // force an empty search space
    process.env.CODEBURN_CLI_PATH_FILE = join(dir, 'no-such-persisted-path')
    try {
      await expect(spawnCli(['status'])).rejects.toMatchObject({ kind: 'not-found' })
    } finally {
      delete process.env.CODEBURN_PATH_DIRS
      delete process.env.CODEBURN_CLI_PATH_FILE
    }
  })
})
