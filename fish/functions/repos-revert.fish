function repos-revert --description 'VS Code-style discard-all across repos: staged / working tree / stashes'
    set -l dry 0
    set -l root

    for a in $argv
        switch $a
            case --dry-run -n
                set dry 1
            case '*'
                set root $a
        end
    end
    set -q root[1]; or set root $PWD

    # ignored paths worth keeping through a -fdx. Override: set -g repos_revert_keep a b c
    set -q repos_revert_keep; or set -l repos_revert_keep .codesearch.db
    set -l keep
    for k in $repos_revert_keep
        set -a keep -e $k
    end

    set -l n_reverted 0
    set -l n_skipped 0
    set -l n_stashes 0
    set -l quit 0

    for d in (find $root -type d -name .git -maxdepth 4 | sort)
        set -l repo (dirname $d)
        set -l name (basename $repo)
        string match -q _tmp $name; and test "$repo" != "$root"; and continue
        git -C $repo rev-parse --git-dir >/dev/null 2>&1; or continue

        set -l staged (git -C $repo diff --cached --name-only | count)
        set -l changed (git -C $repo diff --name-only | count)
        # -x so the count matches what clean -fdx actually removes (untracked + ignored)
        set -l todel (git -C $repo clean -ndx $keep | count)
        set -l stashes (git -C $repo stash list | count)

        test $staged -eq 0; and test $changed -eq 0; and test $todel -eq 0; and continue

        set -l br (git -C $repo branch --show-current); test -n "$br"; or set br detached
        set_color --bold blue; printf "\n%s" $name; set_color normal
        printf "@"; set_color green; printf "%s" $br; set_color normal
        printf "  staged %s  changed %s  to-delete %s  stashes %s\n" (__repos_status warn $staged) (__repos_status warn $changed) (__repos_status err $todel) $stashes

        if test $dry -eq 1
            git -C $repo status --short | string replace -r '^' '  '
            git -C $repo clean -ndx $keep | string replace -r '^' '  '
            git -C $repo stash list | string replace -r '^' '  '
            continue
        end

        set -l all 0
        set -l did 0
        set -l ans

        # --- staged ---
        if test $staged -gt 0
            while true
                set ans y
                if test $all -eq 0
                    read -l -P "  discard $staged staged? [y/N/a/i/q] " reply
                    set ans $reply
                end
                switch $ans
                    case q Q
                        set quit 1
                    case i I
                        git -C $repo diff --cached --name-only | string replace -r '^' '    '
                        continue
                    case a A
                        set all 1
                        set ans y
                    case y Y
                        set ans y
                    case '*'
                        set ans n
                end
                break
            end
            test $quit -eq 1; and break
            if test "$ans" = y
                git -C $repo restore --staged --worktree :/
                set did 1
            end
        end

        # --- working tree: tracked mods + untracked + ignored ---
        if test $changed -gt 0; or test $todel -gt 0
            while true
                set ans y
                if test $all -eq 0
                    read -l -P "  discard working tree ($changed changed, $todel to delete)? [y/N/a/i/q] " reply
                    set ans $reply
                end
                switch $ans
                    case q Q
                        set quit 1
                    case i I
                        git -C $repo status --short | string replace -r '^' '    '
                        git -C $repo clean -ndx $keep | string replace -r '^' '    '
                        continue
                    case a A
                        set all 1
                        set ans y
                    case y Y
                        set ans y
                    case '*'
                        set ans n
                end
                break
            end
            test $quit -eq 1; and break
            if test "$ans" = y
                git -C $repo restore --worktree :/
                git -C $repo clean -fdx $keep >/dev/null
                set did 1
            end
        end

        # --- stashes: only offered once something was actually reverted here ---
        if test $did -eq 1; and test $stashes -gt 0
            while true
                set ans y
                if test $all -eq 0
                    read -l -P "  drop $stashes stashes? [y/N/i/q] " reply
                    set ans $reply
                end
                switch $ans
                    case q Q
                        set quit 1
                    case i I
                        git -C $repo stash list | string replace -r '^' '    '
                        continue
                    case y Y a A
                        set ans y
                    case '*'
                        set ans n
                end
                break
            end
            test $quit -eq 1; and break
            if test "$ans" = y
                git -C $repo stash clear
                set n_stashes (math $n_stashes + $stashes)
            end
        end

        if test $did -eq 1
            set n_reverted (math $n_reverted + 1)
        else
            set n_skipped (math $n_skipped + 1)
        end
    end

    test $quit -eq 1; and echo "aborted"
    test $dry -eq 1; and return 0
    printf "\n%s reverted, %s skipped, %s stashes dropped\n" (__repos_status ok $n_reverted) (__repos_status warn $n_skipped) (__repos_status err $n_stashes)
end
