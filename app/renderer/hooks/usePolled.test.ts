// @vitest-environment jsdom
import { describe, it, expect, vi } from 'vitest'
import { renderHook, act } from '@testing-library/react'

import { usePolled } from './usePolled'

describe('usePolled', () => {
  it('discards a stale in-flight fetch that resolves after a newer one (epoch guard)', async () => {
    // A fetcher we resolve by hand, one deferred per call, so we can force a
    // SLOW deps-A fetch to resolve AFTER a FAST deps-B fetch.
    const resolvers: Array<(v: string) => void> = []
    const fetcher = vi.fn(() => new Promise<string>(resolve => { resolvers.push(resolve) }))

    const { result, rerender } = renderHook(
      ({ p }: { p: string }) => usePolled(fetcher, [p]),
      { initialProps: { p: 'A' } },
    )

    // #0 mount fetch (deps A) — resolve it to establish a known baseline.
    await act(async () => { resolvers[0]!('A0') })
    expect(fetcher).toHaveBeenCalledTimes(1)
    expect(result.current.data).toBe('A0')

    // #1 refresh() while deps are still A → an in-flight SLOW fetch whose cancel
    // handle the hook discards. Leave it unresolved for now.
    act(() => { result.current.refresh() })
    expect(fetcher).toHaveBeenCalledTimes(2)

    // #2 deps change A→B → a FAST fetch that resolves first with fresh data.
    rerender({ p: 'B' })
    expect(fetcher).toHaveBeenCalledTimes(3)
    await act(async () => { resolvers[2]!('B-fresh') })
    expect(result.current.data).toBe('B-fresh')

    // #1 (the slow deps-A fetch) now resolves LATE. It must NOT clobber B.
    await act(async () => { resolvers[1]!('A-stale') })
    expect(result.current.data).toBe('B-fresh')
  })
})
