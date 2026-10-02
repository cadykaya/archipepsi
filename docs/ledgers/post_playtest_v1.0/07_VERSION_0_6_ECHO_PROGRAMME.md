# 07 — 0.6: generated visual forms, Temporal Echoes and reconstruction workshops

**Status:** accepted future direction with unselected implementation details. Glyph is explicitly required for the new menu; applying it to the entire runtime-generated Echo pipeline is a strong proposed reuse, not a capability already integrated into Epsilon. [S05, S08]

## 1. Four things that must not be conflated

**Transferred original:** a real stranded item whose transfer completes to its AP-assigned recipient.  
**Ordinary Echo:** Epsilon's kept interpretation—a gun, mod, armour, ability or other supported part of the player's build.  
**Owned consumable Echo:** a kept tool/supply with charge expenditure and refill rules; exhaustion does not erase the item.  
**Temporal Echo:** a short-lived literal recreation, visibly drawn as the source item and usable for a limited time; not permanent equipment and not an AP Check.

A Temporal Keyblade is visibly a Keyblade with coherent supported behavior, not merely a gun with that name. Pixel-art flatness alone does not make an Echo temporary: ordinary skins/side weapons/companions may also be flat generated art. Do not add clothing or house creation from the reference analogy.

## 2. Prepare, release, finalize, grant

During Zone generation, Epsilon can inspect partial source information and prepare art plus valid interpretations. This does not reveal unclaimed hidden rewards to the player. The original has not transferred and no reward has been granted.

When the player releases the Check, the original completes its transfer and Epsilon obtains the final scan. Optional local art processing must not delay, revoke or duplicate the foreign delivery. Resolve the local interpretation/upgrade against the **current** owned collection, not a stale generation-time assumption. Store a recoverable earned local grant even when a later fabrication step fails.

A related Bomb Bag may improve already-owned bombs or create a distinct item. Similar names create creative opportunity, not a forced merge rule. Sharing `lob` or another primitive alone is insufficient. Prepared alternatives/fallbacks avoid a new unbounded art job at pickup. Save the accepted art/behavior identity so restart does not redraw or reroll it.

Self-addressed originals can also produce a distinct local Echo under the accepted design. Its exact transaction and progression integration remain inherited 0.4 work where needed; this later art pipeline cannot postpone that basic obligation.

## 3. Generated appearance never invents behavior

The runtime behavior vocabulary remains validated and supported. A sprite sheet declares visual size, facing, pivots, anchor points, animation clips and suitable render settings. The associated runtime contract declares movement, targeting, collision and effects. Drawing a giant blade does not silently enlarge a hit volume; drawing hands does not implement button operation.

Companions and side weapons need real supported action/perception/lifecycle contracts, not a following billboard plus a claimed ability. Visual and collision tests must agree from the player's camera—the current flyer mismatch is the counterexample to preserve. Ranged attacks should emerge from plausible sockets on the drawing.

Use bounded retries, cached/reused assets and stable source/output hashes. A failed optional image can use an appropriate approved fallback or omit a truly optional offering before entry without losing allocated rewards. A failed required function cannot be replaced by an unrelated pretty sprite. Generated content remains data, not arbitrary downloaded executable code.

## 4. Temporal item lifetime

Accepted direction: countdown starts when deliberately taken into use, pauses in a genuinely paused menu, and survives reload with remaining time rather than a reset lifetime. Ordinary equipment remains underneath; returning to the Hub ends the temporary item rather than creating permanent storage.

Exact duration, dismissal/binding and ordinary death behavior remain open. Define launched-projectile behavior on expiry explicitly; removing the held sprite must not duplicate or retroactively refund an irreversible attack. A Temporary item should be fun to use, with a visible lifetime and a useful nearby context, not expire during several empty return corridors.

Temporal tools can greatly change an optional fight without becoming its hidden sole viable solution. A chance drop or finite-lifetime side item cannot silently become an AP progression requirement. Other appropriate owned effects should exploit the same real mechanism where legal.

## 5. Temporal Shards and small workshop setpieces

Echo creatures can leave Temporal Shards. A small coherent setpiece workshop converts shards into a literal temporary item. The display, material and assembled object show the transformation in the world. A converter is not an excuse to attach five unrelated minigames to a crafting menu.

For a boss-linked converter, accepted retry direction charges the **local opportunity**. A failed boss attempt restores that opportunity with the encounter, not a duplicable refund of loose material. Preserve useful discovered shortcuts. General-purpose stock/refill/prices remain separate decisions. The system recycles local reconstruction material; it does not hold back a second original item or reopen a foreign transfer every time the player wants a weapon.

## 6. Echo creatures and factions

Echo creatures are Epsilon-style pixel-art reconstructions of beings associated with other worlds, not the actual native Multiworld population. An accepted starting explanation for hostile ones is escaped earlier research reconstructions: making an actor's form did not guarantee obedience. Later companions are specifically stabilized/bound for cooperation; ordinary use should not randomly betray the player under an undefined “unstable” exception.

Define distinct visual language for native creatures, hostile reconstructions and friendly companions. Their allegiance, lifetime, awareness, drop eligibility and save behavior need real rules. Not every world-inspired sprite requires a full new AI implementation; reuse behavior families deliberately while preserving recognizability and honesty about what the actor can do.

## 7. Wind, spikes and bosses

Owner concept: an optional side branch provides a temporary pushing/wind tool; a boss arena has major spikes; displacement creates an environmental opportunity. The causal sequence is force → susceptible motion → actual hazard contact → hazard consequence. There is no hidden “wind colour does extra damage” shortcut.

Bracing windows, armour breakage and exact timings are workshop proposals, not settled boss specifications. The effective authority's exclusion of physics puzzles in boss arenas requires an explicit compatibility ruling before this fight ships. Preserve the documented EXPOSED exception rather than claim a universal ban on all indirect damage changes.

## 8. Proposed incremental delivery

First, one generated **weapon appearance** on an already-supported behavior, with saved identity and correct import. Then one real **side weapon**. Then one **companion** with an observable useful action. Then one **Temporal pickup/converter** and a bounded **Echo-creature** encounter. Add the wind/spike boss only after its legal/runtime prerequisites and optionality are demonstrated.

These are suggested risk-reduction slices. They are not a requirement to deliver every source world's creatures or weapons. Keep the setpiece rollout gradual; tested library breadth should increase meaningful selection, not make each Zone longer or denser.
