function repos-info --description 'VS Code-style status list for all repos under a dir (default: cwd)' --argument-names root
    set -q root[1]; or set root $PWD
    for d in (find $root -type d -name .git -maxdepth 4 | sort)
        set repo (dirname $d)
        set name (basename $repo)
        string match -q _tmp $name; and test "$repo" != "$root"; and continue
        set branch (git -C $repo branch --show-current)
        set dirty (git -C $repo status --porcelain | count)
        set ab (git -C $repo rev-list --count --left-right '@{u}...HEAD' 2>/dev/null)
        set behind (echo $ab | awk '{print $1}'); set ahead (echo $ab | awk '{print $2}')

        test "$dirty" -gt 0; and set_color yellow; or set_color normal
        printf "%-52s %-32s" $name $branch
        test "$dirty" -gt 0; and printf " ●%-3s" $dirty; or printf "  %-4s" ""
        test -n "$ahead"; and test "$ahead" -gt 0; and printf " ↑%s" $ahead
        test -n "$behind"; and test "$behind" -gt 0; and printf " ↓%s" $behind
        printf "\n"; set_color normal
    end
end
