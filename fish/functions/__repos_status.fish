function __repos_status --description 'colorize a repos-* status word by kind: ok/warn/err/info' --argument-names kind text
    switch $kind
        case ok;   set_color green
        case warn; set_color yellow
        case err;  set_color red
        case '*';  set_color normal
    end
    printf "%s" $text
    set_color normal
end
