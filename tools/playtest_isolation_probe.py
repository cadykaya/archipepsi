#!/usr/bin/env python3
"""The concourse-pier playtest, run the way a tester launches it, with a
stand-in bridge listening where a campaign bridge would (`make
godot-concourse-pier`).

    python3 tools/playtest_isolation_probe.py [path/to/godot] [project root]

(The project root defaults to this clone; point it at an unpacked build to
check that build.)

What it proves, through the real startup path (`--path godot -- ...`, the
same main scene and autoloads the launchers start):

1. **No connection is ever attempted.** A TCP listener sits on the bridge's
   own address (127.0.0.1:38290) for every playtest run and counts every
   connection. Both modes, plain and with the live check, must make none.
2. **The control:** an ordinary launch against the same listener DOES
   connect. So a zero above is the playtest's doing, not a deaf listener,
   and the ordinary launch is unchanged.
3. **Nothing of the player's is written.** The three files the client ever
   writes (`settings.cfg`, `loadout.cfg`, `equipment_seen.cfg`) are seeded
   in a scratch user folder and must be byte-identical afterwards, though
   the live check changes a setting and calls every save path. No other
   file may appear there except the engine's own log and caches.
4. **Both modes' live checks pass** (`godot/tests/room_playtest_check.gd`).

The engine's own log (`logs/`) and shader caches still go to Godot's user
folder; they are the engine's, not the game's, and are named in the report.
"""
import hashlib
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time

ROOT = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 \
    else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 \
    else os.path.join(ROOT, "godot-bin", "godot")
HOST, PORT = "127.0.0.1", 38290
PLAYER_FILES = ("settings.cfg", "loadout.cfg", "equipment_seen.cfg")
ENGINE_OWN = ("logs", "shader_cache", "vulkan")

failures = []


def check(ok, what):
    print(("  ok    " if ok else "  FAIL  ") + what)
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


def user_dir(xdg):
    return os.path.join(xdg, "godot", "app_userdata", "Archipepsi")


def snapshot(folder):
    out = {}
    for base, dirs, files in os.walk(folder):
        rel = os.path.relpath(base, folder)
        if rel.split(os.sep)[0] in ENGINE_OWN:
            continue
        for name in files:
            path = os.path.join(base, name)
            with open(path, "rb") as handle:
                out[os.path.relpath(path, folder)] = hashlib.sha256(
                    handle.read()).hexdigest()
    return out


def run(args, xdg, seconds=None):
    env = dict(os.environ, XDG_DATA_HOME=xdg)
    cmd = [GODOT, "--headless", "--path", os.path.join(ROOT, "godot"), "--"] + args
    try:
        done = subprocess.run(cmd, env=env, capture_output=True, text=True,
                              timeout=seconds)
        return done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired as expired:
        out = (expired.stdout or b"") + (expired.stderr or b"")
        return None, out.decode("utf-8", "replace") if isinstance(out, bytes) else out


def main():
    scratch = tempfile.mkdtemp(prefix="pier-probe-")
    xdg = os.path.join(scratch, "player")
    folder = user_dir(xdg)
    os.makedirs(folder)
    # The player's own files, as a returning player would have them.
    seeds = {
        "settings.cfg": "[settings]\nfield_of_view=97.0\nmouse_sensitivity=0.41\n",
        "loadout.cfg": "[favourites]\nsentinel=[\"do-not-touch\"]\n",
        "equipment_seen.cfg": "[seed/slot]\nseen=[\"do-not-touch\"]\n",
    }
    for name, text in seeds.items():
        with open(os.path.join(folder, name), "w") as handle:
            handle.write(text)
    before = snapshot(folder)

    listener = Listener()
    print("[probe] a stand-in bridge listens on %s:%d" % (HOST, PORT))
    for mode in ("empty", "populated"):
        extra = ["--populated"] if mode == "populated" else []
        # The launch exactly as the launcher makes it, left running a while.
        code, _ = run(["--concourse-pier"] + extra, xdg, seconds=15)
        time.sleep(0.3)
        check(listener.count == 0, "%s, as launched, 15 s: %d connection "
              "attempt(s) to the bridge's address" % (mode, listener.count))
        # And the live check, through the same startup path.
        code, out = run(["--concourse-pier"] + extra + ["--concourse-pier-check"],
                        xdg, seconds=600)
        tail = [line for line in out.splitlines() if line.startswith("[pier]")]
        for line in tail:
            print("    " + line)
        check(code == 0, "%s: the live check passes (exit %s)" % (mode, code))
        time.sleep(0.3)
        check(listener.count == 0, "%s, the whole live check: %d connection "
              "attempt(s)" % (mode, listener.count))
    after = snapshot(folder)
    changed = sorted(k for k in before if before[k] != after.get(k))
    added = sorted(k for k in after if k not in before)
    check(not changed, "the player's files are byte-identical (%s)"
          % (", ".join(changed) if changed else ", ".join(PLAYER_FILES)))
    check(not added, "no new file in the player's folder%s (the engine's "
          "own %s aside)" % ((": " + ", ".join(added)) if added else "",
                              "/".join(ENGINE_OWN)))

    # THE CONTROL: an ordinary launch, against the same listener, in its
    # own scratch folder so it cannot touch the comparison above.
    control_xdg = os.path.join(scratch, "control")
    os.makedirs(user_dir(control_xdg))
    run([], control_xdg, seconds=8)
    time.sleep(0.3)
    check(listener.count > 0, "control: an ordinary launch does connect "
          "(%d attempt(s)), so the listener hears a client" % listener.count)
    listener.stop()
    print("[probe] %s -- %d failure(s)"
          % ("PASS" if not failures else "FAILED", len(failures)))
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
