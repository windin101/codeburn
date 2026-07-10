import { CapsuleChart, fmtDay } from '../components/CapsuleChart'
import { ListRow, seriesColorForModel } from '../components/ListRow'
import { Panel } from '../components/Panel'
import { Stat } from '../components/Stat'
import { usePolled } from '../hooks/usePolled'
import { codeburn } from '../lib/ipc'
import type { DailyHistoryEntry, MenubarPayload, Period } from '../lib/types'

function fmtUsd(n: number): string {
  return `$${n.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

/** Local calendar date key "YYYY-MM-DD", matching the CLI's `dateKey` (src/day-aggregator.ts). */
export function localDateKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/**
 * `history.daily` is NOT scoped to the selected period — the CLI backfills up to
 * 365 days regardless of `period`, and zero-activity days are simply absent. So
 * the chart (and any per-period rate) must slice it to the selected window here.
 * Returns the inclusive lower-bound date key ("YYYY-MM-DD"), or null for `all`:
 *   today  → today only          week   → last 7 calendar days
 *   30days → last 30 calendar days   month → 1st of the current month   all → no lower bound
 */
export function periodWindowStart(period: Period, now: Date): string | null {
  switch (period) {
    case 'today':
      return localDateKey(now)
    case 'week':
      return localDateKey(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 6))
    case '30days':
      return localDateKey(new Date(now.getFullYear(), now.getMonth(), now.getDate() - 29))
    case 'month':
      return localDateKey(new Date(now.getFullYear(), now.getMonth(), 1))
    case 'all':
      return null
  }
}

/** `history.daily` entries within the selected period's date window (see above). */
export function sliceDailyToPeriod(daily: DailyHistoryEntry[], period: Period, now: Date): DailyHistoryEntry[] {
  const start = periodWindowStart(period, now)
  const todayKey = localDateKey(now)
  return daily.filter(d => (start === null || d.date >= start) && d.date <= todayKey)
}

/**
 * Length of the selected period in days, for normalizing period-scoped totals
 * (e.g. optimize.savingsUSD) into a rate. Fixed for bounded periods; for `all`
 * it's the span of available history (earliest entry → today, inclusive).
 */
export function periodLengthDays(period: Period, daily: DailyHistoryEntry[], now: Date): number {
  switch (period) {
    case 'today':
      return 1
    case 'week':
      return 7
    case '30days':
      return 30
    case 'month':
      return now.getDate() // days elapsed this calendar month
    case 'all': {
      if (daily.length === 0) return 1
      const earliest = daily.reduce((min, d) => (d.date < min ? d.date : min), daily[0].date)
      const [y, m, d] = earliest.split('-').map(Number)
      const start = new Date(y, m - 1, d)
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
      return Math.max(1, Math.round((today.getTime() - start.getTime()) / 86_400_000) + 1)
    }
  }
}

function median(values: number[]): number {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const mid = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
}

/**
 * All four stat cards + the daily-spend delta, derived from the single
 * MenubarPayload. Every number traces to a payload field — the payload carries
 * no plan budgets, so "over plans"-style deltas are replaced with honest,
 * derivable ones (see comments) rather than fabricated.
 */
function deriveStats(data: MenubarPayload, period: Period, now: Date) {
  const daily = data.history.daily
  const todayKey = localDateKey(now)
  const monthPrefix = todayKey.slice(0, 7) // "YYYY-MM"

  // Today = the daily entry for the machine's local "today". Absent (no activity
  // today) → $0.00.
  const todayEntry = daily.find(d => d.date === todayKey)
  const todayCost = todayEntry?.cost ?? 0

  // Month-to-date = sum of daily costs in the current calendar month.
  const mtdEntries = daily.filter(d => d.date.slice(0, 7) === monthPrefix)
  const mtd = mtdEntries.reduce((s, d) => s + d.cost, 0)

  // Projected month: median of the trailing-7 daily costs as the expected per-day
  // run rate × days left in the calendar month, added to MTD. Approximates
  // src/plan-usage.ts projectMonthEnd, which medians the last 7 CALENDAR days
  // (zero-filling idle days); here `daily` has no zero rows, so we median the
  // last 7 ACTIVE days — a close, slightly hotter estimate on sparse histories.
  const medianDaily = median(daily.slice(-7).map(d => d.cost))
  const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
  const daysRemaining = Math.max(0, daysInMonth - now.getDate())
  const projected = mtd + medianDaily * daysRemaining
  // Forecast for the rest of the month — an honest neutral delta in place of the
  // wireframe's "$X over plans" (which needs plan budgets from getPlans).
  const restOfMonth = Math.max(0, projected - mtd)

  // "+% vs {prevMonth} pace": this month's average daily spend vs the PREVIOUS
  // calendar month's, so the % and the month name in the label agree. Amber when
  // running hotter, mint when cooler; omitted when the prior month has no data.
  const prevMonth = new Date(now.getFullYear(), now.getMonth() - 1, 1)
  const prevMonthPrefix = localDateKey(prevMonth).slice(0, 7)
  const priorEntries = daily.filter(d => d.date.slice(0, 7) === prevMonthPrefix)
  const currentDailyAvg = mtdEntries.length ? mtd / mtdEntries.length : 0
  const priorDailyAvg = priorEntries.length ? priorEntries.reduce((s, d) => s + d.cost, 0) / priorEntries.length : null
  const pacePct = priorDailyAvg && priorDailyAvg > 0 ? ((currentDailyAvg - priorDailyAvg) / priorDailyAvg) * 100 : null
  const prevMonthName = prevMonth.toLocaleString('en-US', { month: 'long' })

  // Waste found /wk = optimize.savingsUSD (recoverable spend over the SELECTED
  // period) normalized to a weekly rate by the SELECTED period's length in days:
  // savingsUSD / periodDays × 7. (history.daily is unbounded backfill, not the
  // period, so its length must not be used as the divisor here.)
  const weeklyWaste = (data.optimize.savingsUSD / periodLengthDays(period, daily, now)) * 7

  return {
    todayEntry,
    todayCost,
    mtd,
    pacePct,
    prevMonthName,
    projected,
    restOfMonth,
    weeklyWaste,
    findingCount: data.optimize.findingCount,
  }
}

/**
 * topSessions carries no model or title (src/menubar-json.ts). Recover each
 * session's dominant model — for the series dot and sub-line — by matching it to
 * topProjects' sessionDetails on (project, date, calls, cost), a key both
 * emitters derive from the same underlying session. `cost` disambiguates two
 * same-project/same-day/same-calls sessions that would otherwise collide.
 */
export function sessionModelKey(project: string, date: string, calls: number, cost: number): string {
  return `${project}|${date}|${calls}|${cost}`
}

function buildModelIndex(data: MenubarPayload): Map<string, string> {
  const index = new Map<string, string>()
  for (const p of data.current.topProjects) {
    for (const sd of p.sessionDetails) {
      const dominant = [...sd.models].sort((a, b) => b.cost - a.cost)[0]
      if (dominant) index.set(sessionModelKey(p.name, sd.date, sd.calls, sd.cost), dominant.name)
    }
  }
  return index
}

function EmptyNote({ children }: { children: React.ReactNode }) {
  return <p style={{ color: 'var(--t3)', margin: 0, fontSize: 12 }}>{children}</p>
}

export function Overview({ period, provider }: { period: Period; provider: string }) {
  const { data, error } = usePolled<MenubarPayload>(
    () => codeburn.getOverview(period, provider),
    [period, provider],
  )

  // Retain last-good data across a failed refresh; only fall to a state when we
  // have nothing to show.
  if (!data) {
    if (error?.kind === 'not-found') {
      return (
        <Panel title="Locate the codeburn CLI">
          <p style={{ color: 'var(--t2)', margin: '0 0 6px', fontSize: 12.5 }}>
            CodeBurn Desktop reads your usage by running the{' '}
            <code style={{ fontFamily: 'var(--mono)', color: 'var(--lav)' }}>codeburn</code> command, but it isn&apos;t
            on your PATH yet.
          </p>
          <p style={{ color: 'var(--t3)', margin: 0, fontSize: 11.5 }}>
            Install it with <code style={{ fontFamily: 'var(--mono)', color: 'var(--lav)' }}>npm i -g codeburn</code>,
            then reopen this window.
          </p>
        </Panel>
      )
    }
    if (error) {
      return (
        <Panel title="Couldn't read usage">
          <p style={{ color: 'var(--red)', margin: 0, fontSize: 12 }}>{error.message}</p>
        </Panel>
      )
    }
    return (
      <Panel title="Overview">
        <EmptyNote>Scanning sessions…</EmptyNote>
      </Panel>
    )
  }

  const now = new Date()
  const s = deriveStats(data, period, now)
  // history.daily is unbounded backfill; the chart shows only the selected
  // period's date window (see sliceDailyToPeriod).
  const chartDaily = sliceDailyToPeriod(data.history.daily, period, now)
  const sessions = data.current.topSessions
  const topModel = data.current.topModels[0]
  const modelIndex = buildModelIndex(data)

  return (
    <>
      <div className="stats">
        <Stat
          label="Today"
          value={fmtUsd(s.todayCost)}
          delta={s.todayEntry ? `${s.todayEntry.calls.toLocaleString('en-US')} calls` : undefined}
          tone="info"
        />
        <Stat
          label="Month to date"
          value={fmtUsd(s.mtd)}
          delta={
            s.pacePct !== null
              ? `${s.pacePct >= 0 ? '+' : ''}${Math.round(s.pacePct)}% vs ${s.prevMonthName} pace`
              : undefined
          }
          tone={s.pacePct !== null && s.pacePct < 0 ? 'ok' : 'hot'}
        />
        <Stat
          label="Projected month"
          value={
            <>
              {fmtUsd(s.projected)} <small>est</small>
            </>
          }
          delta={s.restOfMonth > 0 ? `+${fmtUsd(s.restOfMonth)} rest of month` : undefined}
          tone="info"
        />
        <Stat
          label="Waste found"
          value={
            <>
              {fmtUsd(s.weeklyWaste)} <small>/wk</small>
            </>
          }
          delta={s.findingCount > 0 ? `${s.findingCount} fixes ready` : undefined}
          tone="ok"
        />
      </div>

      <Panel title="Daily spend" right={topModel ? `biggest driver: ${topModel.name}` : undefined}>
        {chartDaily.length ? <CapsuleChart daily={chartDaily} /> : <EmptyNote>No spend in this range yet.</EmptyNote>}
      </Panel>

      <Panel title="Most expensive sessions" right="See all ›" rightLink>
        {sessions.length ? (
          sessions.map((session, i) => {
            const model = modelIndex.get(sessionModelKey(session.project, session.date, session.calls, session.cost))
            const sub = [fmtDay(session.date), model, `${session.calls} calls`].filter(Boolean).join(' · ')
            return (
              <ListRow
                key={`${session.project}-${session.date}-${i}`}
                no={String(i + 1).padStart(2, '0')}
                dotColor={seriesColorForModel(model)}
                title={session.project}
                sub={sub}
                value={fmtUsd(session.cost)}
              />
            )
          })
        ) : (
          <EmptyNote>No sessions in this range.</EmptyNote>
        )}
      </Panel>
    </>
  )
}
