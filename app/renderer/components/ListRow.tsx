import type { CSSProperties, ReactNode } from 'react'

/**
 * Series-dot colour for a model name, per the wireframe palette
 * (blue=Opus, purple=Sonnet, lavender=Haiku, cyan=GPT/Codex). Unknown or
 * unmatched models fall back to a neutral slate rather than a fabricated series.
 */
export function seriesColorForModel(model?: string): string {
  const m = (model ?? '').toLowerCase()
  if (m.includes('opus')) return 'var(--blue)'
  if (m.includes('sonnet')) return 'var(--purple)'
  if (m.includes('haiku')) return 'var(--lav)'
  if (m.includes('gpt') || m.includes('codex')) return 'var(--cyan)'
  return 'var(--t3)'
}

/**
 * A `.li` list row: optional rank `.no`, optional model series `.mdot`, a
 * title + sub line `.lx`, an optional right-aligned `.val`, and the chevron.
 * Presentational; used by Overview's "most expensive sessions" and reusable by
 * later sections.
 */
export function ListRow({
  no,
  dotColor,
  title,
  sub,
  value,
  valueClass,
}: {
  no?: ReactNode
  dotColor?: string
  title: ReactNode
  sub?: ReactNode
  value?: ReactNode
  valueClass?: string
}) {
  const dot: CSSProperties | undefined = dotColor ? { background: dotColor } : undefined
  return (
    <div className="li">
      {no !== undefined && <span className="no">{no}</span>}
      {dotColor !== undefined && <span className="mdot" style={dot} />}
      <div className="lx">
        <b>{title}</b>
        {sub !== undefined && <span>{sub}</span>}
      </div>
      {value !== undefined && <span className={valueClass ? `val ${valueClass}` : 'val'}>{value}</span>}
      <span className="chev">›</span>
    </div>
  )
}
