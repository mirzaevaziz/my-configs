fish_add_path ~/.local/bin
fish_add_path "/Applications/Visual Studio Code.app/Contents/Resources/app/bin"

if status is-interactive
# Commands to run in interactive sessions can go here
end

# Locale — en_US UTF-8
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx DOTNET_CLI_UI_LANGUAGE en
alias claude='claude --dangerously-skip-permissions'
alias copilot='copilot --no-ask-user --no-remote --no-remote-export --disable-builtin-mcps --yolo'

# nav tools (Lesson 03)
zoxide init fish | source
fzf --fish | source

# repo helpers (repos-info, repos-syncall) autoload from functions/
