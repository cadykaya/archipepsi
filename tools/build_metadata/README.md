# Build metadata for review builds

`archipepsi_build.py` describes, stamps and validates the review-build ZIPs
that `tools/*/package.sh` produce. The standard, field by field, and the
steps for a new build are in [docs/build-package-standard.md](../../docs/build-package-standard.md).

```sh
# after tools/<build>/package.sh out/
python3 tools/build_metadata/archipepsi_build.py stamp --spec tools/<build>/build-spec.json out/
python3 tools/build_metadata/archipepsi_build.py validate --strict out/*.zip

# any delivered package, old or new
python3 tools/build_metadata/archipepsi_build.py validate Archipepsi-*.zip
python3 tools/build_metadata/archipepsi_build.py infer Archipepsi-*-part*.zip
```

- `examples/`: specs for Crossing D review, Crossing D readability and Impact Lab.
- `tests/test_archipepsi_build.py`: unit tests (`python3 -m unittest discover -s tools/build_metadata/tests`).
- `tests/compat.sh`: runs Prod's unmodified package scripts from their branches and validates their real output, before and after stamping.
