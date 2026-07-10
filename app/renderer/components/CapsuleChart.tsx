import type { DailyHistoryEntry } from '../lib/types'

/** "YYYY-MM-DD" → "Mon D" (parsed as a local date to avoid a TZ day-shift). */
export function fmtDay(key: string): string {
  const [y, m, d] = key.split('-').map(Number)
  if (!y || !m || !d) return key
  return new Date(y, m - 1, d).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
}

/** Axis-label formatting: whole dollars once we're past $10, else one decimal. */
function fmtAxis(v: number): string {
  if (v >= 10) return String(Math.round(v))
  return v.toFixed(1)
}

/**
 * The daily-spend capsule chart. One `.c` bar per `history.daily` entry, height
 * = cost / axisMax where axisMax is the peak day's spend, so the tallest bar
 * fills the plot (CSS `min-height` shows a stub for $0 days). The peak day gets
 * the gradient+glow treatment (`.c.hi`), the runner-up plain blue (`.c.hi2`).
 * Gridline labels read peak / half / zero; the day axis shows up to five evenly
 * spaced dates.
 */
export function CapsuleChart({ daily }: { daily: DailyHistoryEntry[] }) {
  const costs = daily.map(d => d.cost)
  const max = costs.reduce((m, c) => (c > m ? c : m), 0)
  const axisMax = max > 0 ? max : 1

  // Peak (.c.hi) = highest-cost day, runner-up (.c.hi2) = second highest. Strict
  // `>` keeps the earliest day on ties and never highlights a $0 day.
  let peak = -1
  let second = -1
  costs.forEach((c, i) => {
    if (c <= 0) return
    if (peak === -1 || c > costs[peak]) {
      second = peak
      peak = i
    } else if (second === -1 || c > costs[second]) {
      second = i
    }
  })

  const n = daily.length
  const labelIdx = [
    ...new Set(n <= 5 ? daily.map((_, i) => i) : [0, 0.25, 0.5, 0.75, 1].map(f => Math.round(f * (n - 1)))),
  ]

  return (
    <>
      <div className="plot">
        <div className="gl" style={{ top: 0 }}>
          <em>{fmtAxis(axisMax)}</em>
        </div>
        <div className="gl" style={{ top: '50%' }}>
          <em>{fmtAxis(axisMax / 2)}</em>
        </div>
        <div className="gl" style={{ top: '100%' }}>
          <em>0</em>
        </div>
        <div className="bars">
          {costs.map((c, i) => {
            const cls = i === peak ? 'c hi' : i === second ? 'c hi2' : 'c'
            const height = Math.max(0, Math.min(100, (c / axisMax) * 100))
            return (
              <div className={cls} key={i}>
                <div className="b" style={{ height: `${height}%` }} />
              </div>
            )
          })}
        </div>
      </div>
      <div className="days">
        {labelIdx.map(i => (
          <span key={i}>{fmtDay(daily[i].date)}</span>
        ))}
      </div>
    </>
  )
}
