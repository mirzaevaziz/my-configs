fish_add_path ~/.local/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

if status is-interactive
# Commands to run in interactive sessions can go here
end

# Locale — en_US UTF-8
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx DOTNET_CLI_UI_LANGUAGE en
alias ca='claude --dangerously-skip-permissions'
alias co='copilot --no-ask-user --sync-session off --disable-builtin-mcps --yolo'

# nav tools (Lesson 03)
zoxide init fish | source
fzf --fish | source

# repo helpers (repos-info, repos-syncall) autoload from functions/

eval (/opt/homebrew/bin/brew shellenv fish)

# mise: interactive shells switch tools on cd; non-interactive (fish -c, scripts) use shims
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end


# editor
set -gx EDITOR nvim
set -gx VISUAL nvim
