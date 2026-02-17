#!/usr/bin/env python3

import os
import subprocess
import sys
import shlex

DIRS = [
    os.path.expanduser("~/.local/share/applications"),
    "/usr/share/applications",
    "/var/lib/flatpak/exports/share/applications",
    "/var/lib/snapd/desktop/applications"
]

def get_apps():
    apps = {}
    # Определяем терминал один раз
    term_env = os.environ.get("TERMINAL", "foot")

    for d in DIRS:
        if not os.path.isdir(d): continue
        for entry in os.scandir(d):
            if entry.name.endswith(".desktop"):
                try:
                    with open(entry.path, 'r', encoding='utf-8', errors='ignore') as f:
                        name, exec_cmd, hidden, terminal = "", "", False, False
                        in_entry = False
                        for line in f:
                            line = line.strip()
                            if line == "[Desktop Entry]": in_entry = True
                            elif line.startswith("["): in_entry = False
                            if not in_entry or "=" not in line: continue

                            key, val = line.split("=", 1)
                            if key == "Name" and not name: name = val
                            elif key == "Exec" and not exec_cmd:
                                parts = shlex.split(val)
                                exec_cmd = " ".join([p for p in parts if not p.startswith('%')])
                            elif key == "Terminal" and val == "true":
                                terminal = True
                            elif key in ("NoDisplay", "Hidden") and val == "true":
                                hidden = True

                        if name and exec_cmd and not hidden:
                            if terminal and term_env not in exec_cmd:
                                exec_cmd = f"{term_env} -e {exec_cmd}"
                            apps[name] = exec_cmd
                except Exception: continue
    return apps

def main():
    apps = get_apps()
    if not apps: return

    names = "\n".join(sorted(apps.keys()))

    try:
        fzf = subprocess.Popen(['fzf', '--reverse', '--prompt= '],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        selected, _ = fzf.communicate(input=names)
        selected = selected.strip()

        if selected in apps:
            cmd = apps[selected]
            subprocess.Popen(cmd, shell=True,
                             cwd=os.path.expanduser("~"),
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL,
                             start_new_session=True)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
