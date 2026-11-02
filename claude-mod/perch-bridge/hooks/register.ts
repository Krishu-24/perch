import type { EngineInterface, Register } from 'claude-code'

// Writes two kinds of small JSON files for the Boring Notch Claude tab:
//   sessions/<session id>.json  what each session is doing right now
//   limits.json                 the five-hour and weekly plan windows
// Nothing leaves the Mac, and a failed write never touches the session.

type Status = 'idle' | 'working' | 'needs_you' | 'done' | 'ended'

type SessionFile = {
  sessionId: string
  cwd: string
  surface: string | null
  status: Status
  prompt?: string
  tool?: string
  detail?: string
  updatedAt: number
}

type Windows = Record<string, { used_percentage: number; resets_at?: string }>

const DIR = 'Library/Application Support/Perch'

let base: string | undefined
let current: SessionFile | undefined
// Writes run one after another so an older state never lands last.
let writes: Promise<void> = Promise.resolve()

async function folder($: EngineInterface): Promise<string> {
  if (base === undefined) base = `${await $.env.get('HOME')}/${DIR}`
  return base
}

async function writeSession($: EngineInterface, patch: Partial<SessionFile>): Promise<void> {
  if (current === undefined) {
    current = {
      sessionId: await $.session.id(),
      cwd: await $.session.cwd(),
      surface: null,
      status: 'idle',
      updatedAt: 0,
    }
  }
  current = { ...current, ...patch, updatedAt: await $.clock.now() }
  await $.fs.write(`${await folder($)}/sessions/${current.sessionId}.json`, JSON.stringify(current))
}

async function writeLimits($: EngineInterface, windows: Windows): Promise<void> {
  const updated_at = await $.clock.now()
  await $.fs.write(`${await folder($)}/limits.json`, JSON.stringify({ ...windows, updated_at }))
}

function save($: EngineInterface, patch: Partial<SessionFile>): void {
  writes = writes.then(() => writeSession($, patch)).catch(() => undefined)
}

function saveLimits($: EngineInterface, windows: Windows): void {
  writes = writes.then(() => writeLimits($, windows)).catch(() => undefined)
}

export const register: Register = on => {
  on('session.start', ($, e, next) => {
    current = undefined
    save($, { status: 'idle', cwd: e.cwd, surface: e.surface, prompt: undefined, tool: undefined })
    return next(e)
  })

  on('turn.start', ($, e, next) => {
    if (e.agentId === undefined) {
      const prompt = e.text.trim().replace(/\s+/g, ' ').slice(0, 120)
      save($, { status: 'working', tool: undefined, detail: undefined, ...(prompt ? { prompt } : {}) })
    }
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    const isMain = e.agentId === undefined
    if (isMain) save($, { status: 'working', tool: e.tool, detail: undefined })
    const result = await next(e)
    // Allowed or denied, the wait is over and Claude carries on.
    if (isMain) save($, { status: 'working', tool: undefined, detail: undefined })
    return result
  }).catch(($, e, next) => next(e))

  // Raised only when a permission dialog is about to be shown, after rules and
  // auto mode's classifier have had their say, so it means a person must answer.
  on('classic.PermissionRequest', ($, e, next) => {
    save($, { status: 'needs_you', tool: e.tool_name, detail: 'Waiting for your approval' })
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', ($, e, next) => {
    if (e.agentId === undefined) {
      save($, { status: 'done', tool: undefined, detail: e.isAborted ? 'Stopped' : undefined })
    }
    return next(e)
  })

  on('session.end', ($, e, next) => {
    save($, { status: 'ended', tool: undefined })
    return next(e)
  })

  on('session.measure', ($, e, next) => {
    if (e.changed.includes('rateLimits') && e.rateLimits.length > 0) {
      const windows: Windows = {}
      for (const limit of e.rateLimits) {
        windows[limit.kind] = { used_percentage: limit.percentUsed, resets_at: limit.resetsAt }
      }
      saveLimits($, windows)
    }
    return next(e)
  })
}
