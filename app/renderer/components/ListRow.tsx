import type { CSSProperties, ReactNode } from 'react'

export { seriesColorForModel } from '../lib/modelSeries'

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
