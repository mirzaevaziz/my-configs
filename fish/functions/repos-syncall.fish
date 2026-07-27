function repos-syncall --description 'fetch + safe pull every repo under a dir (default: cwd); prompts to stash dirty ones' --argument-names root
    set -q root[1]; or set root $PWD
    set -l yesall 0
    set -l conflicts
    # prefetch all repos in parallel — network is the bottleneck, local logic below is fast.
    # BatchMode+ConnectTimeout so an unloaded SSH key or dead connection fails fast instead of
    # hanging; wait only on our own PIDs (bare `wait` blocks on unrelated bg jobs). The status
    # line matters: without it these parallel fetches produce zero output until ALL finish, so
    # syncall looks frozen for the whole fetch window and you'd Ctrl-C a working run.
    set -lx GIT_SSH_COMMAND "ssh -o BatchMode=yes -o ConnectTimeout=10"
    set -l pids
    for d in (find $root -type d -name .git -maxdepth 4)
        set -l repo (dirname $d)
        string match -q _tmp (basename $repo); and test "$repo" != "$root"; and continue
        git -C $repo fetch --quiet 2>/dev/null &
        set -a pids $last_pid
    end
    # animate a braille spinner while the background fetches run
    set -l frames ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏
    set -l n (count $pids)
    set -l i 1
    while true
        set -l alive 0
        for p in $pids
            kill -0 $p 2>/dev/null; and set alive (math $alive + 1)
        end
        test $alive -eq 0; and break
        printf "%s%s fetching %d/%d repos…%s\r" (set_color cyan) $frames[$i] (math $n - $alive) $n (set_color normal)
        set i (math "$i % 10 + 1")
        sleep 0.08
    end
    for p in $pids
        wait $p 2>/dev/null
    end
    printf "\033[2K" # clear the spinner line before per-repo results
    for d in (find $root -type d -name .git -maxdepth 4 | sort)
        set -l repo (dirname $d)
        set -l name (basename $repo)
        string match -q _tmp $name; and test "$repo" != "$root"; and continue
        set -l br (git -C $repo branch --show-current); test -n "$br"; or set br detached
        set -l label "$name@$br"
        set -l pad (math 52 - (string length "$label")); test $pad -lt 0; and set pad 0
        set -l disp (set_color blue)$name(set_color normal)@(set_color green)$br(set_color normal)(string repeat -n $pad ' ')
        set name $label

        set -l ab (git -C $repo rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)
        if test -z "$ab"
            printf "%s %s\n" $disp "SKIP (no upstream)"; continue
        end
        set -l behind (echo $ab | awk '{print $1}')
        set -l ahead (echo $ab | awk '{print $2}')
        set -l dirty (git -C $repo status --porcelain | count)

        if test "$ahead" -gt 0
            printf "%s %s\n" $disp "SKIP (diverged — $ahead ahead)"; continue
        end
        if test "$behind" -eq 0
            printf "%s %s\n" $disp "up-to-date"; continue
        end
        if test "$dirty" -eq 0
            git -C $repo merge --ff-only '@{u}' >/dev/null 2>&1
            and printf "%s %s\n" $disp "synced ↓$behind"
            or  printf "%s %s\n" $disp "SKIP (ff failed)"
            continue
        end

        # dirty + behind -> prompt unless 'all' already chosen
        if test $yesall -eq 0
            set_color yellow
            read -l -P "$name — $dirty change(s), $behind behind. stash→pull→pop? [y/N/a/q] " ans
            set_color normal
            switch $ans
                case a A; set yesall 1
                case y Y # proceed
                case q Q; printf "%s %s\n" $disp "quit"; break
                case '*'; printf "%s %s\n" $disp "SKIP (you chose no)"; continue
            end
        end

        # stash -> pull -> pop, guarding the stash the whole way
        if not git -C $repo stash -u >/dev/null 2>&1
            printf "%s %s\n" $disp "SKIP (stash failed)"; continue
        end
        if not git -C $repo merge --ff-only '@{u}' >/dev/null 2>&1
            git -C $repo stash pop >/dev/null 2>&1
            printf "%s %s\n" $disp "SKIP (pull failed — restored)"; continue
        end
        if git -C $repo stash pop >/dev/null 2>&1
            printf "%s %s\n" $disp "synced+popped ↓$behind"
        else
            set -a conflicts $name
            set_color red; printf "%s %s\n" $disp "CONFLICT (stash kept — resolve)"; set_color normal
        end
    end
    if set -q conflicts[1]
        echo; set_color red; echo "Conflicts to resolve manually:"; set_color normal
        for c in $conflicts; echo "  $c"; end
    end
end
