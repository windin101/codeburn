import claude from '../assets/providers/claude.svg'
import copilotDark from '../assets/providers/copilot-dark.svg'
import copilotLight from '../assets/providers/copilot-light.svg'
import cursorDark from '../assets/providers/cursor-dark.svg'
import cursorLight from '../assets/providers/cursor-light.svg'
import gemini from '../assets/providers/gemini.svg'
import grokDark from '../assets/providers/grok-dark.svg'
import grokLight from '../assets/providers/grok-light.svg'
import opencodeDark from '../assets/providers/opencode-dark.svg'
import opencodeLight from '../assets/providers/opencode-light.svg'
import openaiDark from '../assets/providers/openai-dark.svg'
import openaiLight from '../assets/providers/openai-light.svg'
import qwenDark from '../assets/providers/qwen-dark.svg'
import qwenLight from '../assets/providers/qwen-light.svg'

const SINGLE_LOGOS: Record<string, string> = {
  claude,
  gemini,
}

const THEMED_LOGOS: Record<string, { light: string; dark: string }> = {
  codex: { light: openaiLight, dark: openaiDark },
  copilot: { light: copilotLight, dark: copilotDark },
  cursor: { light: cursorLight, dark: cursorDark },
  'cursor-agent': { light: cursorLight, dark: cursorDark },
  grok: { light: grokLight, dark: grokDark },
  opencode: { light: opencodeLight, dark: opencodeDark },
  qwen: { light: qwenLight, dark: qwenDark },
}

export function ProviderLogo({ provider, size = 16 }: { provider: string; size?: number }) {
  const singleLogo = SINGLE_LOGOS[provider]
  if (singleLogo) {
    return <img src={singleLogo} width={size} height={size} alt="" aria-hidden className="provider-logo" />
  }

  const logos = THEMED_LOGOS[provider]
  if (!logos) return null

  return <>
    <img src={logos.light} width={size} height={size} alt="" aria-hidden className="provider-logo pl-light" />
    <img src={logos.dark} width={size} height={size} alt="" aria-hidden className="provider-logo pl-dark" />
  </>
}
