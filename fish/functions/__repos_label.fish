function __repos_label --description 'colored padded name@branch label for repos-* functions' --argument-names repo
    set -l name (path basename (path resolve $repo))
    set -l br (git -C $repo branch --show-current); test -n "$br"; or set br detached
    set -l pad (math 52 - (string length "$name@$br")); test $pad -lt 0; and set pad 0
    printf "%s%s@%s%s%s" (set_color blue) $name (set_color green) $br (set_color normal)
    string repeat -n $pad ' '
end
