// @vitest-environment jsdom
import { render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { CombinedUsage, DeviceScanResult, Identity } from '../lib/types'
import { Settings } from './Settings'

const { getIdentity, getDevices, getDevicesScan } = vi.hoisted(() => ({
  getIdentity: vi.fn<() => Promise<Identity>>(),
  getDevices: vi.fn<(period: string) => Promise<CombinedUsage>>(),
  getDevicesScan: vi.fn<() => Promise<DeviceScanResult>>(),
}))
vi.mock('../lib/ipc', async orig => {
  const actual = await orig<typeof import('../lib/ipc')>()
  return { ...actual, codeburn: { getIdentity, getDevices, getDevicesScan } }
})

const identity: Identity = {
  name: 'Toruk MacBook Pro',
  fingerprint: 'AA:11:22:33:44:55:66:77',
}

const devices: CombinedUsage = {
  perDevice: [
    {
      id: 'local',
      name: 'Toruk MacBook Pro',
      local: true,
      cost: 120.1,
      calls: 100,
      sessions: 10,
      inputTokens: 1,
      outputTokens: 2,
      cacheCreateTokens: 3,
      cacheReadTokens: 4,
      totalTokens: 10,
    },
    {
      id: 'mini',
      name: 'toruk-mini',
      local: false,
      cost: 41.2,
      calls: 680,
      sessions: 34,
      inputTokens: 11,
      outputTokens: 12,
      cacheCreateTokens: 13,
      cacheReadTokens: 14,
      totalTokens: 50,
    },
  ],
  combined: {
    cost: 161.3,
    calls: 780,
    sessions: 44,
    inputTokens: 12,
    outputTokens: 14,
    cacheCreateTokens: 16,
    cacheReadTokens: 18,
    totalTokens: 60,
    deviceCount: 2,
    reachableCount: 2,
  },
}

const scan: DeviceScanResult = {
  found: [
    {
      name: 'Mac Studio',
      host: 'mac-studio.local',
      port: 9732,
      fingerprint: '7F:2A:19:88:55:44:33:C4',
      code: 'pair-1',
      paired: false,
    },
  ],
}

describe('Settings', () => {
  beforeEach(() => {
    getIdentity.mockReset()
    getDevices.mockReset()
    getDevicesScan.mockReset()
  })

  it('renders device identity, scan results, paired devices, and M2 affordances', async () => {
    getIdentity.mockResolvedValue(identity)
    getDevices.mockResolvedValue(devices)
    getDevicesScan.mockResolvedValue(scan)

    const { container } = render(<Settings period="month" />)

    expect(await screen.findByText('Toruk MacBook Pro')).toBeInTheDocument()
    expect(screen.getByText('Visible on the local network as Toruk MacBook Pro.local')).toBeInTheDocument()
    expect(screen.getByText('AA:11:22:33:44:55:66:77')).toBeInTheDocument()

    expect(await screen.findByText('Mac Studio')).toBeInTheDocument()
    expect(screen.getByText('wants to pair · fingerprint 7F:2A:…:C4')).toBeInTheDocument()

    expect(await screen.findByText('toruk-mini')).toBeInTheDocument()
    expect(screen.getByText('34 sessions · $41.20 this month')).toBeInTheDocument()

    expect(screen.getByText('Visibility: on')).toBeInTheDocument()
    expect(screen.getByText('Approve')).toBeInTheDocument()
    expect(screen.getByText('Pull now')).toBeInTheDocument()
    expect(screen.getByText('Combine usage from paired devices')).toBeInTheDocument()
    expect(container.querySelector('.tglon')).toBeInTheDocument()
    expect(getDevices).toHaveBeenCalledWith('month')
  })
})
