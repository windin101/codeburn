import { useId, useMemo } from 'react'

import { motionClass, motionEnabled } from '../lib/motion'

/**
 * Hand-authored brand flame: an orange body tongue over a lighter inner tongue,
 * traced to match the menubar mark. Shared between the launch splash (large) and
 * the sidebar (small). `live` gives the inner tongue an extremely subtle idle
 * flicker in the sidebar; its phase is randomized once per mount so a row of
 * flames never metronomes. All motion is gated by motionEnabled().
 */
export function FlameMark({ size = 20, live = false }: { size?: number; live?: boolean }) {
  const uid = useId()
  const body = `fm-body-${uid}`
  const core = `fm-core-${uid}`
  // Random negative delay so the loop starts mid-cycle at a different point each
  // mount. Computed once; only takes effect when the flicker class is present.
  const flickerStyle = useMemo(() => ({ animationDelay: `-${(Math.random() * 4 + 1).toFixed(2)}s` }), [])
  const coreClass = live ? motionClass('fm-core', 'fm-flicker') : 'fm-core'

  return (
    <svg className="flamemark" width={size} height={size} viewBox="0 0 32 40" fill="none" aria-hidden="true">
      <defs>
        <linearGradient id={body} x1="16" y1="2" x2="16" y2="39" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#f2701c" />
          <stop offset=".5" stopColor="#e8590c" />
          <stop offset="1" stopColor="#c2410c" />
        </linearGradient>
        <linearGradient id={core} x1="16" y1="16" x2="16" y2="39" gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor="#ffd9a8" />
          <stop offset=".55" stopColor="#ffb877" />
          <stop offset="1" stopColor="#f79a56" />
        </linearGradient>
      </defs>
      <path
        fill={`url(#${body})`}
        d="M17.4 2.8C19.6 7.2 17.2 9.9 15.2 12.7C12.6 16.3 9.7 19.1 9.2 23.4C8.9 25.7 9.6 27.8 11 29.6C9.4 28.9 8.2 27.4 7.7 25.6C6.1 27.2 5.2 29.4 5.4 31.7C5.7 35.9 10.3 39 15.9 39C22 39 26.7 35.4 26.7 29.6C26.7 25.6 24.6 22.4 23.2 20.6C23.9 22.4 23.7 24.3 22.6 25.4C24 21.7 22.4 17.7 19.6 15.3C21.6 12.9 22.5 9.9 21.6 7.1C20.8 9.3 19.4 10.6 18.8 10.9C20 8.2 19.8 5 17.4 2.8Z"
      />
      <path
        className={coreClass}
        style={live && motionEnabled() ? flickerStyle : undefined}
        fill={`url(#${core})`}
        d="M16.6 17.8C17.8 20.4 16 22.2 15.6 24.6C15.3 26.6 16.4 28.3 18.4 28.7C20.1 29 21.7 28 22 26.3C22.3 24.6 21.4 23.3 20.8 22.6C21.1 24.1 20.3 25 19.4 25.2C20.5 22.5 18.9 20.4 17.6 19.6C18.3 18.5 18 17.2 16.6 17.8Z"
      />
    </svg>
  )
}
