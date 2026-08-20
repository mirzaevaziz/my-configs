function lgp --description 'pick a repo under cwd with fzf (optional filter), open lazygit in it'
    set -l repos
    for d in (find $PWD -type d -name .git -maxdepth 4 | sort)
        set -l repo (dirname $d)
        # skip scratch clones, and containers like onboarding-candidate whose
        # .git is stale/empty — those are not repos
        string match -q '*/_tmp' $repo; and continue
        git -C $repo rev-parse --git-dir >/dev/null 2>&1; or continue
        set -a repos $repo
    end

    # $argv seeds the fzf query; --select-1 skips the picker on a single match,
    # --exit-0 bails when nothing matches. --with-nth trims the common prefix in
    # the DISPLAY only; fzf still prints the full path.
    set -l pick (printf '%s\n' $repos \
        | fzf --prompt 'repo> ' --delimiter / --with-nth -2.. \
              --query "$argv" --select-1 --exit-0)
    test -n "$pick"; and lazygit -p $pick
end
