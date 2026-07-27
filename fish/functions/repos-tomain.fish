function repos-tomain --description 'Checkout each child repo to its default branch (skips dirty)'
    for dir in */
        set -l repo (string trim -r -c / $dir)
        test -d $repo/.git; or continue

        set -l def (git -C $repo symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | string replace 'origin/' '')
        if test -z "$def"
            echo "⚠ $repo: no default branch (skip)"
            continue
        end

        set -l dirty (git -C $repo status --porcelain)
        set -l stashed 0
        if test -n "$dirty"
            read -l -P "⚠ $repo dirty — stash & switch? [y/N/q] " ans
            switch $ans
                case q Q
                    echo "aborted"
                    return
                case y Y
                    git -C $repo stash push -u -m repos-tomain >/dev/null 2>&1; and set stashed 1
                case '*'
                    echo "  skip $repo"
                    continue
            end
        end

        if git -C $repo checkout $def >/dev/null 2>&1
            if test $stashed -eq 1
                git -C $repo stash pop >/dev/null 2>&1
                echo "✓ $repo → $def (stash popped)"
            else
                echo "✓ $repo → $def"
            end
        else
            test $stashed -eq 1; and git -C $repo stash pop >/dev/null 2>&1
            echo "✗ $repo: checkout $def failed"
        end
    end
end
