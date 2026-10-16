# Importing the Freight Bay kits into SigmAudio

Run these from a SigmAudio checkout. They use SigmAudio's own importer, which accepts only CC0 or self-recorded audio. `kits-entries.json` holds the exact records these commands produced, for checking.

The combat parts also use the four Overclock round-2 guitar kits. Import them first, following `../../combat-piece/round-2/NOTES.md` and its `guitar-samples/` folder.

```bash
K=<path to this folder>; FS=https://freesound.org/people
node tools/samples-import.mjs add --dir $K/bayMachine --id bayMachine --label "Freight bay: machines" --type kit --license CC0 --author "mark646, kyles, mcpable, o_ciz, ronnyver (Freesound)" --source "$FS/mark646/sounds/209219/ ; $FS/mark646/sounds/209217/ ; $FS/kyles/sounds/453303/ ; $FS/mcpable/sounds/131934/ ; $FS/o_ciz/sounds/475427/ ; $FS/ronnyver/sounds/488589/" --blurb "A stamping press, a hydraulic cutter, air valves and a struck plate, cut into a drum kit." --gain-db -4
node tools/samples-import.mjs add --dir $K/bayHeavy --id bayHeavy --label "Freight bay: heavy impacts" --type kit --license CC0 --author "magnuswaker, ldezem, davidlay1, mark646 (Freesound)" --source "$FS/magnuswaker/sounds/614063/ ; $FS/magnuswaker/sounds/614062/ ; $FS/ldezem/sounds/386302/ ; $FS/davidlay1/sounds/416080/ ; $FS/mark646/sounds/209217/" --blurb "Heavy metal impacts, a pneumatic hammer and a big pressure release." --gain-db -4
node tools/samples-import.mjs add --dir $K/bayHorn --id bayHorn --label "Freight bay: air horn" --type pitched --license CC0 --author "mcpable (Freesound)" --source "$FS/mcpable/sounds/131930/" --blurb "One tone of an industrial air horn, tuned and playable."
node tools/samples-import.mjs add --dir $K/bayMotor --id bayMotor --label "Freight bay: electric motor" --type pitched --license CC0 --author "jasonLON (Freesound)" --source "$FS/jasonLON/sounds/125401/" --blurb "A steady electric motor whir, tuned to B and playable as a drone."
node tools/samples-import.mjs add --dir $K/bayHydraulic --id bayHydraulic --label "Freight bay: hydraulic hum" --type pitched --license CC0 --author "kyles (Freesound)" --source "$FS/kyles/sounds/637811/" --blurb "A scissor lift's hydraulic hum, tuned to F and playable."
node tools/samples-import.mjs add --dir $K/bayConveyor --id bayConveyor --label "Freight bay: conveyor" --type atmosphere --license CC0 --author "Kinoton (Freesound)" --source "$FS/Kinoton/sounds/519027/" --blurb "An industrial conveyor belt running, as a seamless loop." --root 60
```

`prep/` shows how the kit files were made:
- `raw-downloads/` holds the Freesound previews exactly as downloaded;
- `slice.py` and `hornfix.py` hold every cut, fade and tuning step;
- `edits.json` is the log those scripts wrote.

To re-run them, put the downloads in `raw/`, convert them to 44.1 kHz mono WAVs in `wav/`, and run the scripts from that folder.
