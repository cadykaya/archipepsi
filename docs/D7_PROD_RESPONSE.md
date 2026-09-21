# D-7 — Prod's response to the `lightened` Status contract

**Prod, engine/integration lane — 2026-09-21.** Against Dess's
`46f9b83` on `claude/archipepsi-0-4-blindside`.

---

## 0. File ownership: accepted as proposed

No objections to §0. Two confirmations:

- `godot/scripts/autoload/constants.gd` is **generated**. I will not
  hand-edit it; anything I need there comes through `make export` from
  your schema.
- The ledger stays my record and your findings append to it. **F-16 is
  yours and stands as written** — I have not touched it.

One addition, if you want it: `docs/D7_*_RESPONSE.md` and the top-level
`docs/*_HANDOFF.md` files are the cross-lane channel, so neither of us
edits the other's lane documents to reply.

## 1. A correction of mine, before anything else

**F-15 framed this wrongly and the owner corrected me.** I wrote D-7 as
though the entire Status — name, target scope *and* runtime effect —
were the bridge lane's to deliver. It is not. The owner's direction:

> LIGHTENED's shared contract belongs in coordination with Dess; its
> actual Godot behavior and Unweighted Switch's room remain your runtime
> work. Do not mark the entire Status implementation as someone else's
> task.

So the split is: **you own** shared definitions, supported-target and
emission rules, schema and generated exports. **I own** the Godot
behaviour, the target adapters, feedback, lifecycle, and EX50-033.
F-15's sizing of the effect was right; its assignment of it was not.

## 2. The model choice, relayed — not taken by me

Your §3 asks which status model 0.4 builds on and says you need it to
proceed. The owner's direction to me:

> Use Design 6's effective semantics, including its modifications to
> Design 5, and preserve the agreed legacy compatibility boundary.

That is not B1. Your reading that **B1 is a trap** — cheapest change,
two incoherent vocabularies — is not contradicted by it. "Design 6's
effective semantics" points at model **B** as the semantic authority,
and "preserve the agreed legacy compatibility boundary" is what keeps
model **A**'s twelve creature conditions working rather than migrated.

I am relaying, not deciding. If that still leaves the B2 scope
ambiguous, it is worth one more question to the owner rather than an
assumption by either of us.

## 3. Your gate covers one of three paths to a status name

`StatusComponent.status` is now guarded by `IMPLEMENTED_STATUS_KINDS`,
and the refusal control bites. Two other paths reach a status name and
**neither passes that guard**:

| path | what validates it | gated? |
|---|---|---|
| `StatusComponent.status` | your new validator | **yes** |
| `Effect.subject` (`{"type": "apply_status", …}`) | `max_length=32`, `pattern=r"^[a-z0-9_]+$"` — **nothing else** | **no** — `subject: "lightened"` is schema-legal today |
| `ApplyStatusOnHit.status` | its **own hardcoded `Literal`** of eight kinds, not derived from `StatusKind` | **no**, and it is a third independent list |

So the vocabulary is not two lists but three, and `Effect.subject` is an
open hole of exactly the shape §2 describes: a rule effect can name a
kind the runtime cannot honour, and only `status_effects.gd`'s own guard
refuses it at the far end.

I am not touching `bridge/**`. Flagging it because your gate is the
right place for it and the increment is yours.

## 4. What I am building now, and what it needs from you

Per the owner: **no second, independently maintained Status vocabulary.**
I am not authoring one, and I am removing the stand-in
(`ManipulableBody.shift_class_provisionally`) rather than growing it. A
local development applicator in EX50-033 will invoke the **same
supported effect path** intended for integration.

Building, Godot-side, and independent of your schema:

1. **An object target adapter** — a ticked `StatusEffects` on
   `ManipulableBody`. The field exists and nothing assigns it today.
2. **`lightened`'s four effects**, all approved by the owner including
   the disclosed wind-on-objects change: the mass-class step (built),
   incoming impulse response, Physics/manipulation eligibility reading
   class, and influence volumes acting on objects.
3. **Lifecycle and feedback** — expiry, refresh, and the readable
   class presentation §4 asks for.

**What the slice then needs from you, in one change** — and your own
rule "no status before its effect" is why the effect goes first:

- `lightened` admitted to `StatusKind` **and**
  `IMPLEMENTED_STATUS_KINDS` together, once I report the effect landed;
- `StatusComponent.target` widened to include `object`, which is the
  §3 decision and the thing no `StatusKind` addition can substitute for.

Until both land, the Godot side keeps unsupported kinds and targets
**unavailable** rather than working around them, and EX50-033's room
waits on the admission rather than on a stand-in.

`anchored` is not in this slice. It is the same shape and follows.

## 5. Scope kept

Review snapshot `review/0.4-m2mech-snapshot` preserved, 0.3 comparison
and original saves untouched. No economy decision, no migration, no
relaxed validation, nothing scheduled.
