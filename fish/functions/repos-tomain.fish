function repos-tomain --description 'Checkout each child repo to its default branch (skips dirty)'
    for dir in */
        set -l repo (string trim -r -c / $dir)
        test -d $repo/.git; or continue

        set -l def (git -C $repo symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | string replace 'origin/' '')
        if test -z "$def"
            printf "%s %s\n" (__repos_label $repo) (__repos_status warn "SKIP (no default branch)")
            continue
        end

        set -l disp (__repos_label $repo)

        if test (git -C $repo symbolic-ref --short HEAD 2>/dev/null) = "$def"
            printf "%s %s\n" $disp (__repos_status ok "already on $def")
            continue
        end

        set -l dirty (git -C $repo status --porcelain)
        set -l stashed 0
        if test -n "$dirty"
            set_color yellow
            read -l -P "⚠ $repo dirty — stash & switch? [y/N/q] " ans
            set_color normal
            switch $ans
                case q Q
                    printf "%s %s\n" $disp (__repos_status warn "aborted")
                    return
                case y Y
                    git -C $repo stash push -u -m repos-tomain >/dev/null 2>&1; and set stashed 1
                case '*'
                    printf "%s %s\n" $disp (__repos_status warn "SKIP (you chose no)")
                    continue
            end
        end

        if git -C $repo checkout $def >/dev/null 2>&1
            if test $stashed -eq 1
                git -C $repo stash pop >/dev/null 2>&1
                printf "%s %s\n" $disp (__repos_status ok "→ $def (stash popped)")
            else
                printf "%s %s\n" $disp (__repos_status ok "→ $def")
            end
        else
            test $stashed -eq 1; and git -C $repo stash pop >/dev/null 2>&1
            printf "%s %s\n" $disp (__repos_status err "checkout $def failed")
        end
    end
end
