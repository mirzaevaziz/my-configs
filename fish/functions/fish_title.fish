# Ghostty tab label. No per-tab color exists in Ghostty 1.3.1 (tab bar inherits
# the background), so a colored dot carries the signal instead.
# ponytail: switch on PWD, no config file — add one when the list stops fitting.
function fish_title --argument last_command
    set -l dot
    if set -q SSH_TTY
        set dot 🔴
    else
        switch $PWD
            case ~/Projects/adnoc'*'; set dot 🔵
            case ~/Projects/epam'*'; set dot 🟢
            case ~/Projects/self'*'; set dot 🟣
            case ~/Projects/skills'*'; set dot 🟡
            case ~/learn-terminal'*'; set dot 🟠
            case '*'; set dot ⚪
        end
    end
    echo $dot' '(prompt_pwd)
end
