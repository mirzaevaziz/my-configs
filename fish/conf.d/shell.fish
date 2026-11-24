# Fish does not set $SHELL itself; export it so tools (e.g. Raycast Shell) use fish
set -gx SHELL /opt/homebrew/bin/fish

# mise: config.fish activates it; skip Homebrew vendor auto-activate (was double)
set -gx MISE_FISH_AUTO_ACTIVATE 0
