function repos-info --description 'VS Code-style status list for all repos under a dir (default: cwd)' --argument-names root
    set -q root[1]; or set root $PWD
    for d in (find $root -type d -name .git -maxdepth 4 | sort)
        set -l repo (dirname $d)
        set -l name (basename $repo)
        string match -q _tmp $name; and test "$repo" != "$root"; and continue
        set -l dirty (git -C $repo status --porcelain | count)
        set -l ab (git -C $repo rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)
        set -l behind (echo $ab | awk '{print $1}'); set -l ahead (echo $ab | awk '{print $2}')

        printf "%s" (__repos_label $repo)
        test "$dirty" -gt 0; and printf " %s" (__repos_status warn "●$dirty")
        test -n "$ahead"; and test "$ahead" -gt 0; and printf " %s" (__repos_status ok "↑$ahead")
        test -n "$behind"; and test "$behind" -gt 0; and printf " %s" (__repos_status warn "↓$behind")
        printf "\n"
    end
end
