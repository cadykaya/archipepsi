#!/usr/bin/env python3
"""Crossing D's review build, run the way a tester launches it, with a
stand-in bridge listening where a campaign bridge would (`make
godot-crossing-d`).

    python3 tools/crossing_review_probe.py [path/to/godot] [project root]
    python3 tools/crossing_review_probe.py --exported path/to/Archipepsi-Crossing-D.x86_64
    python3 tools/crossing_review_probe.py --wine path/to/Archipepsi-Crossing-D.exe
    python3 tools/crossing_review_probe.py --lab [--exported ... | --wine ...]
    python3 tools/crossing_review_probe.py --relay [--exported ... | --wine ...]
    python3 tools/crossing_review_probe.py --weapon [--exported ... | --wine ...]

`--lab` probes the Impact Lab (the post-D G0 fixture) instead: one mode,
no enemies, its own banner and live check (`impact_lab_check.gd`).
`--relay` probes the Impact Relay (G1, D-18's room) the same way
(`impact_relay_check.gd`). `--weapon` probes the weapon-feel range, one
mode per starting treatment (`weapon_feel_check.gd`).

The first form runs the source tree through the real startup path
(`--path godot -- --crossing-d`, the main scene and autoloads the game
uses). `--exported` runs an exported build as shipped -- one executable
with its pack inside, no Godot, no import step -- and `--wine` runs the
Windows executable under Wine (Linux evidence for a Windows build, not a
Windows run).

What it proves, both yard modes (populated, and `--empty-yard`):

1. **No connection is ever attempted.** A TCP listener holds the bridge's
   own address (127.0.0.1:38290) and counts every connection, through a
   15 s run as launched and through the whole live check.
2. **The live check passes** (`godot/tests/crossing_d_check.gd`).
3. **Nothing of the player's is written.** The three files the client ever
   writes (`settings.cfg`, `loadout.cfg`, `equipment_seen.cfg`) are seeded
   in a scratch user folder and must be byte-identical afterwards; no
   other file may appear there except the engine's own log and caches.
4. **The control** (source tree only): an ordinary launch against the
   same listener DOES connect, so a zero above is the build's doing.
"""
import argparse
import glob
import hashlib
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

HOST, PORT = "127.0.0.1", 38290
# What each review build is called, how it is started from source, what it
# prints when it starts, its live check's flag and line prefix, its modes.
SCENARIOS = {
    "crossing": {"flag": "--crossing-d", "banner": "crossing-d: review build",
                 "check": "--crossing-d-check", "prefix": "[crossing]",
                 "modes": (("populated", []), ("empty", ["--empty-yard"]))},
    "lab": {"flag": "--impact-lab", "banner": "impact-lab: technical fixture",
            "check": "--impact-lab-check", "prefix": "[lab]",
            "modes": (("no enemies", []),)},
    "relay": {"flag": "--impact-relay", "banner": "impact-relay: review room",
              "check": "--impact-relay-check", "prefix": "[relay]",
              "modes": (("no enemies", []), ("heavy-hit", ["--heavy-hit"]))},
    "weapon": {"flag": "--weapon-feel", "banner": "weapon-feel: range",
               "check": "--weapon-feel-check", "prefix": "[feel]",
               "modes": (("baseline", ["--feel=baseline"]),
                         ("A heavy report", ["--feel=a"]),
                         ("B crisp snap", ["--feel=b"]),
                         ("C echo resonance", ["--feel=c"]))},
}
CONTROL_SECONDS = 20
PLAYER_FILES = ("settings.cfg", "loadout.cfg", "equipment_seen.cfg")
ENGINE_OWN = ("logs", "shader_cache", "vulkan")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

failures = []


def check(ok, what):
    print(("  ok    " if ok else "  FAIL  ") + what, flush=True)
    if not ok:
        failures.append(what)


class Listener:
    """Accepts and counts every connection on the bridge's address."""

    def __init__(self):
        self.count = 0
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.sock.bind((HOST, PORT))
        except OSError:
            print("  FAIL  %s:%d is already in use: stop the bridge (or "
                  "whatever holds it) and run this again" % (HOST, PORT))
            sys.exit(2)
        self.sock.listen(16)
        self.sock.settimeout(0.2)
        self.running = True
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _serve(self):
        while self.running:
            try:
                conn, _ = self.sock.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            self.count += 1
            conn.close()

    def stop(self):
        self.running = False
        self.thread.join(1.0)
        self.sock.close()


def snapshot(folder):
    out = {}
    for base, _dirs, files in os.walk(folder):
        rel = os.path.relpath(base, folder)
        if rel.split(os.sep)[0] in ENGINE_OWN:
            continue
        for name in files:
            path = os.path.join(base, name)
            with open(path, "rb") as handle:
                out[os.path.relpath(path, folder)] = hashlib.sha256(
                    handle.read()).hexdigest()
    return out


class Launch:
    """How this build is started, and where its player folder is."""

    def __init__(self, args, scratch, scenario):
        self.args = args
        self.scenario = scenario
        self.home = os.path.join(scratch, "player")
        self.env = dict(os.environ, XDG_DATA_HOME=self.home)
        if args.wine:
            self.prefix = os.path.join(scratch, "wineprefix")
            self.env.update(WINEPREFIX=self.prefix, WINEDEBUG="-all",
                            WINEDLLOVERRIDES="mscoree,mshtml=")
            subprocess.run(["wineboot", "-i"], env=self.env,
                           capture_output=True, timeout=600)
            users = glob.glob(os.path.join(self.prefix, "drive_c", "users", "*",
                                           "AppData", "Roaming"))
            users = [u for u in users if "/Public/" not in u]
            self.folder = os.path.join(users[0], "Godot", "app_userdata",
                                       "Archipepsi")
        else:
            self.folder = os.path.join(self.home, "godot", "app_userdata",
                                       "Archipepsi")

    def command(self, extra, check_run):
        a = self.args
        engine = ["--headless"] + (["--fixed-fps", "60"] if check_run else [])
        if a.wine:
            return ["wine", os.path.abspath(a.wine)] + engine + ["--"] + extra
        if a.exported:
            return [os.path.abspath(a.exported)] + engine + ["--"] + extra
        return ([a.godot] + engine + ["--path", os.path.join(a.root, "godot"),
                                      "--", self.scenario["flag"]] + extra)

    def run(self, extra, seconds, check_run=False):
        cmd = self.command(extra, check_run)
        try:
            done = subprocess.run(cmd, env=self.env, capture_output=True,
                                  timeout=seconds)
            out = (done.stdout + done.stderr).decode("utf-8", "replace")
            return done.returncode, out
        except subprocess.TimeoutExpired as expired:
            out = (expired.stdout or b"") + (expired.stderr or b"")
            if self.args.wine:
                subprocess.run(["wineserver", "-k"], env=self.env,
                               capture_output=True)
            return None, out.decode("utf-8", "replace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("godot", nargs="?",
                        default=os.path.join(REPO, "godot-bin", "godot"))
    parser.add_argument("root", nargs="?", default=REPO)
    parser.add_argument("--exported")
    parser.add_argument("--wine")
    parser.add_argument("--log", help="keep each run's full output here")
    parser.add_argument("--lab", action="store_true",
                        help="probe the Impact Lab instead of Crossing D")
    parser.add_argument("--relay", action="store_true",
                        help="probe the Impact Relay instead of Crossing D")
    parser.add_argument("--weapon", action="store_true",
                        help="probe the weapon-feel range instead")
    args = parser.parse_args()
    scenario = SCENARIOS["weapon" if args.weapon else "relay" if args.relay
                         else "lab" if args.lab else "crossing"]
    args.godot = os.path.abspath(args.godot)
    args.root = os.path.abspath(args.root)
    scratch = tempfile.mkdtemp(prefix="crossing-probe-")
    launch = Launch(args, scratch, scenario)
    what = ("the Windows build under Wine: %s" % args.wine) if args.wine \
        else ("the exported build: %s" % args.exported) if args.exported \
        else ("the source tree: %s" % args.root)
    print("[probe] %s" % what)
    os.makedirs(launch.folder, exist_ok=True)
    seeds = {
        "settings.cfg": "[settings]\nfield_of_view=97.0\nmouse_sensitivity=0.41\n",
        "loadout.cfg": "[favourites]\nsentinel=[\"do-not-touch\"]\n",
        "equipment_seen.cfg": "[seed/slot]\nseen=[\"do-not-touch\"]\n",
    }
    for name, text in seeds.items():
        with open(os.path.join(launch.folder, name), "w") as handle:
            handle.write(text)
    before = snapshot(launch.folder)

    listener = Listener()
    print("[probe] a stand-in bridge listens on %s:%d" % (HOST, PORT))
    for mode, extra in scenario["modes"]:
        code, out = launch.run(extra, seconds=15)
        if args.log:
            with open(os.path.join(args.log, "launched-%s.log"
                                   % mode.replace(" ", "-")), "w") as f:
                f.write(out)
        # The banner reaches stdout, or -- for a windowed Windows build,
        # whose stdout may go nowhere -- the engine's own log file.
        logged = ""
        log_file = os.path.join(launch.folder, "logs", "godot.log")
        if os.path.exists(log_file):
            with open(log_file, encoding="utf-8", errors="replace") as handle:
                logged = handle.read()
        started = scenario["banner"] in out + logged
        check(started, "%s, as launched: the build starts (%s)"
              % (mode, "its banner line printed" if started else
                 "no banner; exit %s" % code))
        time.sleep(0.3)
        check(listener.count == 0, "%s, as launched, 15 s: %d connection "
              "attempt(s) to the bridge's address" % (mode, listener.count))
        code, out = launch.run(extra + [scenario["check"]], seconds=2400,
                               check_run=True)
        if args.log:
            with open(os.path.join(args.log, "check-%s.log"
                                   % mode.replace(" ", "-")), "w") as f:
                f.write(out)
        lines = [l for l in out.splitlines()
                 if l.startswith(scenario["prefix"])]
        fails = [l for l in lines if "  FAIL  " in l]
        verdict = [l for l in lines if "PASS" in l or "FAILED" in l]
        for line in fails:
            print("    " + line)
        oks = sum(1 for l in lines if "  ok  " in l)
        check(code == 0 and verdict and "PASS" in verdict[-1],
              "%s: the live check passes, %d checks (exit %s)"
              % (mode, oks, code))
        time.sleep(0.3)
        check(listener.count == 0, "%s, the whole live check: %d connection "
              "attempt(s)" % (mode, listener.count))
    after = snapshot(launch.folder)
    changed = sorted(k for k in before if before[k] != after.get(k))
    added = sorted(k for k in after if k not in before)
    check(not changed, "the player's files are byte-identical (%s)"
          % (", ".join(changed) if changed else ", ".join(PLAYER_FILES)))
    check(not added, "no new file in the player's folder%s (the engine's "
          "own %s aside)" % ((": " + ", ".join(added)) if added else "",
                              "/".join(ENGINE_OWN)))
    if os.path.exists(args.godot) and os.path.isdir(os.path.join(args.root,
                                                                   "godot")):
        # THE CONTROL: an ordinary launch of the source tree, against the
        # same listener, in its own scratch folder so it cannot touch the
        # comparison above. (An exported review build has no ordinary
        # launch: it is the Crossing whatever it is given.) It gets 20 s:
        # an ordinary launch's first attempt comes 7.6-10.3 s in on the
        # machine this was measured on, D's tree and the readability
        # pass's alike, so 8 s was a coin toss.
        control = dict(os.environ, XDG_DATA_HOME=os.path.join(scratch, "control"))
        try:
            subprocess.run([args.godot, "--headless", "--path",
                            os.path.join(args.root, "godot")], env=control,
                           capture_output=True, timeout=CONTROL_SECONDS)
        except subprocess.TimeoutExpired:
            pass
        time.sleep(0.3)
        check(listener.count > 0, "control: an ordinary launch does connect "
              "(%d attempt(s)), so the listener hears a client" % listener.count)
    listener.stop()
    if args.wine:
        subprocess.run(["wineserver", "-k"], env=launch.env, capture_output=True)
    shutil.rmtree(scratch, ignore_errors=True)
    print("[probe] %s -- %d failure(s)"
          % ("PASS" if not failures else "FAILED", len(failures)))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
