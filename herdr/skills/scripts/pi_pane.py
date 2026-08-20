#!/usr/bin/env python3
"""Delegate a prompt to a fresh pi.dev pane via Herdr, one script call.

Does: pane split -> agent start --kind pi -> agent prompt [--wait]. Prints one JSON line.

Usage:
    pi_pane.py delegate --prompt "..." [--name NAME] [--direction right|down]
                         [--cwd PATH] [--wait/--no-wait] [--timeout MS]
    pi_pane.py collect --name NAME [--lines N]     # read output from a --no-wait delegate
    pi_pane.py self-check                          # offline assertions, no herdr calls
"""
import argparse
import json
import os
import random
import string
import subprocess
import sys


def herdr(*args):
    """Run herdr CLI, return parsed JSON stdout. Raises on non-zero exit."""
    p = subprocess.run(["herdr", *args], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"herdr {' '.join(args)} failed: {p.stderr.strip() or p.stdout.strip()}")
    return json.loads(p.stdout)


def gen_name():
    # [a-z][a-z0-9_-]{0,31}, unique-enough per call
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=6))
    return f"pi-{suffix}"


def require_herdr_env():
    if os.environ.get("HERDR_ENV") != "1":
        print(json.dumps({"status": "ERROR", "message": "not running inside Herdr (HERDR_ENV != 1)"}))
        sys.exit(1)


def delegate(args):
    require_herdr_env()
    name = args.name or gen_name()
    cwd = args.cwd or os.getcwd()

    split = herdr("pane", "split", "--current", "--direction", args.direction,
                   "--cwd", cwd, "--no-focus")
    pane_id = split["result"]["pane"]["pane_id"]

    herdr("agent", "start", name, "--kind", "pi", "--pane", pane_id,
          "--timeout", str(args.start_timeout))

    prompt_args = ["agent", "prompt", name, args.prompt]
    if args.wait:
        prompt_args += ["--wait", "--timeout", str(args.timeout)]
    herdr(*prompt_args)

    result = {"status": "READY", "pane_id": pane_id, "agent_name": name, "waited": args.wait}
    if args.wait:
        read = herdr("agent", "read", name, "--source", "recent-unwrapped", "--lines", str(args.lines))
        result["output"] = read.get("result", read)
    print(json.dumps(result))


def collect(args):
    require_herdr_env()
    read = herdr("agent", "read", args.name, "--source", "recent-unwrapped", "--lines", str(args.lines))
    print(json.dumps({"status": "READY", "agent_name": args.name, "output": read.get("result", read)}))


def self_check():
    import re
    name_re = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
    for _ in range(20):
        n = gen_name()
        assert name_re.match(n), f"bad generated name: {n}"
    assert gen_name() != gen_name(), "names should vary"
    print("ok")


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)

    d = sub.add_parser("delegate")
    d.add_argument("--prompt", required=True)
    d.add_argument("--name")
    d.add_argument("--direction", choices=["right", "down"], default="right")
    d.add_argument("--cwd")
    d.add_argument("--wait", dest="wait", action="store_true", default=True)
    d.add_argument("--no-wait", dest="wait", action="store_false")
    d.add_argument("--timeout", type=int, default=120000)
    d.add_argument("--start-timeout", type=int, default=30000)
    d.add_argument("--lines", type=int, default=200)

    c = sub.add_parser("collect")
    c.add_argument("--name", required=True)
    c.add_argument("--lines", type=int, default=200)

    sub.add_parser("self-check")

    args = ap.parse_args()
    if args.cmd == "delegate":
        delegate(args)
    elif args.cmd == "collect":
        collect(args)
    elif args.cmd == "self-check":
        self_check()


if __name__ == "__main__":
    main()
