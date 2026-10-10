# schemas — the binding contract

Copy this directory **verbatim** into `bridge/archipepsi_bridge/schemas/`. Do not
retype the models from the prose: the prose describes them, this code *is* them.

```bash
pip install pydantic pytest
python -m pytest -q        # 37 tests
python export.py generated # JSON Schema + constants.gd
```

| File | Role |
|---|---|
| `constants.py` | Every gameplay number. Single source of truth. `SAFE_BASE_JUMP_GAP` is *derived* from the jump arc, not typed in. |
| `zone.py` | Zone contract. Chambers are a discriminated union on `type`. |
| `echo.py` | Echo contract. Discriminated on `activation`; composition rules are structural. |
| `protocol.py` | Campaign state, save format, and the Godot↔bridge messages. |
| `export.py` | Generates JSON Schema and `constants.gd`. Never hand-edit its output. |
| `test_schemas.py` | 37 tests. Each pins a rule v0.3 stated in prose and could not enforce. |

The modules use relative imports with an absolute fallback, so they work both
standalone here and nested inside the bridge package.

## Why this exists

v0.3 said "define an equivalent Pydantic model and JSON Schema" from an example.
That meant three validators (Pydantic, JSON Schema, and whatever Godot did
defensively) that had to agree, all derived by hand from prose. Here Pydantic is
the source and everything else is generated.

Three guarantees that were prose promises are now unrepresentable states:
a Zone cannot express a mandatory Echo gate, a passive Echo has no cooldown
field, and a modifier effect cannot exist without something to modify.
