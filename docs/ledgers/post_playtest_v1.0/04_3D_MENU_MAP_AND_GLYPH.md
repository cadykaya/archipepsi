# 04 — Real 3D pause interface, equipment and spatial memory

## 1. Owner requirement

The menu exists in **actual 3D space**, uses **Glyph-authored fonts and textures**, and follows the owner's inside-of-a-box presentation. Escape pauses the game and opens Pause/Settings. Large left/right arrows rotate between four inward-facing pages. Left proceeds Settings → Equipment/Inventory → 3D Map → Objectives/Lore/Story → Settings; right reverses it.

This is not a static screenshot on a rectangle, an exterior cube viewed from outside, a scale-to-zero tab animation, or a long equipment event list with a 3D frame around it.

## 2. Reference to reuse, not misrepresent

`cadykaya/Caster-Guide-to-Fishing`, inspected at `a0eb2e4328dcc92ad8ae4856711691055b2faca3`, contains `scripts/ui/game_menu.gd` and `scripts/ui/inventory_slot.gd`. The implementation explicitly describes a BG3-style inventory and builds equipment around a character preview with a six-column bag grid, selected-item information, comparisons and drag-related handling. It pauses the game and cycles tabs. Its page animation is a horizontal squeeze, **not the requested inside-box rotation**. This packet does not claim the reference was rendered or usability-tested here. [S07]

Reuse the interaction/layout lessons and appropriate independent components. Do not port fishing-specific slots, bait, rods, class mechanics or a second save/fold backend into Archipepsi. Bind to its actual supported slots and item identities. Check the source licence before literal code reuse; an original adapted interface is always separable from copied implementation.

## 3. Proposed runtime architecture

Use a dedicated menu scene with its own controlled camera/render world, four inward-facing panel surfaces and real transforms. It is isolated from the dungeon's walls, lighting, combat physics and field of view. Ordinary UI controls can render to textures displayed on these real 3D surfaces; the information and click targets remain live. Equipment and map previews can have depth behind their panel frames.

Godot's viewport model supports rendering to textures and separate 3D worlds; SubViewports do not receive input automatically in every embedding. Its official GUI-in-3D demo is a starting reference for forwarding input. Confirm compatibility with the project's pinned Godot 4.5.1; do not upgrade the engine to copy a current demo. [S11–S13]

**Proposed division:** Godot owns geometry, camera, rotation, input, text, state and miniature layout. Glyph owns font glyphs/metrics, panel materials, nine-slice borders, item/circuit/map icons, arrow art and state artwork. Dynamic names, descriptions, amounts and binds are never painted into a whole-screen image.

At rest, the selected page faces the camera squarely and fills a readable area. Perspective should sell the turn, not shrink outer columns. The exact angular easing, camera distance, panel resolution and duration are measured choices, not prescribed numbers here. Offer a reduced-motion transition while preserving the underlying 3D scene and page order.

## 4. Pause is a world boundary, not an input hold

**Owner requirement:** gameplay pauses. Proposed policy: the dungeon, AI, projectiles, physics machinery, cooldowns and temporary gameplay-effect lifetimes stop advancing; menu animation and its previews continue. The external AP world is not paused—keep the connection and legitimate incoming delivery alive.

Godot documents that paused physics/process modes and signals are different: signal callbacks can run even when normal processing stops. The implementation must therefore audit callback-driven launches, deferred input, timers and bridge snapshot effects, not simply set a flag and infer the entire transaction is frozen. Do not re-enable the whole gameplay physics server just to make a menu ray test work. Use appropriate menu input mapping or isolated geometric picking. [S11]

Specific race to test: the player requested consumable authorization, then paused before the response. The accepted charge is not silently refunded, and its effect is not launched into a frozen world without an agreed policy. Preserve/reconcile the pending authorization through pause, disconnect and resume using the existing D-9 accounting. Closing the menu must not turn the click that selected an item into a grenade throw.

Use ownership-aware pause/input holds so closing one menu cannot release a layout/restore hold. A modal error, equipment picker, text field or binding dialog must not accidentally unpause. Opening/closing should preserve the intended mouse mode, focus and selected page context.

## 5. Equipment face

Three visible regions form the starting layout: **equipped build**, **owned-item grid**, **selected-item detail/comparison**. Fit them to actual supported data, not a fantasy slot count. Show readable icons, item names where needed, equipped/new markers, quantities and current resolved upgrade identity. Clicking a compatible equipment slot can filter or highlight its candidates; it does not hide the entire inventory with no way back.

The grid represents current owned items/components. Upgrade-only source events belong in history associated with the resolved item, not as fake additional equippable objects. Mixed Echoes with active and passive components need explicit component presentation without silently dropping either side. Passive does not automatically mean user-toggleable. Preserve source-owned modifiers and existing fold rules.

Selected-item information answers: what it does; activation/binding; target/usage restrictions; supported slot; actual cost/cooldown/charges; differences from equipped; why an attempted equip is refused. Detailed source history can expand after the useful summary. Keep pending/refused/accepted equipment changes correlated to the real authority rather than optimistically painting a success that never arrived.

Bombs need an obvious consumable slot and current binding, remaining uses and zero state. Distinguish **none owned**, **owned but not equipped**, **equipped and empty**, **pending authorization**, and **disconnected**. Natural acquisition should draw attention to the actual new item without blocking the AP transfer on an animation. Capacity upgrades and refill rules remain separate decisions.

Support mouse click, keyboard/controller navigation and a usable non-drag equip action. Drag-and-drop may be offered, but it must work while paused, preserve identity during a snapshot refresh, and cancel safely on page turn or close. Search must not trigger Q/C or movement. Use real binding names, not separately hard-coded keycaps. A direct Tab-to-equipment shortcut is a recommendation, not an owner-specified requirement.

## 6. Map facts: one projection, two views

Keep immutable room, edge, gate and mechanism identifiers for code/saves. Add or reuse stable display names for large ordinary rooms and setpieces. Both maps and relevant objectives show the same names. If a setpiece repeats, attach a meaningful location qualifier; do not randomly rename it on reload. Debug IDs can be available to a report tool without being the principal map label.

Build the map from the **accepted realized layout**: actual room envelopes/geometry, connector chains, vertical changes and meaningful passage openings. The overview graph alone can misrepresent a turning 76-m connector as a straight line; the map must not repeat that old traversal-harness error. A miniature should preserve enough real shape to recognize rooms while removing decoration that obscures navigation.

A shared read model supplies discovered room/connection identities, player location/facing, known gate state/reason, circuit identity, known terminals and objective references. Presentation colours are not permissions. A local map can display authoritative updates but cannot grant access or change progression by editing its copy.

**Green circuit example:** green supply → green receiver → green door. The minimap draws a green blocker on the connector through that door. The 3D map draws a small pulsing green indicator at that passage/area. If the player merely owns the supply, the barrier stays; after installation, it changes only when the real passage state changes. A jammed, closing or unknown passage is not silently labelled open. A reversible closure reappears correctly. An accepted permanent opening survives re-entry.

Supplement colour with reason symbols and readable details: key, power, mechanism, blocked/unsafe. Two unrelated circuits in one place need distinct identity even if colours are reused elsewhere. Do not reveal undiscovered control locations or hidden Check contents as a side effect of the map's access to complete generation data.

## 7. Minimap and 3D map interaction

The minimap stays visible during normal exploration/combat. Show position, facing, nearby actual connectors, useful known markers and an unambiguous floor/elevation convention. Do not cover the action with long labels; full names/details can appear on focus or the large map. “Always visible” does not require rendering it over the full pause map.

The map face contains a rotate/zoom/pan miniature. Offer cutaway roofs or selected-floor isolation so stacked rooms remain readable. Recenter on the player, distinguish current from other floors, and preserve useful inspection state through page changes. Mapping controls must not compete with the page-turn arrows. Known destinations and return routes should remain inspectable without spoilers.

Use **render-only** map geometry/resources. Never duplicate live scripts, collision, enemies, reward nodes, sounds or state setters into a small copy. Opening the map must not send a second Check, run a room `_ready` side effect or create another machine simulation. Cache appropriately and measure with a representative built Zone, not only an empty five-room mockup.

## 8. Journal and Settings faces

Journal initially lists real active objectives, completed consequences, discovered named places and appropriately earned notes. It can organize future lore/story, but the near-term delivery must not invent a finished campaign or spoil unvisited rewards. A control's recorded discovery can remind the player which door it affects; it should not reveal an undiscovered solution.

Settings includes resume, current campaign/profile information and supported options. Separate **return to Hub**, **abandon current Zone**, **quit**, and **new campaign** wherever those existing actions are offered. Destructive actions need their existing confirmation and accurate consequences. Do not change the all-Checks/abandon policy through a prettier button label.

## 9. Glyph asset handoff and visual floor

Use the inspected tooling branch in an isolated checkout for new sources. Read `AGENTS.md` and `GAME_ASSETS.md`; discover actual commands rather than infer them from an old guide. The documented relevant exports include bitmap-font `.fnt`, nine-patch panel blocks and SpriteFrames. These export resources/metadata; they do not create menu input or 3D geometry. The guide's font test names Godot 4.3, so the actual new import/interaction trial must use the project's 4.5.1. [S08]

Supply editable Glyph source identity/revision, exported asset paths/hashes, palette and metrics, states, atlas/region mapping, exact `res://` references and a consumer screenshot. The project receives assets through its normal versioned pipeline, not by runtime guessing filenames. No opening/checkpointing original approved `.glyph` files in an upgrade trial; work on copies, because Arty's trial recorded writes during opens/verifies.

Make typography a family: readable body text, distinguishable numerals, headings and keycaps. Long generated names, punctuation and unsupported characters must have a visible fallback rather than blanks. UI scale and panel sampling must be checked in the 3D consumer, including high-DPI and resizing. Decorative pixel art does not justify unreadable item descriptions. No actual font binaries are included in this planning handoff.

## 10. Completion means the real interaction works

One real item can be found, inspected, compared, equipped and unequipped through accepted/refused authority. A real new consumable is noticed and its count understood. A real named blocked door matches both maps and changes after its actual circuit operates. The player can rotate to the journal/settings and back without lost focus or a dangling drag. The gameplay world has not advanced behind the menu. Closing/reopening and cold restarting preserve correct state.

Review the in-engine menu itself at intended sizes, not only a Glyph render or a headless node census. Actual 3D construction and attractive flat screenshots are separate claims. Owner usability/visual approval remains an independent result.
