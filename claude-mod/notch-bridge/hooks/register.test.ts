import { expect, test } from 'claude-code/testing'

const HOME = '/Users/test'
const FOLDER = `${HOME}/Library/Application Support/BoringNotchClaude`
const SESSION_FILE = `${FOLDER}/sessions/s1.json`

type Write = { path: string; text: string }

// Writes are queued behind each other and not awaited by the hooks, so let them drain.
async function settle(): Promise<void> {
  for (let i = 0; i < 200; i++) await Promise.resolve()
}

// The hooks below stand for the engine: they answer the calls the mod makes on `$`
// and record every file it writes.
function engine(on: any): Write[] {
  const writes: Write[] = []
  on('env.get', () => ({ value: HOME }))
  on('session.id', () => ({ value: 's1' }))
  on('session.cwd', () => ({ value: '/Users/test/Code/website' }))
  on('clock.now', () => ({ value: 1_700_000_000_000 }))
  on('fs.write', (_: unknown, e: Write) => {
    writes.push(e)
    return { value: undefined }
  })
  on('session.start', (_: unknown, e: { cwd: string }) => ({ cwd: e.cwd }))
  on('turn.start', (_: unknown, e: { turnId: string }) => ({ turnId: e.turnId }))
  on('turn.complete', () => ({ text: '' }))
  on('tool.call', () => ({ result: {} }))
  on('classic.PermissionRequest', () => ({}))
  on('session.measure', (_: unknown, e: { changed: string[] }) => ({ changed: e.changed }))
  on('session.end', (_: unknown, e: { sessionId: string }) => ({ sessionId: e.sessionId }))
  return writes
}

function lastSession(writes: Write[]): Record<string, unknown> {
  const mine = writes.filter(w => w.path === SESSION_FILE)
  expect(mine.length > 0).toBe(true)
  return JSON.parse(mine[mine.length - 1].text)
}

const turnEnd = { answer: 'ok', durationMs: 10, isAborted: false, turnId: 't1', reason: 'answer' as const }

test('a turn goes from working to done and keeps the prompt', async ($, on) => {
  const writes = engine(on)

  await $.session.start({ cwd: '/Users/test/Code/website', surface: 'desktop', isInteractive: true })
  await settle()
  expect(lastSession(writes).status).toBe('idle')

  await $.turn.start({ text: '  Fix the\n navbar  ', turnId: 't1' })
  await settle()
  expect(lastSession(writes)).toEqual(expect.objectContaining({ status: 'working', prompt: 'Fix the navbar' }))

  await $.tool.call({ tool: 'Bash', command: 'ls' })
  await settle()
  expect(lastSession(writes).status).toBe('working')

  await $.turn.complete(turnEnd)
  await settle()
  expect(lastSession(writes)).toEqual(
    expect.objectContaining({ sessionId: 's1', status: 'done', prompt: 'Fix the navbar', surface: 'desktop' }),
  )
})

test('a permission dialog marks the session as needing you until the tool is answered', async ($, on) => {
  const writes = engine(on)
  await $.session.start({ cwd: '/Users/test/Code/website', surface: 'desktop', isInteractive: true })

  await $.classic.PermissionRequest({ tool_name: 'Bash', tool_input: { command: 'rm -rf build' } })
  await settle()
  expect(lastSession(writes)).toEqual(expect.objectContaining({ status: 'needs_you', tool: 'Bash' }))

  await $.tool.call({ tool: 'Bash', command: 'rm -rf build' })
  await settle()
  expect(lastSession(writes).status).toBe('working')
})

test("a subagent's turns leave the session's status alone", async ($, on) => {
  const writes = engine(on)
  await $.session.start({ cwd: '/Users/test/Code/website', surface: 'desktop', isInteractive: true })
  await $.turn.start({ text: 'main task', turnId: 't1' })
  await settle()

  await $.turn.complete({ ...turnEnd, turnId: 't2', agentId: 'a1' })
  await settle()
  expect(lastSession(writes).status).toBe('working')
})

test('plan limits are written when they change, and only then', async ($, on) => {
  const writes = engine(on)
  const measure = {
    context: { window: 200_000 },
    rateLimits: [
      { kind: 'five_hour', percentUsed: 18, resetsAt: '2026-11-02T23:30:00.000Z' },
      { kind: 'seven_day', percentUsed: 29, resetsAt: '2026-11-08T09:00:00.000Z' },
    ],
  }

  await $.session.measure({ ...measure, changed: ['context'] } as any)
  await settle()
  expect(writes.some(w => w.path === `${FOLDER}/limits.json`)).toBe(false)

  await $.session.measure({ ...measure, changed: ['rateLimits'] } as any)
  await settle()
  const limits = writes.filter(w => w.path === `${FOLDER}/limits.json`)
  expect(limits.length).toBe(1)
  expect(JSON.parse(limits[0].text)).toEqual(
    expect.objectContaining({
      five_hour: { used_percentage: 18, resets_at: '2026-11-02T23:30:00.000Z' },
      seven_day: { used_percentage: 29, resets_at: '2026-11-08T09:00:00.000Z' },
    }),
  )
})

test('the session file says ended when the session ends', async ($, on) => {
  const writes = engine(on)
  await $.session.start({ cwd: '/Users/test/Code/website', surface: 'desktop', isInteractive: true })
  await $.session.end({ reason: 'other', sessionId: 's1', resume: {} } as any)
  await settle()
  expect(lastSession(writes).status).toBe('ended')
})
