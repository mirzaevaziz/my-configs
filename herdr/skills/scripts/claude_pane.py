#!/usr/bin/env python3
"""Delegate a subagent task to a fresh Claude Code tab via Herdr, one script call.

Does: tab create --label -> agent start --kind claude -> agent prompt -> wait for
idle/done + output file -> harvest file -> tab close. Prints one JSON line.

Grill-settled design (2026-08-20): every Claude Code subagent runs as an interactive
claude session in its own labeled Herdr tab; persona comes from the agent-type .md
body via --append-system-prompt; result handoff is file-based (alt-screen output is
not scrapeable); harvest is automatic (no user gate); successful harvest auto-closes
the tab, error/blocked leaves it open for inspection.

Usage:
    claude_pane.py delegate --prompt "..." [--agent-type TYPE] [--name NAME]
                            [--cwd PATH] [--model M] [--wait/--no-wait] [--timeout MS]
    claude_pane.py collect --name NAME [--cwd PATH]   # harvest a --no-wait delegate
    claude_pane.py self-check                   # offline assertions, no herdr calls
"""
import argparse
import json
import os
import random
import re
import string
import subprocess
import sys
import time

MAX_NUDGES = 3


def runs_dir(cwd):
    return os.path.join(cwd, "_tmp", "herdr-subagents")


def herdr(*args):
    """Run herdr CLI, return parsed JSON stdout. Raises on non-zero exit."""
    p = subprocess.run(["herdr", *args], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"herdr {' '.join(args[:3])} failed: {p.stderr.strip() or p.stdout.strip()}")
    return json.loads(p.stdout) if p.stdout.strip() else {}


def gen_name(base=None):
    # Always unique: caller-provided --name is a base, suffix guarantees a fresh
    # run dir / output file even when the same base is reused across runs.
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    base = re.sub(r"[^a-z0-9_-]", "-", (base or "cc").lower()).strip("-") or "cc"
    if not base[0].isalpha():
        base = "cc-" + base
    return f"{base[:25]}-{suffix}"


def require_herdr_env():
    if os.environ.get("HERDR_ENV") != "1":
        print(json.dumps({"status": "ERROR", "message": "not running inside Herdr (HERDR_ENV != 1)"}))
        sys.exit(1)


def find_key(obj, key):
    """Depth-first search for the first occurrence of key in nested dicts/lists."""
    if isinstance(obj, dict):
        if key in obj:
            return obj[key]
        for v in obj.values():
            found = find_key(v, key)
            if found is not None:
                return found
    elif isinstance(obj, list):
        for v in obj:
            found = find_key(v, key)
            if found is not None:
                return found
    return None


def strip_frontmatter(text):
    if text.startswith("---"):
        end = text.find("\n---", 3)
        if end != -1:
            return text[end + 4:].lstrip("\n")
    return text


def agent_type_prompt(agent_type, cwd):
    for base in (os.path.join(cwd, ".claude", "agents"),
                 os.path.expanduser("~/.claude/agents")):
        path = os.path.join(base, f"{agent_type}.md")
        if os.path.isfile(path):
            with open(path) as f:
                return strip_frontmatter(f.read())
    return None  # built-in types (Explore, general-purpose, ...) have no .md file


def agent_state(name):
    listing = herdr("agent", "list")
    agents = listing.get("result", listing)
    if isinstance(agents, dict):
        agents = agents.get("agents", [])
    for a in agents:
        if a.get("name") == name:
            return a.get("state") or a.get("status") or "unknown"
    return None  # gone


KNOWN_RUN_FILES = {"output.md", "error.txt", "meta.json"}


def artifacts(run_dir):
    """Extra files the subagent dropped in its run dir besides the known control files."""
    try:
        return sorted(
            os.path.join(run_dir, f) for f in os.listdir(run_dir) if f not in KNOWN_RUN_FILES
        )
    except FileNotFoundError:
        return []


def harvest(name, meta):
    with open(meta["output"]) as f:
        output = f.read()
    try:
        herdr("tab", "close", meta["tab_id"])
    except RuntimeError:
        pass  # user may have closed it already; output is what matters
    result = {"status": "READY", "agent_name": name, "output": output}
    files = artifacts(os.path.dirname(meta["output"]))
    if files:
        result["artifacts"] = files
    return result


def wait_and_harvest(name, meta, timeout_ms):
    deadline = time.monotonic() + timeout_ms / 1000
    nudges = 0
    while True:
        remaining = int((deadline - time.monotonic()) * 1000)
        if remaining <= 0:
            return {"status": "ERROR", "agent_name": name, "tab_id": meta["tab_id"],
                    "message": "timeout waiting for delegate; tab left open"}
        try:
            herdr("agent", "wait", name, "--timeout", str(remaining))
        except RuntimeError as e:
            if agent_state(name) is None and os.path.isfile(meta["output"]):
                return harvest(name, meta)  # agent exited after writing = done
            return {"status": "ERROR", "agent_name": name, "tab_id": meta["tab_id"], "message": str(e)}
        state = agent_state(name)
        if state == "blocked":
            return {"status": "BLOCKED", "agent_name": name, "tab_id": meta["tab_id"],
                    "message": "delegate waiting on approval/question; inspect the tab"}
        if os.path.isfile(meta["output"]):
            return harvest(name, meta)
        if nudges >= MAX_NUDGES:
            return {"status": "ERROR", "agent_name": name, "tab_id": meta["tab_id"],
                    "message": f"idle without output file after {MAX_NUDGES} nudges; tab left open"}
        nudges += 1
        herdr("agent", "prompt", name,
              f"Write your complete final report as Markdown to {meta['output']} now, then stop.")
        time.sleep(2)


def delegate(args):
    require_herdr_env()
    name = gen_name(args.name)
    run_dir = os.path.join(runs_dir(args.cwd or os.getcwd()), name)
    os.makedirs(run_dir, exist_ok=True)
    for stale in ("output.md", "error.txt"):
        try:
            os.remove(os.path.join(run_dir, stale))
        except FileNotFoundError:
            pass
    try:
        _delegate(args, name, run_dir)
    except Exception as e:
        import traceback
        with open(os.path.join(run_dir, "error.txt"), "w") as f:
            f.write(traceback.format_exc())
        print(json.dumps({"status": "ERROR", "agent_name": name, "message": str(e),
                          "detail": os.path.join(run_dir, "error.txt")}))
        sys.exit(1)


def _delegate(args, name, run_dir):
    cwd = args.cwd or os.getcwd()
    output = os.path.join(run_dir, "output.md")

    claude_args = []
    role_prefix = ""
    if args.agent_type:
        persona = agent_type_prompt(args.agent_type, cwd)
        if persona:
            claude_args += ["--append-system-prompt", persona]
        else:
            role_prefix = f"You are acting as the '{args.agent_type}' subagent.\n\n"
    if args.model:
        claude_args += ["--model", args.model]

    create = ["tab", "create", "--cwd", cwd, "--label", name, "--no-focus"]
    ws = os.environ.get("HERDR_WORKSPACE_ID")
    if ws:
        create[2:2] = ["--workspace", ws]
    tab = herdr(*create)
    tab_id = find_key(tab, "tab_id")
    pane_id = find_key(tab, "pane_id")
    if not tab_id or not pane_id:
        raise RuntimeError(f"could not find tab_id/pane_id in tab create response: {json.dumps(tab)}")

    meta = {"tab_id": tab_id, "pane_id": pane_id, "output": output}
    with open(os.path.join(run_dir, "meta.json"), "w") as f:
        json.dump(meta, f)

    start = ["agent", "start", name, "--kind", "claude", "--pane", pane_id,
             "--timeout", str(args.start_timeout)]
    if claude_args:
        start += ["--", *claude_args]
    herdr(*start)

    task = (f"{role_prefix}{args.prompt}\n\nWhen finished: 1) write your complete final report "
            f"as Markdown to {output} (overwrite it); if your task produced actual result files "
            f"(not just a text report), save them into {run_dir} too so the parent can pick them up; "
            f"2) then run this exact Bash command to hand off and close your tab: "
            f"herdr tab close \"$HERDR_TAB_ID\"")
    herdr("agent", "prompt", name, task)

    if args.wait:
        print(json.dumps(wait_and_harvest(name, meta, args.timeout)))
    else:
        print(json.dumps({"status": "RUNNING", "agent_name": name, "tab_id": tab_id,
                          "pane_id": pane_id, "output": output,
                          "collect": f"claude_pane.py collect --name {name}"}))


def collect(args):
    require_herdr_env()
    meta_path = os.path.join(runs_dir(args.cwd or os.getcwd()), args.name, "meta.json")
    if not os.path.isfile(meta_path):
        print(json.dumps({"status": "ERROR", "message": f"no run named {args.name}"}))
        sys.exit(1)
    with open(meta_path) as f:
        meta = json.load(f)
    print(json.dumps(wait_and_harvest(args.name, meta, args.timeout)))


def self_check():
    name_re = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
    for _ in range(20):
        n = gen_name()
        assert name_re.match(n), f"bad generated name: {n}"
    assert gen_name() != gen_name(), "names should vary"
    for base in ("arch-migration", "Arch Review!", "9lives", "x" * 40):
        for _ in range(5):
            n = gen_name(base)
            assert name_re.match(n), f"bad name from base {base!r}: {n}"
    assert gen_name("same-base") != gen_name("same-base"), "same base must still be unique"
    assert strip_frontmatter("---\nname: x\n---\n\nBody here") == "Body here"
    assert strip_frontmatter("No frontmatter") == "No frontmatter"
    print("ok")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("delegate")
    d.add_argument("--prompt", required=True)
    d.add_argument("--agent-type")
    d.add_argument("--name")
    d.add_argument("--cwd")
    d.add_argument("--model")
    d.add_argument("--wait", dest="wait", action="store_true", default=True)
    d.add_argument("--no-wait", dest="wait", action="store_false")
    d.add_argument("--timeout", type=int, default=600000)
    d.add_argument("--start-timeout", type=int, default=30000)

    c = sub.add_parser("collect")
    c.add_argument("--name", required=True)
    c.add_argument("--cwd")
    c.add_argument("--timeout", type=int, default=600000)

    sub.add_parser("self-check")

    args = ap.parse_args()
    if args.cmd == "delegate":
        delegate(args)
    elif args.cmd == "collect":
        collect(args)
    else:
        self_check()


if __name__ == "__main__":
    main()
