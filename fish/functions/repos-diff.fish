function repos-diff --description 'review unmerged work (branch + uncommitted) across all repos under a dir' --argument-names root
    set -q root[1]; or set root $PWD
    set -l full 0
    contains -- --full $argv; and set full 1
    contains -- -f $argv; and set full 1

    for d in (find $root -type d -name .git -maxdepth 4 | sort)
        set -l repo (dirname $d)
        set -l name (basename $repo)
        string match -q _tmp $name; and test "$repo" != "$root"; and continue

        # a stale/empty .git (onboarding-candidate) would spray "fatal:" on stderr
        git -C $repo rev-parse --git-dir >/dev/null 2>&1; or continue

        set -l br (git -C $repo branch --show-current); test -n "$br"; or set br detached
        # merge-base with the default branch -> everything this branch added,
        # committed or not. Same thing a reviewer sees on the PR page.
        set -l def (git -C $repo symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
        set -l from HEAD
        if test -n "$def"
            set -l mb (git -C $repo merge-base $def HEAD 2>/dev/null)
            test -n "$mb"; and set from $mb
        end

        set -l stat (git -C $repo diff --shortstat $from 2>/dev/null)
        test -z "$stat"; and continue

        set_color --bold blue; printf "\n%s" $name; set_color normal
        printf "@"; set_color green; printf "%s\n" $br; set_color normal

        if test $full -eq 1
            git -C $repo diff $from
        else
            git -C $repo --no-pager diff --stat --color=always $from | string replace -r '^' '  '
        end
    end
end
