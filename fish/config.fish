fish_add_path ~/.local/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

if status is-interactive
# Commands to run in interactive sessions can go here
end

# Locale — en_US UTF-8
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx DOTNET_CLI_UI_LANGUAGE en
alias ca='claude --permission-mode auto'
alias co='copilot --no-ask-user --sync-session off --disable-builtin-mcps --assisted-approval'
alias mr='mise run'

# nav tools (Lesson 03)
zoxide init fish | source
fzf --fish | source

# repo helpers (repos-info, repos-syncall) autoload from functions/

# static copy of `brew shellenv fish` (saves a process per shell); re-check after brew changes
set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
set -gx HOMEBREW_REPOSITORY /opt/homebrew
fish_add_path --global --move --path /opt/homebrew/bin /opt/homebrew/sbin
if test -n "$MANPATH"; set -gx MANPATH (string replace --regex '^:*(.*?):*$' ':$1' -- "$MANPATH"); end
if not set -q INFOPATH; set INFOPATH ''; end; set -gx INFOPATH /opt/homebrew/share/info $INFOPATH

# mise: interactive shells switch tools on cd; non-interactive (fish -c, scripts) use shims
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end


# editor
set -gx EDITOR nvim
set -gx VISUAL nvim
