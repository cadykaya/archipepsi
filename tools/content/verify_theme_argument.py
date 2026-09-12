"""The theme is a build argument, and it cannot reach the shipped pack.

    python3 tools/content/verify_theme_argument.py

## Why this exists

Theme-pack gap 4. Every builder used to hold `THEME = "concrete_facility"`
as a module constant, so a second theme of an existing room meant editing
45 files or waiting for a runtime binder nobody has written. It is an
argument now -- `--theme <name>` after Blender's `--`, or `ART_THEME`.

The feature is the easy half. The half worth checking is the blast radius:

  * **The default must be unchanged.** `check_art_current.sh` rebuilds all
    52 builders and compares against git, so that is already proved there.
    What is proved HERE is the thing that makes it true: with no argument,
    the output directories are exactly the shipped ones.

  * **A non-default run must not be able to write a shipped asset.** One
    `--theme` typo would otherwise replace twelve approved shells with
    differently-painted ones. `git diff` would show binary churn across the
    whole pack and the only thing standing between the repository and that
    would be somebody remembering. So the redirect is checked, and so is
    the guard behind it.

  * **An unknown theme must refuse.** `--theme temple_ruins` would
    otherwise paint every surface from an empty table and export an asset
    nobody could tell from a real one by looking at it.

`common.py` imports `bpy`, so each case runs in its own subprocess through
Blender rather than by importing it here.
"""
import os
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLENDER = os.environ.get("BLENDER", os.path.join(ROOT, ".tools/blender/blender"))

PROBE = r'''
import json, sys, os
sys.path.insert(0, os.path.join(%r, "tools", "blender"))
import common
print("PROBE " + json.dumps({
    "theme": common.THEME,
    "is_default": common.IS_DEFAULT_THEME,
    "models": os.path.relpath(common.MODEL_DIR, %r),
    "textures": os.path.relpath(common.TEXTURE_DIR, %r),
    "house_override": common.theme_for("rusted_industrial"),
}))
''' % (ROOT, ROOT, ROOT)


def probe(args=(), env=None):
    """Import common.py under Blender and report what it resolved to."""
    script = os.path.join(ROOT, ".probe_theme.py")
    with open(script, "w") as handle:
        handle.write(PROBE)
    try:
        run = subprocess.run(
            [BLENDER, "--background", "--python", script, "--"] + list(args),
            capture_output=True, text=True,
            env={**os.environ, **(env or {})})
    finally:
        os.remove(script)
    for line in run.stdout.splitlines():
        if line.startswith("PROBE "):
            import json
            return json.loads(line[6:]), run
    return None, run


def main():
    if not os.path.exists(BLENDER):
        print("verify-theme: SKIPPED -- no blender at %s" % BLENDER)
        return 0

    problems = []

    # 1. no argument -> the shipped pack, exactly.
    got, run = probe()
    if got is None:
        problems.append("the default build did not resolve at all:\n%s"
                        % run.stderr[-600:])
    else:
        if got["theme"] != "concrete_facility":
            problems.append("the default theme is '%s', not concrete_facility"
                            % got["theme"])
        if got["models"] != os.path.join("assets", "models"):
            problems.append("the default build writes models to %s, not "
                            "assets/models" % got["models"])
        if got["textures"] != os.path.join("assets", "textures"):
            problems.append("the default build writes textures to %s, not "
                            "assets/textures" % got["textures"])
        if got["house_override"] != "rusted_industrial":
            problems.append("theme_for() lost a builder's own house theme on "
                            "a default build: %s" % got["house_override"])

    # 2. a second theme -> scratch, and nowhere near the pack.
    for args, env, how in ((["--theme", "temple_ruin"], None, "--theme"),
                           ([], {"ART_THEME": "temple_ruin"}, "ART_THEME")):
        got, run = probe(args, env)
        if got is None:
            problems.append("%s did not resolve:\n%s" % (how, run.stderr[-400:]))
            continue
        if got["theme"] != "temple_ruin":
            problems.append("%s was ignored; the build is '%s'"
                            % (how, got["theme"]))
        want = os.path.join("assets", "themed", "temple_ruin", "models")
        if got["models"] != want:
            problems.append("%s writes models to %s, which is not the scratch "
                            "tree %s" % (how, got["models"], want))
        if got["house_override"] != "temple_ruin":
            problems.append("%s did not reach a builder with its own house "
                            "theme: %s" % (how, got["house_override"]))

    # 3. an unknown theme must refuse rather than paint from nothing.
    got, run = probe(["--theme", "temple_ruins"])
    if got is not None:
        problems.append("'temple_ruins' built as '%s' instead of being "
                        "refused" % got["theme"])
    elif "is not one the palette knows" not in (run.stdout + run.stderr):
        problems.append("'temple_ruins' failed without saying why; the "
                        "message is what makes a typo findable")

    for problem in problems:
        print("verify-theme: FAIL -- %s" % problem, file=sys.stderr)
    if problems:
        return 1
    print("verify-theme: the default writes the shipped pack, a second theme "
          "writes only assets/themed/, and an unknown theme refuses.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
