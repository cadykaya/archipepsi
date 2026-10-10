# Archipepsi — Design Conversation Transcript

> **Scope:** User-visible Archipepsi design discussion in this thread, reconstructed into Markdown for project context.
>
> **Not included:** hidden reasoning, tool calls, system/developer instructions, artifact-generation internals, and unrelated prior-chat summaries.
>
> **Authority:** This transcript preserves intent/history. The packet specs are later and authoritative when they conflict with older brainstorming.

---

## User

Crazy archipelago idea

## Assistant

Oh NO 😭 You have my full attention.

What’s the **crazy Archipelago idea**? Because after KH2 Randomizer Crimes™, I’m already expecting something deeply irresponsible and excellent.

---

## User

We make one. With a super early version of local epsilon. Lets say 6 people are playing. Were playing mario64, ocarina of time, bomb rush cyberfunk, dark souls 3, borderlands2, and our new game(ArchipEpsilon is an awful name but a funny project name). ArchipEpsilon is a pretty basic game, maybe like at the start its just a sandbox 1st person game, its logic has like 250 locations and 250 checks, they are all just entering and completing rooms/dungeons/maps. The archipelago data gets randomized and the player playing archipepsi(get it?) is given a blank room with an ip/port spot and a profile(whatever its called? Slot name?) now when we connect, the archipelago data goes to our local epsilon, who starts /making/ the game. We start with room 1, which epsilon knows ends with a check for borderlands2, and knows what that check is for. It will divide checks into the number of rooms there are per game(i mean if theres 6 other games, then we get 6 rooms(im calling them rooms but they dont have to be literally a room, i mean a map or themed set of maps/levels) divide the checks and locations into chests or boss drops or whatever epsilon wants based on the game. We can set this stuff up in the yaml i think i could be wrong. Then uh i forgot what i was saying. Do you see the vision? Also lets force it to be like blocky minecrafty 2d textures on easy flat planes. Something easy easy for a local llm to make.

## Assistant

YES. I absolutely see it 😭

The key twist is that **Archipepsi isn’t a normal APWorld with a prebuilt map** — it’s a *game that synthesizes its own campaign after it sees the rolled multiworld*. Epsilon is basically the dungeon master / level compiler.

**Archipepsi** is the correct terrible project name, by the way. Non-negotiable.

The important conceptual shift is:

> **Archipepsi is an Archipelago game whose content does not exist until the seed is running.**

The player launches Archipepsi and gets roughly:

```text
ARCHIPEPSI

Server: 192.168.1.whatever:38281
Slot Name: Skyiah
Password: optional

[ CONNECT ]
```

And yes, **slot name** is the Archipelago term.

The APWorld itself can be deliberately simple: a fixed set of abstract locations such as `Archipepsi Check 001 ... 250`, plus a small amount of native progression. Archipelago does not need to know whether Check 037 is physically represented as a chest, boss reward, platforming goal, shop purchase, or something stranger. After generation, the server knows which real item sits at that location.

Epsilon can inspect that placement and decide how the check should be expressed. If Check 037 contains a Dark Souls item, Epsilon can make a Dark-Souls-ish blocky challenge; if it contains an Ocarina item, it can make a Zelda-ish room; if it belongs to Borderlands, it can lean into crude FPS combat.

The crucial feasibility trick is that Epsilon should not be asked to “program a videogame.” Archipepsi ships with a box of supported Legos:

```text
GEOMETRY
- cube
- plane
- ramp
- stairs
- pillar
- platform
- wall

INTERACTIONS
- reward
- pickup
- button
- door
- enemy
- boss-ish enemy
- finish trigger

THEMES
- grass
- stone
- brick
- metal
- neon
- dirt
- lava
- void

ENEMIES
- melee
- ranged
- charger/brute/etc.

OBJECTIVES
- kill enemies
- reach exit
- collect/activate
- platforming
```

Epsilon outputs validated structured data instead of code. Godot turns that data into the actual scene.

The blocky Minecraft-ish aesthetic is therefore a huge advantage: flat/simple materials, primitive meshes, no Blender, no generated rigs, no generated shaders, no complicated art pipeline.

Another important rule: **Epsilon must not invent Archipelago logic after the seed is generated.** Archipelago owns formal reachability. Epsilon can decide how already-legal checks are expressed, but cannot silently make a formally available check depend on a future ability the AP solver never knew about.

The game can generate in chunks rather than generating all 250 checks at startup. Connect, scout enough state, build the next Zone, play it, then generate later content while preserving accepted generated JSON in the save.

Eventually the whole thing becomes:

> Archipelago is the randomized circulatory system; Epsilon is a dungeon master continuously authoring the sixth game around the seed.

---

## User

I like the progression items and i also want it to give the player the same thing the player gives someone else, soo if we give a doom olayer the super shotgun, then archipepsi makes a super shotgun. Maybe we also add coins and stick them into other peoples games, they give us coins and we can buy extra items that we found for other peoples games in the shop. And when it makes the next room/level/whatever we call it, it will account for the items we have found. Now we can also have a shop that when we buy stuff it gives it to us and to the other player. And we can let it get super random(the point lol) by letting epsilon decide what every item does. This is kinda crazy

## Assistant

YES — this is where it stops being “AI generates rooms” and becomes **a seed-specific roguelike/RPG made out of everyone else’s item pool** 😭

The “you get a local version of whatever you send” rule gives Archipepsi its own identity.

Suppose one Archipepsi Check contains:

> Super Shotgun → another player

When the Archipepsi player clears that Check:

1. Archipepsi reports the normal location completion.
2. Archipelago gives the real Super Shotgun to the real recipient.
3. Archipepsi also creates a local-only **Echo** based on that source item.

The Echo is not a new Archipelago item. It is campaign-local state.

Epsilon might interpret Super Shotgun as:

- many pellets
- huge knockback
- huge backwards recoil
- maybe a movement use

Then future Zones see that the player owns that Echo and can make situations where recoil is useful.

This works for weird semantic items too. Epsilon is allowed to reinterpret them, but only using mechanics we have actually implemented. The key safety rule is:

> Epsilon can invent combinations of supported mechanics, not arbitrary executable mechanics.

So the engine might expose verbs like damage, projectile, recoil, grapple, dash, gravity modification, speed modification, heal, shield, etc. Epsilon decides how an item maps onto those verbs.

Coins fit Archipelago nicely as real Archipepsi items. Other players can find `Epsilon Coin` for Archipepsi. Archipepsi reconstructs its coin balance from delivered items and keeps a local “coins spent” ledger.

The shop is another presentation of real unchecked Archipepsi locations. If the shop shows:

```text
[5 coins] Hookshot
[8 coins] Conference Call
```

buying one simply completes the corresponding Archipepsi location. The real item goes to its real recipient, and Archipepsi gets the local Echo.

The important safety wrinkle is that shop-only progression could deadlock because Archipelago does not know our local money state. Therefore shop stock should be an **alternate/early clear**: if it is not purchased, it eventually returns to the normal challenge pool.

That creates the feedback loop:

> other players find Coins for you → you buy one of their real items → they receive progression → you receive Epsilon’s cursed Echo → future generated content incorporates it.

Once Epsilon invents an Echo for a source location, that definition is saved and becomes canon for that seed.

---

## User

For now, as a proof of concept, i say we make a team of me, you, and claude opus 5. We all work on this until its playable. Then we let claude opus 5 play as epsilon(weve seen its work so far with “claudey”) and if everything works and its fun, we move to a local model.

## Assistant

That is the right order: **prove the game loop with an absurdly capable “fake Epsilon” first, then shrink the intelligence requirement later.**

We should not start by solving local Epsilon. We should make Epsilon a replaceable provider.

The division is roughly:

- **Skyiah:** game director / tester / final arbiter of whether this is fun.
- **ChatGPT:** architecture, integration rules, design/spec work, debugging/review.
- **Claude:** heavy implementation agent and the first runtime Epsilon provider.

The repo itself should become the coordination layer rather than passing design decisions between chats.

A useful project shape is:

```text
/docs
/game
/bridge
/apworld
/schemas
/tests
```

The game should never know which model is behind Epsilon. It asks a provider for a structured Zone/Echo result; today that provider is Claude, later it can be a local model.

The first POC should be much smaller than 250 Checks. **30** is enough to prove the scary parts.

The first real milestone is:

1. connect to AP
2. scout a blank Archipepsi location
3. obtain its real recipient/item metadata
4. give that context to Epsilon
5. get valid Zone data
6. instantiate ugly block geometry
7. clear the Check
8. send the real AP item
9. generate the local Echo
10. use that Echo
11. let a later Zone see it

Then prove the Coin/shop loop.

At runtime Claude must not emit GDScript. It outputs a constrained JSON/data contract. That is what makes future local-model replacement plausible.

The long-term experiment becomes:

> Is Archipepsi fun with a very capable Epsilon, and if yes, how small/dumb can Epsilon get before it stops being fun?

---

## User

Quick sanity check. Is all of this possible? Anything we would have to cut? Do we make our own fork of godot or whatever? Ill start a project when we get home

## Assistant

**Yes. The core idea is actually possible.** There is no obvious Archipelago/Godot limitation that kills it.

We absolutely do **not** need a Godot fork. Stock Godot 4 gives us first-person 3D, runtime scene construction, primitive meshes, physics, materials, JSON, HTTP/WebSocket support, and enough flexibility for the POC.

The Archipelago side also fits: the APWorld can expose abstract Checks, the runtime client can scout their placement information, and completing them can use normal location-check behavior.

The important boundaries are:

- Do not let Epsilon execute arbitrary generated code.
- Do not let Epsilon retroactively change formal AP reachability.
- Let Epsilon compose a supported mechanic vocabulary instead.
- Keep native AP progression separate from emergent Echo progression.
- Keep coin spending local while Coin delivery remains real AP state.
- Treat shop purchases as normal real locations, but never make money the only permanent route to a logically necessary Check.
- Start with a much smaller POC: ~30 Checks, simple block graphics, small enemy/effect catalogs.
- Use normal Godot; development may involve an Archipelago source checkout/fork for APWorld work, but final distribution can be an `.apworld` plus the game.

The smallest convincing victory remains:

> Connect Godot/bridge to AP, scout one location, let Epsilon build an ugly playable challenge, clear it, send the real AP item, and acquire/use the generated Echo.

If that works, the crazy part is real.

---

## User

Great! We need a design doc i think. Whatever we can iron out on paper. Ideally we give it to claude fable 5 and it makes on its own with 4 hours if uninterrupted code. Soo we need literally everything ironed out and right here in paper(or md lol) and when you make that, it will be unfinished because youbstruggle with long horizon tasks 💀 but ill look it over with you when your first lass is done and we will upgrade it until its ready :>

## Assistant

Agreed. The design goal becomes: **remove every excuse the coding agent has to make a product decision.**

The first design pass should freeze:

- POC scope
- repo layout
- APWorld behavior
- Godot architecture
- generation schemas
- Echo rules
- shop/coin behavior
- saves/reconnects
- validation/fallbacks
- tests
- autonomous build order

One immediate design trap was identified before writing the first pass: shop purchases cannot be the only way to clear a location, because Archipelago’s solver does not understand the local `coins_spent` economy. Unsold shop stock therefore has to return to the normal challenge pool.

A first monolithic spec was created as:

`ARCHIPEPSI_POC_DESIGN_SPEC_v0.1.md`

It intentionally erred on the side of writing down concrete decisions so we could review and bully them later rather than leaving Claude to invent them.

---

## User

Yeaah. Look it over yourself i probably dont have to tell you why

## Assistant

Yep 💀 The right review mode is hostile code review, not “good job past me.”

The v0.1 audit found several meaningful problems:

- Epsilon had too much ownership over AP bookkeeping.
- Generated Zones were allowed to hard-require owned Echoes even though we had no reachability proof.
- The shop existed both inside generated Zones and in the fixed Hub in different parts of the spec.
- The networking description reinvented more Archipelago client behavior than necessary.
- `ReceivedItems`/reconnect handling needed a much more authoritative model.
- The build scope was still too wide for a first autonomous pass.
- The mock/live examples accidentally introduced a DOOM player even though the named six-game POC did not contain DOOM.

The corrected v0.2 principles became:

- deterministic code chooses which real AP locations go into Zones/shop stock
- Epsilon only designs presentation around locations it is explicitly given
- no mandatory Echo-gated traversal in the POC
- Hub-only shop
- linear chamber-template generation instead of arbitrary model-placed geometry
- current Archipelago `CommonContext` infrastructure should be reused where possible
- item handling should request remote + local + starting items
- automatic location scouting should not silently create hints
- `ReceivedItems` must be treated as authoritative reconstructed inventory state
- pending Check/shop transactions must be persisted before network send
- race-mode rooms should be refused for the POC
- generation gets one repair attempt, then deterministic fallback
- the first catalogs should be smaller

A hardened second monolithic spec was created as:

`ARCHIPEPSI_POC_DESIGN_SPEC_v0.2.md`

---

## User

Yea its better but

## Assistant

…but there’s still a **“Claude could technically follow this and still build the wrong game”** feeling.

v0.2 is safer, but one giant file is trying to be:

1. game design document
2. technical architecture
3. APWorld spec
4. Epsilon contract
5. autonomous coding instructions
6. test plan

That creates long-context failure modes of its own.

The better next step is a packet:

```text
DESIGN.md
TECHNICAL_ARCHITECTURE.md
EPSILON_SPEC.md
APWORLD_SPEC.md
IMPLEMENTATION_PLAN.md
ACCEPTANCE_TESTS.md
```

with a clear authority order.

The remaining design work is mostly about exact game feel rather than architecture: movement numbers, Zone pacing, Echo design philosophy, how weird is too weird, target-game influence, shop UX, reward presentation, waiting for progression, finale behavior, and what “fun” means for the POC.

---

## User

Well once its a zipped packet i stop being able to see it. Actually yes lets do it. Include this whole chat as a md in there too
