import { hello, pair, pairRequest, fetchUsage } from './client.js'
import { loadOrCreateIdentity } from './identity.js'
import { pairingCode } from './pairing.js'
import { sanitizeForSharing } from './sanitize.js'
import type { DiscoveredDevice } from './discovery.js'
import type { UsageQuery } from './share-server.js'
import { getSharingDir, loadRemotes, saveRemotes, type RemoteDevice } from './store.js'
import type { CombinedUsage, DeviceSummary, MenubarPayload } from '../menubar-json.js'
import { formatCost } from '../currency.js'
import { renderTable } from '../text-table.js'
import { Chalk } from 'chalk'

export type { CombinedUsage, DeviceSummary } from '../menubar-json.js'

// Minimal shape we read from a device's usage payload (the menubar payload).
// Cache read/write come from the period-scoped `current` (like input/output)
// when the peer sends them; older peers only carry cache in the daily history,
// so we fall back to summing that (scoped by `window` when provided).
type DevicePayload = {
  current?: { cost?: number; calls?: number; sessions?: number; inputTokens?: number; outputTokens?: number; cacheReadTokens?: number; cacheWriteTokens?: number }
  history?: { daily?: Array<{ date?: string; cacheReadTokens?: number; cacheWriteTokens?: number }> }
}

type SummaryWindow = {
  start: string
  end: string
}

export type DeviceUsage = {
  id: string // stable unique id (cert fingerprint for remotes, 'local' for this device)
  name: string
  local: boolean
  payload?: DevicePayload
  error?: string
}

const zeroUsage = {
  cost: 0,
  calls: 0,
  sessions: 0,
  inputTokens: 0,
  outputTokens: 0,
  cacheCreateTokens: 0,
  cacheReadTokens: 0,
  totalTokens: 0,
}

function num(n: number | undefined): number {
  return n ?? 0
}

function summarizeOneDevice(d: DeviceUsage, window?: SummaryWindow): DeviceSummary {
  const error = d.error !== undefined ? d.error : d.payload === undefined ? 'no usage payload' : undefined
  if (error !== undefined || d.payload === undefined) {
    return {
      id: d.id,
      name: d.name,
      local: d.local,
      error,
      ...zeroUsage,
    }
  }

  const cur = d.payload.current
  const daily = (d.payload.history?.daily ?? []).filter((e) => {
    if (window === undefined) return true
    return e.date !== undefined && window.start <= e.date && e.date <= window.end
  })
  const inputTokens = num(cur?.inputTokens)
  const outputTokens = num(cur?.outputTokens)
  // Prefer the period-scoped `current` counts (issue #583); fall back to the
  // windowed daily history for older peers that don't send them. `??` keeps a
  // genuine 0 and only falls back when the field is absent.
  const cacheCreateTokens = cur?.cacheWriteTokens ?? daily.reduce((s, e) => s + num(e.cacheWriteTokens), 0)
  const cacheReadTokens = cur?.cacheReadTokens ?? daily.reduce((s, e) => s + num(e.cacheReadTokens), 0)
  return {
    id: d.id,
    name: d.name,
    local: d.local,
    cost: num(cur?.cost),
    calls: num(cur?.calls),
    sessions: num(cur?.sessions),
    inputTokens,
    outputTokens,
    cacheCreateTokens,
    cacheReadTokens,
    totalTokens: inputTokens + outputTokens + cacheCreateTokens + cacheReadTokens,
  }
}

export function summarizeDeviceUsage(results: DeviceUsage[], window?: SummaryWindow): CombinedUsage {
  const perDevice = results.map((d) => summarizeOneDevice(d, window))
  const combined = perDevice.reduce(
    (a, d) => {
      if (d.error !== undefined) return a
      return {
        cost: a.cost + d.cost,
        calls: a.calls + d.calls,
        sessions: a.sessions + d.sessions,
        inputTokens: a.inputTokens + d.inputTokens,
        outputTokens: a.outputTokens + d.outputTokens,
        cacheCreateTokens: a.cacheCreateTokens + d.cacheCreateTokens,
        cacheReadTokens: a.cacheReadTokens + d.cacheReadTokens,
        totalTokens: a.totalTokens + d.totalTokens,
        deviceCount: a.deviceCount,
        reachableCount: a.reachableCount + 1,
      }
    },
    { ...zeroUsage, deviceCount: perDevice.length, reachableCount: 0 },
  )
  return { perDevice, combined }
}

function parseHostPort(input: string, defaultPort: number): { host: string; port: number } {
  const idx = input.lastIndexOf(':')
  if (idx > 0 && /^\d+$/.test(input.slice(idx + 1))) {
    return { host: input.slice(0, idx), port: Number(input.slice(idx + 1)) }
  }
  return { host: input, port: defaultPort }
}

// Pair with a device the user is currently sharing (PIN shown on that device),
// pin its fingerprint, store the issued token, and persist it.
export async function addRemote(
  input: string,
  pin: string,
  opts: { defaultPort: number; dir?: string },
): Promise<RemoteDevice> {
  const dir = opts.dir ?? getSharingDir()
  const identity = await loadOrCreateIdentity(dir)
  const { host, port } = parseHostPort(input, opts.defaultPort)

  const h = await hello({ identity, host, port })
  if (h.status !== 200) throw new Error(`could not reach a CodeBurn device at ${host}:${port}`)
  const info = h.json as { fingerprint: string; name: string }

  const pr = await pair({ identity, host, port, expectedFingerprint: info.fingerprint }, pin, identity.name)
  if (pr.status !== 200) {
    const err = (pr.json as { error?: string })?.error ?? `HTTP ${pr.status}`
    throw new Error(`pairing failed: ${err}`)
  }
  const token = (pr.json as { token: string }).token

  const device: RemoteDevice = { name: info.name, host, port, fingerprint: info.fingerprint, token, addedAt: Date.now() }
  const remotes = (await loadRemotes(dir)).filter((r) => r.fingerprint !== device.fingerprint)
  remotes.push(device)
  await saveRemotes(remotes, dir)
  return device
}

// Pair with a discovered device using approve-style pairing (no PIN). The owner
// of that device approves on their screen after confirming the matching code.
export async function linkRemote(
  d: DiscoveredDevice,
  opts: { dir?: string; onCode?: (code: string) => void } = {},
): Promise<RemoteDevice> {
  const dir = opts.dir ?? getSharingDir()
  const identity = await loadOrCreateIdentity(dir)
  const code = pairingCode(identity.fingerprint, d.fingerprint)
  opts.onCode?.(code)
  const r = await pairRequest({ identity, host: d.host, port: d.port, expectedFingerprint: d.fingerprint }, identity.name)
  if (r.status !== 200) {
    throw new Error(r.status === 403 ? 'the other device declined' : `pairing failed (HTTP ${r.status})`)
  }
  const token = (r.json as { token: string }).token
  const device: RemoteDevice = { name: d.name, host: d.host, port: d.port, fingerprint: d.fingerprint, token, addedAt: Date.now() }
  const remotes = (await loadRemotes(dir)).filter((x) => x.fingerprint !== device.fingerprint)
  remotes.push(device)
  await saveRemotes(remotes, dir)
  return device
}

// Pull this machine's usage plus every paired remote's, each kept separate.
export async function pullDevices(
  localGetUsage: (q: UsageQuery) => Promise<DevicePayload>,
  query: UsageQuery,
  localName: string,
  opts: { dir?: string } = {},
): Promise<DeviceUsage[]> {
  const dir = opts.dir ?? getSharingDir()
  const identity = await loadOrCreateIdentity(dir)
  const remotes = await loadRemotes(dir)

  const local: DeviceUsage = { id: 'local', name: localName, local: true, payload: await localGetUsage(query) }
  // Pull every remote concurrently and isolate failures, so one slow or
  // powered-off device degrades to an error row instead of blocking the rest.
  const remoteResults = await Promise.all(
    remotes.map(async (r): Promise<DeviceUsage> => {
      try {
        const res = await fetchUsage({ identity, host: r.host, port: r.port, expectedFingerprint: r.fingerprint }, r.token, query)
        // Re-sanitize on receipt: do not trust the sender to have stripped its
        // own project names/sessions (it may run an older build). Belt and
        // suspenders alongside the sender-side sanitize.
        if (res.status === 200) return { id: r.fingerprint, name: r.name, local: false, payload: sanitizeForSharing(res.json as MenubarPayload) }
        return { id: r.fingerprint, name: r.name, local: false, error: res.status === 401 ? 'not authorized (re-pair?)' : `HTTP ${res.status}` }
      } catch (e) {
        return { id: r.fingerprint, name: r.name, local: false, error: e instanceof Error ? e.message : String(e) }
      }
    }),
  )
  return [local, ...remoteResults]
}

// Joined "Totals by machine" report: one row per device plus a bold Combined
// row. Tokens are shown as full, comma-grouped numbers.
export function renderDevices(results: DeviceUsage[]): string {
  const n = (x: number): string => Math.round(x).toLocaleString()
  const money = (x: number): string => formatCost(x).replace(/(\d)(?=(\d{3})+(\.|$))/g, '$1,')
  const summary = summarizeDeviceUsage(results)
  const rows = summary.perDevice.map((d) => ({
    name: d.name + (d.local ? ' (this Mac)' : ''),
    error: d.error,
    cost: d.cost,
    input: d.inputTokens,
    output: d.outputTokens,
    cacheCreate: d.cacheCreateTokens,
    cacheRead: d.cacheReadTokens,
    total: d.totalTokens,
  }))
  const combined = summary.combined

  const tableRows = [
    ...rows.map((r) =>
      r.error
        ? [r.name, r.error, '-', '-', '-', '-', '-']
        : [r.name, money(r.cost), n(r.total), n(r.input), n(r.output), n(r.cacheCreate), n(r.cacheRead)],
    ),
    ['Combined', money(combined.cost), n(combined.totalTokens), n(combined.inputTokens), n(combined.outputTokens), n(combined.cacheCreateTokens), n(combined.cacheReadTokens)],
  ]
  const table = renderTable(
    [
      { header: 'Host' },
      { header: 'Cost', right: true },
      { header: 'Total tokens', right: true },
      { header: 'Input', right: true },
      { header: 'Output', right: true },
      { header: 'Cache create', right: true },
      { header: 'Cache read', right: true },
    ],
    tableRows,
    { boldRows: new Set([tableRows.length - 1]) },
  )
  const heading = new Chalk({}).cyan('Totals by machine')
  return heading + '\n' + table + '\n'
}

export function aggregatePayloads(payloads: MenubarPayload[]): MenubarPayload {
  if (payloads.length === 0) {
    throw new Error("Cannot aggregate empty payloads");
  }
  if (payloads.length === 1) {
    return payloads[0];
  }

  const base = payloads[0];
  const currentPayloads = payloads.map(p => p.current);

  const cost = currentPayloads.reduce((sum, c) => sum + (c.cost || 0), 0);
  const calls = currentPayloads.reduce((sum, c) => sum + (c.calls || 0), 0);
  const sessions = currentPayloads.reduce((sum, c) => sum + (c.sessions || 0), 0);
  const inputTokens = currentPayloads.reduce((sum, c) => sum + (c.inputTokens || 0), 0);
  const outputTokens = currentPayloads.reduce((sum, c) => sum + (c.outputTokens || 0), 0);
  const cacheReadTokens = currentPayloads.reduce((sum, c) => sum + (c.cacheReadTokens || 0), 0);
  const cacheWriteTokens = currentPayloads.reduce((sum, c) => sum + (c.cacheWriteTokens || 0), 0);
  const codexCredits = currentPayloads.reduce((sum, c) => sum + (c.codexCredits || 0), 0);

  let totalSessionsForOneShot = 0;
  let weightedOneShotRate = 0;
  for (const c of currentPayloads) {
    if (c.oneShotRate !== null && c.oneShotRate !== undefined) {
      weightedOneShotRate += c.oneShotRate * (c.sessions || 1);
      totalSessionsForOneShot += (c.sessions || 1);
    }
  }
  const oneShotRate = totalSessionsForOneShot > 0 ? weightedOneShotRate / totalSessionsForOneShot : null;
  const cacheHitPercentVal = (inputTokens + cacheReadTokens) > 0 ? (cacheReadTokens / (inputTokens + cacheReadTokens)) * 100 : 0;

  function groupAndSum<T>(
    arrays: T[][],
    getKey: (item: T) => string,
    merge: (acc: T, val: T) => T
  ): T[] {
    const map = new Map<string, T>();
    for (const arr of arrays) {
      for (const item of arr) {
        const key = getKey(item);
        const existing = map.get(key);
        if (existing) {
          map.set(key, merge(existing, item));
        } else {
          map.set(key, { ...item });
        }
      }
    }
    return Array.from(map.values());
  }

  const topActivities = groupAndSum(
    currentPayloads.map(c => c.topActivities || []),
    item => item.name,
    (acc, val) => {
      const totalTurns = (acc.turns || 0) + (val.turns || 0);
      let newOneShotRate = null;
      if (totalTurns > 0) {
        const accOneShot = (acc.oneShotRate || 0) * (acc.turns || 0);
        const valOneShot = (val.oneShotRate || 0) * (val.turns || 0);
        newOneShotRate = (accOneShot + valOneShot) / totalTurns;
      }
      return {
        name: acc.name,
        cost: (acc.cost || 0) + (val.cost || 0),
        savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
        turns: totalTurns,
        oneShotRate: newOneShotRate,
      };
    }
  ).sort((a, b) => b.cost - a.cost);

  const topModels = groupAndSum(
    currentPayloads.map(c => c.topModels || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      cost: (acc.cost || 0) + (val.cost || 0),
      savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
      savingsBaselineModel: acc.savingsBaselineModel || val.savingsBaselineModel,
      calls: (acc.calls || 0) + (val.calls || 0),
    })
  ).sort((a, b) => b.cost - a.cost);

  const unpricedModels = groupAndSum(
    currentPayloads.map(c => c.unpricedModels || []),
    item => item.model,
    (acc, val) => ({
      model: acc.model,
      calls: (acc.calls || 0) + (val.calls || 0),
      tokens: (acc.tokens || 0) + (val.tokens || 0),
    })
  ).sort((a, b) => b.tokens - a.tokens);

  const localModelSavingsTotalUSD = currentPayloads.reduce((sum, c) => sum + (c.localModelSavings?.totalUSD || 0), 0);
  const localModelSavingsCalls = currentPayloads.reduce((sum, c) => sum + (c.localModelSavings?.calls || 0), 0);
  const localModelSavingsByModel = groupAndSum(
    currentPayloads.map(c => c.localModelSavings?.byModel || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      calls: (acc.calls || 0) + (val.calls || 0),
      actualUSD: (acc.actualUSD || 0) + (val.actualUSD || 0),
      savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
      baselineModel: acc.baselineModel || val.baselineModel,
      inputTokens: (acc.inputTokens || 0) + (val.inputTokens || 0),
      outputTokens: (acc.outputTokens || 0) + (val.outputTokens || 0),
    })
  );
  const localModelSavingsByProvider = groupAndSum(
    currentPayloads.map(c => c.localModelSavings?.byProvider || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      calls: (acc.calls || 0) + (val.calls || 0),
      savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
    })
  );
  const localModelSavings = {
    totalUSD: localModelSavingsTotalUSD,
    calls: localModelSavingsCalls,
    byModel: localModelSavingsByModel,
    byProvider: localModelSavingsByProvider,
  };

  const providers: Record<string, number> = {};
  for (const c of currentPayloads) {
    if (c.providers) {
      for (const [k, v] of Object.entries(c.providers)) {
        providers[k] = (providers[k] || 0) + v;
      }
    }
  }

  const topProjects = groupAndSum(
    currentPayloads.map(c => c.topProjects || []),
    item => item.name,
    (acc, val) => {
      const totalSessions = (acc.sessions || 0) + (val.sessions || 0);
      const totalCost = (acc.cost || 0) + (val.cost || 0);
      return {
        name: acc.name,
        cost: totalCost,
        savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
        sessions: totalSessions,
        avgCostPerSession: totalSessions > 0 ? totalCost / totalSessions : 0,
        sessionDetails: [...(acc.sessionDetails || []), ...(val.sessionDetails || [])].sort(
          (a, b) => b.cost - a.cost
        ),
      };
    }
  ).sort((a, b) => b.cost - a.cost);

  const modelEfficiency = groupAndSum(
    currentPayloads.map(c => c.modelEfficiency || []),
    item => item.name,
    (acc, val) => {
      const count = 2;
      const costPerEdit =
        acc.costPerEdit !== null && val.costPerEdit !== null
          ? (acc.costPerEdit + val.costPerEdit) / count
          : acc.costPerEdit !== null
          ? acc.costPerEdit
          : val.costPerEdit;
      const oneShotRateVal =
        acc.oneShotRate !== null && val.oneShotRate !== null
          ? (acc.oneShotRate + val.oneShotRate) / count
          : acc.oneShotRate !== null
          ? acc.oneShotRate
          : val.oneShotRate;
      return {
        name: acc.name,
        costPerEdit,
        oneShotRate: oneShotRateVal,
      };
    }
  );

  const topSessions = currentPayloads
    .flatMap(c => c.topSessions || [])
    .sort((a, b) => b.cost - a.cost)
    .slice(0, 3);

  const retryTaxTotalUSD = currentPayloads.reduce((sum, c) => sum + (c.retryTax?.totalUSD || 0), 0);
  const retryTaxRetries = currentPayloads.reduce((sum, c) => sum + (c.retryTax?.retries || 0), 0);
  const retryTaxEditTurns = currentPayloads.reduce((sum, c) => sum + (c.retryTax?.editTurns || 0), 0);
  const retryTaxByModel = groupAndSum(
    currentPayloads.map(c => c.retryTax?.byModel || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      taxUSD: (acc.taxUSD || 0) + (val.taxUSD || 0),
      retries: (acc.retries || 0) + (val.retries || 0),
      retriesPerEdit: null,
    })
  );
  const retryTax = {
    totalUSD: retryTaxTotalUSD,
    retries: retryTaxRetries,
    editTurns: retryTaxEditTurns,
    byModel: retryTaxByModel,
  };

  const routingWasteTotalSavingsUSD = currentPayloads.reduce((sum, c) => sum + (c.routingWaste?.totalSavingsUSD || 0), 0);
  const routingWasteByModel = groupAndSum(
    currentPayloads.map(c => c.routingWaste?.byModel || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      costPerEdit: (acc.costPerEdit + val.costPerEdit) / 2,
      editTurns: (acc.editTurns || 0) + (val.editTurns || 0),
      actualUSD: (acc.actualUSD || 0) + (val.actualUSD || 0),
      counterfactualUSD: (acc.counterfactualUSD || 0) + (val.counterfactualUSD || 0),
      savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
    })
  );
  const routingWaste = {
    totalSavingsUSD: routingWasteTotalSavingsUSD,
    baselineModel: currentPayloads[0]?.routingWaste?.baselineModel || "",
    baselineCostPerEdit: currentPayloads[0]?.routingWaste?.baselineCostPerEdit || 0,
    byModel: routingWasteByModel,
  };

  const tools = groupAndSum(
    currentPayloads.map(c => c.tools || []),
    item => item.name,
    (acc, val) => ({ name: acc.name, calls: (acc.calls || 0) + (val.calls || 0) })
  ).sort((a, b) => b.calls - a.calls);

  const skills = groupAndSum(
    currentPayloads.map(c => c.skills || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      turns: (acc.turns || 0) + (val.turns || 0),
      cost: (acc.cost || 0) + (val.cost || 0),
    })
  ).sort((a, b) => b.cost - a.cost);

  const subagents = groupAndSum(
    currentPayloads.map(c => c.subagents || []),
    item => item.name,
    (acc, val) => ({
      name: acc.name,
      calls: (acc.calls || 0) + (val.calls || 0),
      cost: (acc.cost || 0) + (val.cost || 0),
    })
  ).sort((a, b) => b.cost - a.cost);

  const mcpServers = groupAndSum(
    currentPayloads.map(c => c.mcpServers || []),
    item => item.name,
    (acc, val) => ({ name: acc.name, calls: (acc.calls || 0) + (val.calls || 0) })
  ).sort((a, b) => b.calls - a.calls);

  const optimizeCount = payloads.reduce((sum, p) => sum + (p.optimize?.findingCount || 0), 0);
  const optimizeSavingsUSD = payloads.reduce((sum, p) => sum + (p.optimize?.savingsUSD || 0), 0);
  const optimizeTopFindings = groupAndSum(
    payloads.map(p => p.optimize?.topFindings || []),
    item => item.title,
    (acc, val) => ({
      title: acc.title,
      impact: acc.impact === 'high' || val.impact === 'high' ? 'high' : acc.impact === 'medium' || val.impact === 'medium' ? 'medium' : 'low',
      savingsUSD: (acc.savingsUSD || 0) + (val.savingsUSD || 0),
    })
  ).sort((a, b) => b.savingsUSD - a.savingsUSD);

  const dailyHistoryEntries = groupAndSum(
    payloads.map(p => p.history?.daily || []),
    item => item.date,
    (acc, val) => ({
      date: acc.date,
      cost: acc.cost + val.cost,
      savingsUSD: acc.savingsUSD + val.savingsUSD,
      calls: acc.calls + val.calls,
      inputTokens: acc.inputTokens + val.inputTokens,
      outputTokens: acc.outputTokens + val.outputTokens,
      cacheReadTokens: acc.cacheReadTokens + val.cacheReadTokens,
      cacheWriteTokens: acc.cacheWriteTokens + val.cacheWriteTokens,
      topModels: groupAndSum(
        [acc.topModels || [], val.topModels || []],
        m => m.name,
        (ma, mv) => ({
          name: ma.name,
          cost: ma.cost + mv.cost,
          savingsUSD: ma.savingsUSD + mv.savingsUSD,
          calls: ma.calls + mv.calls,
          inputTokens: ma.inputTokens + mv.inputTokens,
          outputTokens: ma.outputTokens + mv.outputTokens,
        })
      ),
    })
  ).sort((a, b) => a.date.localeCompare(b.date));

  return {
    generated: new Date().toISOString(),
    current: {
      label: base.current.label,
      cost,
      calls,
      sessions,
      oneShotRate,
      inputTokens,
      outputTokens,
      cacheReadTokens,
      cacheWriteTokens,
      cacheHitPercent: cacheHitPercentVal,
      codexCredits,
      topActivities,
      topModels,
      unpricedModels,
      localModelSavings,
      providers,
      topProjects,
      modelEfficiency,
      topSessions,
      retryTax,
      routingWaste,
      tools,
      skills,
      subagents,
      mcpServers,
    },
    optimize: {
      findingCount: optimizeCount,
      savingsUSD: optimizeSavingsUSD,
      topFindings: optimizeTopFindings,
    },
    history: {
      daily: dailyHistoryEntries,
    },
  };
}
