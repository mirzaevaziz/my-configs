# Red dot while remote. Pairs with fish_title.
function ssh --wraps ssh
    printf '\e]0;🔴 %s\a' "$argv[-1]"
    command ssh $argv
end
