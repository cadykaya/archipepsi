# Archipepsi agent instructions

Use the repository as memory. Do not reconstruct completed work from chat history.

## Cheap wake-up
On autonomous wake/heartbeat:
1. `git status`
2. `git log --oneline -3`
3. read `docs/AGENT_FRONTIER.md`
4. inspect unfinished work, then continue the next frontier item

Do **not** reread all of `NEXT_STEPS.md`, `IMPLEMENTATION_DECISIONS.md`, or the full design packet on every wake-up. Read those only when the current task needs a specific fact or section.

## Token discipline
- Search first (`rg -n ...`), then read only relevant line ranges.
- Do not dump whole source files, documents, diffs, or logs into context unless genuinely necessary.
- Successful commands need only a concise result. On failure, inspect targeted diagnostics around the error.
- Use focused tests while iterating. Run the full frontier at stage boundaries, risky cross-system changes, or before claiming a major checkpoint green.
- Keep intermediate narration terse; one short checkpoint per coherent task is enough.

## Load-bearing boundaries
Archipelago owns randomized truth. Python owns deterministic campaign/save/allocation/fold truth. Epsilon emits validated structured creative interpretation only. Godot simulates/renders and sends player intents. Persistent state changes go through validated transitions; derived mechanics come only from the interpretation-log fold and are not separately persisted. Preserve base-kit solvability.

Never weaken a test merely to pass it. Generated artifacts are regenerated from source, never hand-edited. A capability unlocks only when its **last** required dependency exists.

When the frontier changes, update `docs/AGENT_FRONTIER.md` immediately and keep `NEXT_STEPS.md` as the detailed historical/project handoff.

## Art lane: sign the reports
Every end-of-work Markdown the art lane writes -- the reports under `docs/art/reports/`, review-package READMEs, anything meant to be shared -- is signed **Arty** at the top, under the title. The art lane has a name; a report that arrives unsigned reads like it came from nowhere.

<!-- Token-discipline bootstrap authored by ChatGPT / GPT-5.6 Sol, OpenAI. -->
