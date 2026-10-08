"""The launcher's window: the build library on the left, the chosen build's
details and play modes on the right."""

import os
import queue
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from . import __version__
from .library import InstallError, Library

PAD = 8


class LauncherApp:
    def __init__(self, root, library, initial_zips=()):
        self.root = root
        self.lib = library
        self.events = queue.Queue()
        self.busy = False
        self.mode_var = tk.IntVar(value=0)
        self.console_var = tk.BooleanVar(value=False)

        root.title("Archipepsi Development Launcher %s" % __version__)
        root.geometry("1040x640")
        root.minsize(760, 460)
        self._build()
        self.refresh()
        self.root.after(100, self._poll)
        self.root.after(50, self._place_divider)
        root.protocol("WM_DELETE_WINDOW", self.close)
        if initial_zips:
            self.root.after(200, lambda: self.import_zips(list(initial_zips)))

    # ------------------------------------------------------------ layout
    def _build(self):
        bar = ttk.Frame(self.root, padding=(PAD, PAD, PAD, 0))
        bar.pack(fill="x")
        self.import_btn = ttk.Button(bar, text="Install build from ZIP...",
                                     command=self.ask_import)
        self.import_btn.pack(side="left")
        ttk.Button(bar, text="Open library folder",
                   command=lambda: _open_path(self.lib.home)).pack(side="left", padx=(PAD, 0))
        self.status = ttk.Label(bar, text="", foreground="#555")
        self.status.pack(side="left", padx=PAD)

        panes = self.panes = ttk.PanedWindow(self.root, orient="horizontal")
        panes.pack(fill="both", expand=True, padx=PAD, pady=PAD)

        left = ttk.Frame(panes)
        self.tree = ttk.Treeview(left, columns=("rev", "date"), show="tree headings",
                                 selectmode="browse")
        self.tree.heading("#0", text="Build")
        self.tree.heading("rev", text="Revision")
        self.tree.heading("date", text="Installed")
        self.tree.column("#0", width=240, minwidth=120)
        self.tree.column("rev", width=80, minwidth=60, stretch=False, anchor="w")
        self.tree.column("date", width=122, minwidth=90, stretch=False, anchor="w")
        self.tree.tag_configure("old", foreground="#666")
        self.tree.tag_configure("bad", foreground="#b00")
        sb = ttk.Scrollbar(left, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=sb.set)
        self.tree.pack(side="left", fill="both", expand=True)
        sb.pack(side="left", fill="y")
        self.tree.bind("<<TreeviewSelect>>", lambda e: self.show_selected())
        self.tree.bind("<Double-1>", lambda e: self.play())
        panes.add(left, weight=2)

        right = ttk.Frame(panes, padding=(PAD, 0, 0, 0))
        self.title_lbl = ttk.Label(right, text="", font=("Segoe UI", 14, "bold"),
                                   wraplength=400)
        self.title_lbl.pack(anchor="w", fill="x")
        self.title_lbl.bind("<Configure>",
                            lambda e: self.title_lbl.config(wraplength=max(200, e.width - 4)))
        self.meta_lbl = ttk.Label(right, text="", foreground="#555", justify="left",
                                  width=40)
        self.meta_lbl.pack(anchor="w", fill="x", pady=(2, PAD))
        self.meta_lbl.bind("<Configure>",
                           lambda e: self.meta_lbl.config(wraplength=max(200, e.width - 4)))

        self.modes_box = ttk.LabelFrame(right, text="Play", padding=PAD)
        self.modes_box.pack(fill="x")
        self.modes_inner = ttk.Frame(self.modes_box)
        self.modes_inner.pack(fill="x")
        row = ttk.Frame(self.modes_box)
        row.pack(fill="x", pady=(PAD, 0))
        self.play_btn = ttk.Button(row, text="Play", command=self.play)
        self.play_btn.pack(side="left", ipadx=24, ipady=4)
        self.console_chk = ttk.Checkbutton(row, text="with a log window (console build)",
                                           variable=self.console_var)
        self.console_chk.pack(side="left", padx=PAD)

        tools = ttk.Frame(right)
        tools.pack(fill="x", pady=(PAD, 0))
        ttk.Button(tools, text="Open build folder",
                   command=self.open_build_folder).pack(side="left")
        ttk.Button(tools, text="Remove this build...",
                   command=self.remove).pack(side="left", padx=(PAD, 0))

        ttk.Label(right, text="README").pack(anchor="w", pady=(PAD, 0))
        txt_frame = ttk.Frame(right)
        txt_frame.pack(fill="both", expand=True)
        self.readme = tk.Text(txt_frame, wrap="none", height=10, font=("Consolas", 9),
                              relief="flat", background="#f6f6f6")
        rsb = ttk.Scrollbar(txt_frame, orient="vertical", command=self.readme.yview)
        self.readme.configure(yscrollcommand=rsb.set, state="disabled")
        self.readme.pack(side="left", fill="both", expand=True)
        rsb.pack(side="left", fill="y")
        panes.add(right, weight=3)

    def _place_divider(self, tries=50):
        """Once the window is laid out, give the build list its share. Set
        once only, so the divider stays where the player drags it."""
        width = self.panes.winfo_width()
        if width < 300 and tries:
            self.root.after(100, lambda: self._place_divider(tries - 1))
            return
        self.panes.sashpos(0, min(430, int(width * 0.42)))

    # ------------------------------------------------------------ library view
    def refresh(self, select=None):
        self.tree.delete(*self.tree.get_children())
        first = None
        for product, builds in self.lib.products():
            title = builds[0]["title"]
            node = self.tree.insert("", "end", iid="p:" + product, text=title, open=True)
            for i, b in enumerate(builds):
                state = self.lib.status(b)
                label = "latest" if i == 0 else "earlier"
                if state != "ok":
                    label += " (%s: reinstall)" % state
                tags = ("bad",) if state != "ok" else (() if i == 0 else ("old",))
                self.tree.insert(node, "end", iid="b:" + b["id"],
                                 text="%s - %s" % (b["title"], label) if b["title"] != title
                                 else label,
                                 values=(b["revision"], b["imported_at"].replace("T", " ")[:16]),
                                 tags=tags)
                first = first or b["id"]
        target = select or first
        if target and self.tree.exists("b:" + target):
            self.tree.selection_set("b:" + target)
            self.tree.see("b:" + target)
        self.show_selected()
        if not self.lib.builds:
            self.status.config(text="No builds yet: install one from its ZIP(s).")

    def selected(self):
        sel = self.tree.selection()
        if not sel:
            return None
        iid = sel[0]
        if iid.startswith("p:"):
            kids = self.tree.get_children(iid)
            iid = kids[0] if kids else None
        return self.lib.get(iid[2:]) if iid else None

    def show_selected(self):
        b = self.selected()
        for w in self.modes_inner.winfo_children():
            w.destroy()
        self.readme.configure(state="normal")
        self.readme.delete("1.0", "end")
        if b is None:
            self.title_lbl.config(text="No build selected")
            self.meta_lbl.config(text="")
            self.play_btn.state(["disabled"])
            self.console_chk.state(["disabled"])
            self.readme.configure(state="disabled")
            return
        state = self.lib.status(b)
        newest = self.lib.is_newest(b)
        self.title_lbl.config(text=b["title"])
        meta = "Revision %s  -  installed %s  -  %s" % (
            b["revision"] or "?", b["imported_at"].replace("T", " ")[:16],
            "the latest installed version of this build" if newest else "an earlier version, kept")
        meta += "\nFrom: " + ", ".join(b["source_zips"])
        meta += "\nChecked: " + "; ".join(b.get("verification", []))
        if b.get("verified") is False:
            meta += ("\nWARNING: this package carried nothing to check its game against, "
                     "so the launcher could not confirm it is intact.")
        if state != "ok":
            meta += ("\nPROBLEM: this build's game file is %s, so it cannot be played. "
                     "Install its ZIP(s) again to repair it." % state)
        if b.get("summary"):
            meta += "\n\n" + b["summary"]
        self.meta_lbl.config(text=meta)
        self.mode_var.set(0)
        for i, m in enumerate(b["modes"]):
            text = m["label"] + ("   (start here)" if m["recommended"] else "")
            if m["args"]:
                text += "   [%s]" % " ".join(m["args"])
            ttk.Radiobutton(self.modes_inner, text=text, value=i,
                            variable=self.mode_var).pack(anchor="w")
        self.play_btn.state(["!disabled"] if state == "ok" else ["disabled"])
        self.console_chk.state(["!disabled"] if b.get("console_exe") else ["disabled"])
        if not b.get("console_exe"):
            self.console_var.set(False)
        path = os.path.join(self.lib.folder(b), "README.txt")
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as f:
                self.readme.insert("1.0", f.read())
        self.readme.configure(state="disabled")

    # ------------------------------------------------------------ actions
    def play(self):
        b = self.selected()
        if b is None:
            return
        mode = b["modes"][self.mode_var.get()]
        try:
            self.lib.launch(b, mode, console=self.console_var.get())
        except InstallError as e:
            messagebox.showerror("Could not start the build", e.full())
            self.refresh(select=b["id"])
            return
        self.status.config(text="Started %s: %s" % (b["title"], mode["label"]))

    def ask_import(self):
        paths = filedialog.askopenfilenames(
            title="Choose a build's ZIP (for a two-part build, choose both parts)",
            filetypes=[("ZIP packages", "*.zip"), ("All files", "*.*")])
        if paths:
            self.import_zips(list(paths))

    def import_zips(self, paths):
        if self.busy:
            return
        self.busy = True
        self.import_btn.state(["disabled"])
        self.status.config(text="Installing...")

        def work():
            try:
                results = self.lib.import_zips(
                    paths, progress=lambda m: self.events.put(("progress", m)))
                self.events.put(("done", results))
            except InstallError as e:
                self.events.put(("failed", e.full()))
            except Exception as e:  # keep the window alive on anything unexpected
                self.events.put(("failed", InstallError(
                    "Something unexpected went wrong, and the install was stopped. "
                    "Builds already in your library are not affected.",
                    "%s: %s" % (type(e).__name__, e)).full()))

        threading.Thread(target=work, daemon=True).start()

    def _poll(self):
        try:
            while True:
                kind, payload = self.events.get_nowait()
                if kind == "progress":
                    self.status.config(text=payload)
                elif kind == "failed":
                    self._finish()
                    messagebox.showerror("Install failed", payload)
                elif kind == "done":
                    self._finish()
                    ok = [b for b, _ in payload if b]
                    self.refresh(select=ok[-1]["id"] if ok else None)
                    text = "\n\n----\n\n".join(msg for _, msg in payload)
                    if ok and len(ok) == len(payload):
                        messagebox.showinfo("Install", text)
                    elif ok:
                        messagebox.showwarning("Install: some builds were not installed", text)
                    else:
                        messagebox.showerror("Install failed", text)
        except queue.Empty:
            pass
        self.root.after(100, self._poll)

    def _finish(self):
        self.busy = False
        self.import_btn.state(["!disabled"])
        self.status.config(text="")

    def open_build_folder(self):
        b = self.selected()
        if b:
            _open_path(self.lib.folder(b))

    def remove(self):
        b = self.selected()
        if b is None:
            return
        if self.busy:
            messagebox.showinfo("Remove build", "Wait for the install to finish first.")
            return
        if not messagebox.askyesno(
                "Remove build",
                "Delete %s %s from the launcher's library?\n\nThis deletes its "
                "installed folder. Your original ZIPs are not touched." % (
                    b["title"], b["revision"]), icon="warning", default="no"):
            return
        try:
            self.lib.remove(b["id"])
        except InstallError as e:
            messagebox.showerror("Could not remove the build", e.full())
        self.refresh()

    def close(self):
        if self.busy and not messagebox.askyesno(
                "Install in progress",
                "A build is still being installed. Close anyway? The unfinished install "
                "is discarded the next time the launcher starts; builds already in your "
                "library are not affected.", icon="warning", default="no"):
            return
        self.lib.unlock()
        self.root.destroy()


def _open_path(path):
    if sys.platform == "win32":
        os.startfile(path)
    elif sys.platform == "darwin":
        subprocess.Popen(["open", path])
    else:
        subprocess.Popen(["xdg-open", path])


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    root = tk.Tk()
    try:
        lib = Library()
        if not lib.lock():
            root.withdraw()
            messagebox.showinfo(
                "Archipepsi Launcher",
                "The launcher is already open. Use the window that is already running "
                "(it may be behind other windows or minimised).")
            return 1
        notices = lib.startup()
    except OSError as e:
        root.withdraw()
        messagebox.showerror(
            "Archipepsi Launcher",
            "The launcher could not open its library folder, so it cannot start.\n\n"
            "Details: %s" % e)
        return 1
    zips = [a for a in argv if a.lower().endswith(".zip") and os.path.isfile(a)]
    LauncherApp(root, lib, initial_zips=zips)
    if notices:
        root.after(300, lambda: messagebox.showinfo(
            "Archipepsi Launcher", "\n\n".join(notices)))
    root.mainloop()
    return 0
