// @vitest-environment jsdom
import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { App } from './App'
import type { MenubarPayload, SpendFlow } from './lib/types'

const mocks = vi.hoisted(() => ({
  getOverview: vi.fn<(period: string, provider: string) => Promise<MenubarPayload>>(),
  getSpendFlow: vi.fn<(period: string, provider: string) => Promise<SpendFlow>>(),
  getModels: vi.fn(),
  getPlans: vi.fn(),
  getYield: vi.fn(),
  getDevices: vi.fn(),
  getDevicesScan: vi.fn(),
  getIdentity: vi.fn(),
  cliStatus: vi.fn(),
}))

vi.mock('./lib/ipc', async orig => {
  const actual = await orig<typeof import('./lib/ipc')>()
  return { ...actual, codeburn: mocks }
})

function dateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

function overviewPayload(): MenubarPayload {
  const now = new Date()
  return {
    generated: now.toISOString(),
    current: {
      label: 'Last 30 days',
      cost: 12.34,
      calls: 12,
      sessions: 2,
      oneShotRate: null,
      inputTokens: 0,
      outputTokens: 0,
      cacheReadTokens: 0,
      cacheWriteTokens: 0,
      cacheHitPercent: 0,
      codexCredits: 0,
      topActivities: [],
      topModels: [],
      localModelSavings: { totalUSD: 0, calls: 0, byModel: [], byProvider: [] },
      providers: {},
      topProjects: [],
      modelEfficiency: [],
      topSessions: [],
      retryTax: { totalUSD: 0, retries: 0, editTurns: 0, byModel: [] },
      routingWaste: { totalSavingsUSD: 0, baselineModel: '', baselineCostPerEdit: 0, byModel: [] },
      tools: [],
      skills: [],
      subagents: [],
      mcpServers: [],
    },
    optimize: { findingCount: 0, savingsUSD: 0, topFindings: [] },
    history: {
      daily: [
        {
          date: dateKey(now),
          cost: 12.34,
          savingsUSD: 0,
          calls: 12,
          inputTokens: 0,
          outputTokens: 0,
          cacheReadTokens: 0,
          cacheWriteTokens: 0,
          topModels: [],
        },
      ],
    },
  }
}

describe('App shortcuts', () => {
  beforeEach(() => {
    for (const mock of Object.values(mocks)) mock.mockReset()
    mocks.getOverview.mockResolvedValue(overviewPayload())
    mocks.getSpendFlow.mockResolvedValue({ period: { label: 'Last 30 days', start: '', end: '' }, models: [], projects: [], links: [] })
  })

  it('switches sections with command-number shortcuts', async () => {
    render(<App />)

    expect(await screen.findByText('Most expensive sessions')).toBeInTheDocument()

    fireEvent.keyDown(document, { key: '2', metaKey: true })

    expect(await screen.findByText('Cost flow · model → project')).toBeInTheDocument()
  })

  it('re-polls visible section data when period or provider changes', async () => {
    render(<App />)

    fireEvent.keyDown(document, { key: '2', metaKey: true })
    expect(await screen.findByText('Cost flow · model → project')).toBeInTheDocument()

    fireEvent.click(screen.getByText('Today'))

    await waitFor(() => {
      expect(mocks.getOverview).toHaveBeenCalledWith('today', 'all')
      expect(mocks.getSpendFlow).toHaveBeenCalledWith('today', 'all')
    })

    fireEvent.click(screen.getByText('All providers'))

    await waitFor(() => {
      expect(mocks.getOverview).toHaveBeenCalledWith('today', 'claude')
      expect(mocks.getSpendFlow).toHaveBeenCalledWith('today', 'claude')
    })
  })
})
