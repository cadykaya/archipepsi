# Release Crossings — the 81 games: visual family and music identity

**Dess, 2026-10-17. A design table, for Prod to code later.**

**Sources:**
- the audio placement map's Appendix B, received verbatim through Condi
  ("a provisional sort by musical personality … All 81 are release
  Crossings");
- the six house visual families in code: `schemas/constants.py:1813-1820`
  `THEMES`.

**Today**, only 6 games have a set family (`THEME_BY_GAME_HINT`,
`:1863-1870`); every other game gets one by name hash (`epsilon/fallback.py`
`_theme_for`).

**Rules used:**
1. **Visual family is one of the six** (as the code describes them):
   - `concrete_facility`: bright test-chamber facility, clean concrete,
     vents;
   - `rusted_industrial`: refinery, corrugated steel, scaffold;
   - `neon_transit`: underground station, tile, signage, neon spill;
   - `gothic_stone`: castle stone, iron, torchlight;
   - `temple_ruin`: cracked sandstone, roots, brass;
   - `void_glitch`: dev surfaces, a missing-texture checker.
2. **Music identity is one of nine:** the six family musics plus the
   mood musics **cozy**, **ocean** and **strategy**.
3. **Default:** a game keeps the audio map's family for **both** its look
   and its music. I differ only where the game's own world clearly reads
   as another family.
4. **OPEN** means my call differs from the audio map, in look or music, or
   is a coin-flip. Those are the ones Skyiah would notice. ★ marks my
   pick. **12 rows are OPEN** (§3); two of them change both look and music.

---

## 1. The table

**Key:** look = visual family; music = music identity.

### concrete_facility group (22)
| Game | Look | Music | Note |
|---|---|---|---|
| Super Mario 64 | concrete_facility | concrete_facility | Already the code hint |
| Super Mario World | concrete_facility | concrete_facility | |
| Super Mario Land 2 | concrete_facility | concrete_facility | |
| Yoshi's Island | concrete_facility | concrete_facility | |
| Kirby's Dream Land 3 | concrete_facility | concrete_facility | |
| Mario & Luigi Superstar Saga | concrete_facility | concrete_facility | |
| A Hat in Time | concrete_facility | concrete_facility | |
| Celeste (Open World) | concrete_facility | concrete_facility | Close: mountain and ruins could read `temple_ruin`. Kept bright. |
| Celeste 64 | concrete_facility | concrete_facility | As above |
| Jak and Daxter | concrete_facility | concrete_facility | Close: the Precursor ruins suggest `temple_ruin`. Kept bright. |
| Sonic Adventure 2 Battle | concrete_facility | concrete_facility | Close: the city and space levels suggest `neon_transit`. |
| Mega Man 2 | concrete_facility | concrete_facility | Robot labs suit the facility |
| Mega Man 3 | concrete_facility | concrete_facility | |
| **MegaMan Battle Network 3** | **neon_transit** ★ | concrete_facility | **OPEN:** a cyber world of data paths and glowing signage |
| VVVVVV | concrete_facility | concrete_facility | Literally a space station |
| Bumper Stickers | concrete_facility | concrete_facility | Close: Archipelago-native; `void_glitch` is the alternative |
| DLCQuest | concrete_facility | concrete_facility | |
| Saving Princess | concrete_facility | concrete_facility | |
| APQuest | concrete_facility | concrete_facility | Close: as Bumper Stickers |
| Paint | concrete_facility | concrete_facility | Close: as Bumper Stickers |
| Yacht Dice | concrete_facility | concrete_facility | Close: as Bumper Stickers |
| Overcooked! 2 | concrete_facility | concrete_facility | |

### temple_ruin group (22)
| Game | Look | Music | Note |
|---|---|---|---|
| Ocarina of Time | temple_ruin | temple_ruin | Already the code hint |
| A Link to the Past | temple_ruin | temple_ruin | |
| The Legend of Zelda | temple_ruin | temple_ruin | |
| Links Awakening DX | temple_ruin | temple_ruin | |
| The Wind Waker | temple_ruin | temple_ruin | Close: the sea suggests ocean music; kept adventure |
| SMZ3 | temple_ruin | temple_ruin | A Zelda/Metroid combo; the Zelda half leads |
| TUNIC | temple_ruin | temple_ruin | |
| Secret of Evermore | temple_ruin | temple_ruin | |
| Landstalker | temple_ruin | temple_ruin | |
| Final Fantasy | temple_ruin | temple_ruin | |
| Final Fantasy Mystic Quest | temple_ruin | temple_ruin | |
| Lufia II Ancient Cave | temple_ruin | temple_ruin | |
| Faxanadu | temple_ruin | temple_ruin | |
| Adventure | temple_ruin | temple_ruin | |
| **Aquaria** | temple_ruin | **ocean** ★ | **OPEN:** an underwater game; the ocean mood fits better than ancient-adventure |
| Kingdom Hearts | temple_ruin | temple_ruin | |
| Kingdom Hearts 2 | temple_ruin | temple_ruin | |
| Timespinner | temple_ruin | temple_ruin | |
| **Hylics 2** | **void_glitch** ★ | temple_ruin | **OPEN:** surreal claymation reads as uncanny, not ancient |
| The Witness | temple_ruin | temple_ruin | Close: a clean puzzle island; ruins and nature fit |
| **Lingo** | **concrete_facility** ★ | temple_ruin | **OPEN:** abstract coloured rooms, much like a test-chamber facility |
| **Shivers** | **gothic_stone** ★ | temple_ruin | **OPEN:** a haunted museum, dread rather than ancient adventure |

### neon_transit group (5)
| Game | Look | Music | Note |
|---|---|---|---|
| Bomb Rush Cyberfunk | neon_transit | neon_transit | Already the code hint |
| Muse Dash | neon_transit | neon_transit | |
| **The Messenger** | **temple_ruin** ★ | neon_transit | **OPEN:** ninja ruins and towers. Its chiptune stays electronic. |
| Zillion | neon_transit | neon_transit | Sci-fi base corridors |
| **Super Metroid** | **temple_ruin** ★ | **gothic_stone** ★ | **OPEN:** Chozo ruins and caverns. Its score is atmospheric dread, not breakbeat. |

### gothic_stone group (9)
| Game | Look | Music | Note |
|---|---|---|---|
| Dark Souls III | gothic_stone | gothic_stone | Already the code hint |
| Blasphemous | gothic_stone | gothic_stone | |
| Castlevania - Circle of the Moon | gothic_stone | gothic_stone | |
| Castlevania 64 | gothic_stone | gothic_stone | |
| Hollow Knight | gothic_stone | gothic_stone | |
| Heretic | gothic_stone | gothic_stone | |
| Gauntlet Legends | gothic_stone | gothic_stone | |
| Inscryption | gothic_stone | gothic_stone | |
| Undertale | gothic_stone | gothic_stone | Close: the Ruins could be `temple_ruin`, and its chiptune isn't organ dread. Kept as sorted, to avoid two changes. |

### rusted_industrial group (10)
| Game | Look | Music | Note |
|---|---|---|---|
| DOOM 1993 | rusted_industrial | rusted_industrial | |
| DOOM II | rusted_industrial | rusted_industrial | |
| Factorio | rusted_industrial | rusted_industrial | |
| Satisfactory | rusted_industrial | rusted_industrial | |
| **shapez** | **concrete_facility** ★ | rusted_industrial | **OPEN:** clean, flat factory shapes; grime would misrepresent it |
| Risk of Rain 2 | rusted_industrial | rusted_industrial | Close: alien landscapes could be `temple_ruin` |
| Choo-Choo Charles | rusted_industrial | rusted_industrial | |
| Starcraft 2 | rusted_industrial | rusted_industrial | |
| Noita | rusted_industrial | rusted_industrial | Mines and caves |
| **Terraria** | **temple_ruin** ★ | **concrete_facility** ★ | **OPEN:** forests, caves, dungeons; a bright adventure score, not industrial |

### void_glitch group (2)
| Game | Look | Music | Note |
|---|---|---|---|
| ChecksFinder | void_glitch | void_glitch | |
| Meritous | void_glitch | void_glitch | |

### Music-only moods (11): the visual family is new in every row
| Game | Look | Music | Note |
|---|---|---|---|
| Stardew Valley | temple_ruin | cozy | Farm, nature, mines: warm and overgrown |
| A Short Hike | temple_ruin | cozy | Island and mountain nature |
| Pokemon Emerald | concrete_facility | cozy | Bright, clean towns and routes |
| Pokemon Red and Blue | concrete_facility | cozy | As above |
| **EarthBound** | concrete_facility ★ | cozy | **OPEN (coin-flip):** quirky suburbia; `void_glitch` suits its weirdness |
| **Subnautica** | neon_transit ★ | ocean | **OPEN (coin-flip):** glowing habitats and bioluminescence; clean `concrete_facility` modules are the alternative |
| **Raft** | rusted_industrial ★ | ocean | **OPEN (coin-flip):** scrap-built; wood and brass `temple_ruin` is the alternative |
| Civilization VI | temple_ruin | strategy | Ancient wonders |
| Wargroove | gothic_stone | strategy | Medieval fantasy castles |
| Yu-Gi-Oh! 2006 | temple_ruin | strategy | Egyptian motifs |
| Old School Runescape | gothic_stone | strategy | Medieval fantasy |

**Counts:** 22 + 22 + 5 + 9 + 10 + 2 + 11 = **81**.

**Visual totals:**

| Family | Games |
|---|---|
| concrete_facility | 26 |
| temple_ruin | 26 |
| neon_transit | 5 |
| gothic_stone | 12 |
| rusted_industrial | 9 |
| void_glitch | 3 |

**Music totals:** concrete_facility 23, temple_ruin 21, gothic_stone 10,
rusted_industrial 9, neon_transit 4, void_glitch 2, cozy 5, strategy 4,
ocean 3.

---

## 2. Notes for Prod
- **One table, replacing the hash fallback for these 81:** game name →
  (visual family, music identity).
- **A game outside the table keeps today's hash fallback.** Borderlands 2
  stays in `THEME_BY_GAME_HINT` (`rusted_industrial`). It isn't in the 81,
  and that is harmless.
- **Archipepsi itself stays `void_glitch`.**
- **Music is per identity, not per game.** Nine identities, as the audio
  map settled.
- **Names must match AP's own game strings exactly.** They are as
  archipelago.gg lists them; check with the apworld scouts.

## 3. OPEN questions for Skyiah (★ = my pick)
1. **MegaMan Battle Network 3.** Look `neon_transit` ★, or keep
   `concrete_facility`?
2. **Aquaria.** Music `ocean` ★, or keep `temple_ruin`?
3. **Hylics 2.** Look `void_glitch` ★, or keep `temple_ruin`?
4. **Lingo.** Look `concrete_facility` ★, or keep `temple_ruin`?
5. **Shivers.** Look `gothic_stone` ★, or keep `temple_ruin`?
6. **The Messenger.** Look `temple_ruin` ★, or keep `neon_transit`?
7. **Super Metroid.** Look `temple_ruin` ★ **and** music `gothic_stone` ★,
   or keep `neon_transit` for both?
8. **shapez.** Look `concrete_facility` ★, or keep `rusted_industrial`?
9. **Terraria.** Look `temple_ruin` ★ **and** music `concrete_facility` ★,
   or keep `rusted_industrial`?
10. **EarthBound.** Look `concrete_facility` ★, or `void_glitch`?
11. **Subnautica.** Look `neon_transit` ★, or `concrete_facility`?
12. **Raft.** Look `rusted_industrial` ★, or `temple_ruin`?

(Super Metroid and Terraria each change both look and music.)

**Not OPEN, but close:**
- Celeste ×2, Jak and Daxter, Sonic Adventure 2 Battle;
- the Archipelago-native small games (Bumper Stickers, APQuest, Paint,
  Yacht Dice);
- The Wind Waker, The Witness, Undertale, Risk of Rain 2.

Each keeps the audio map's family.
