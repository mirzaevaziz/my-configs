# Bare `herdr` opens (or refocuses) a workspace rooted at $PWD, then attaches.
# Needed because a cold session has no source pane for new_cwd="follow" to follow,
# so the first workspace falls back to $HOME.

function __herdr_wait_for_server
    for i in (seq 50)
        if command herdr status server 2>/dev/null | string match -q 'status: running'
            return 0
        end
        sleep 0.1
    end
    return 1
end

function __herdr_find_workspace --argument root
    set -l wsjson (command herdr workspace list 2>/dev/null | string collect)
    set -l panejson (command herdr pane list 2>/dev/null | string collect)
    test -n "$wsjson" -a -n "$panejson"; or return 1

    printf '%s\n%s\n' $wsjson $panejson | HERDR_ROOT=$root python3 -c '
import json, os, sys

root = os.path.realpath(os.environ["HERDR_ROOT"])
lines = sys.stdin.read().splitlines()
try:
    workspaces = json.loads(lines[0])["result"]["workspaces"]
    panes = json.loads(lines[1])["result"]["panes"]
except Exception:
    sys.exit(0)

# Primary key: the wsroot token we stamp at creation. Survives a pane cd-ing away.
for w in workspaces:
    token = w.get("tokens", {}).get("wsroot")
    if token and os.path.realpath(token) == root:
        print(w["workspace_id"])
        sys.exit(0)

# Fallback for workspaces made outside this wrapper, or if a server restart dropped
# the tokens. ponytail: first pane listed per workspace is treated as the root pane.
roots = {}
for p in panes:
    roots.setdefault(p["workspace_id"], p.get("cwd"))
for w in workspaces:
    cwd = roots.get(w["workspace_id"])
    if cwd and os.path.realpath(cwd) == root:
        print(w["workspace_id"])
        sys.exit(0)
'
end

function herdr --description "Attach to Herdr with a workspace rooted at \$PWD"
    # Subcommands and flags pass straight through, as do calls from inside a pane.
    if test (count $argv) -gt 0; or test "$HERDR_ENV" = 1
        command herdr $argv
        return $status
    end

    set -l root (path resolve $PWD)

    # The socket API needs a live server before any workspace can be created.
    if not command herdr status server 2>/dev/null | string match -q 'status: running'
        command herdr server >/dev/null 2>&1 &
        disown
        __herdr_wait_for_server; or begin
            echo "herdr: server did not come up; attaching without a \$PWD workspace" >&2
            command herdr
            return $status
        end
    end

    set -l ws (__herdr_find_workspace $root)
    if test -n "$ws"
        command herdr workspace focus $ws >/dev/null 2>&1
    else
        set -l created (command herdr workspace create --cwd $root --label (path basename $root) --focus 2>/dev/null | string collect)
        set -l id (printf '%s\n' $created | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["workspace"]["workspace_id"])' 2>/dev/null)
        if test -n "$id"
            command herdr workspace report-metadata $id --source herdr-fish --token "wsroot=$root" >/dev/null 2>&1
        end
    end

    command herdr
end
