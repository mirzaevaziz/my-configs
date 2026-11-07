#!/usr/bin/env bash
# macOS settings changed from stock on this Mac. Re-applies them with `defaults write`.
# Safe to re-run. Log out and back in afterwards; some keys only load at login.
set -euo pipefail

# --- Appearance -------------------------------------------------------------
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
defaults write NSGlobalDomain AppleShowScrollBars -string Always
defaults -currentHost write NSGlobalDomain AppleFontSmoothing -int 0
# tighter menu bar icons, so more fit beside the notch
defaults -currentHost write NSGlobalDomain NSStatusItemSpacing -int 6
defaults -currentHost write NSGlobalDomain NSStatusItemSelectionPadding -int 6

# --- Keyboard ---------------------------------------------------------------
# F1-F12 act as standard function keys; hold fn for brightness/volume
defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
# no input-source popup when switching layouts
defaults write NSGlobalDomain TSMLanguageIndicatorEnabled -int 0

# --- Trackpad and scrolling -------------------------------------------------
# tap to click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
# natural scrolling off
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false
# no two-finger swipe back/forward in browsers
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool false

# --- Windows and Desktop ----------------------------------------------------
defaults write NSGlobalDomain AppleMiniaturizeOnDoubleClick -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write com.apple.WindowManager HideDesktop -bool true # no icons on the desktop
defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1

# --- Dock -------------------------------------------------------------------
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock orientation -string left
defaults write com.apple.dock tilesize -float 47

# --- Finder -----------------------------------------------------------------
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv  # list view

# --- App Shortcuts (System Settings > Keyboard > Keyboard Shortcuts > App Shortcuts)
# frees cmd+h for the editors' own bindings; titles must match the menu item exactly
defaults write com.microsoft.VSCode NSUserKeyEquivalents -dict-add "Hide Visual Studio Code" '@~^$h'
defaults write com.mitchellh.ghostty NSUserKeyEquivalents -dict-add "Hide Ghostty" '@~^$h'
defaults write com.mitchellh.ghostty NSUserKeyEquivalents -dict-add "Move Tab to New Window" '@$w'

# --- System keyboard shortcuts ----------------------------------------------
# Raw AppleSymbolicHotKeys entries. Known ids: 28-31 and 184 screenshots (Vorssaint owns them),
# 36 Show Desktop (F11), 60/61 previous/next input source (60 moved to shift+ctrl+opt+p),
# 64 Spotlight cmd+space (Raycast owns it), 65 Finder search, 79-82 move between Spaces,
# 190 Quick Note (fn+q).
hk() { defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$1" "$2"; }
hk 15 '<dict><key>enabled</key><false/></dict>'
hk 16 '<dict><key>enabled</key><false/></dict>'
hk 17 '<dict><key>enabled</key><false/></dict>'
hk 18 '<dict><key>enabled</key><false/></dict>'
hk 19 '<dict><key>enabled</key><false/></dict>'
hk 20 '<dict><key>enabled</key><false/></dict>'
hk 21 '<dict><key>enabled</key><false/></dict>'
hk 22 '<dict><key>enabled</key><false/></dict>'
hk 23 '<dict><key>enabled</key><false/></dict>'
hk 24 '<dict><key>enabled</key><false/></dict>'
hk 25 '<dict><key>enabled</key><false/></dict>'
hk 26 '<dict><key>enabled</key><false/></dict>'
hk 28 '<dict><key>enabled</key><false/></dict>'
hk 29 '<dict><key>enabled</key><false/></dict>'
hk 30 '<dict><key>enabled</key><false/></dict>'
hk 31 '<dict><key>enabled</key><false/></dict>'
hk 36 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>103</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 60 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>112</integer><integer>35</integer><integer>917504</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 61 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>786432</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 64 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 65 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>32</integer><integer>49</integer><integer>1572864</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 79 '<dict><key>enabled</key><true/></dict>'
hk 80 '<dict><key>enabled</key><true/></dict>'
hk 81 '<dict><key>enabled</key><true/></dict>'
hk 82 '<dict><key>enabled</key><true/></dict>'
hk 164 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>65535</integer><integer>0</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 184 '<dict><key>enabled</key><false/></dict>'
hk 190 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>113</integer><integer>12</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>'
hk 260 '<dict><key>enabled</key><false/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>53</integer><integer>1048576</integer></array><key>type</key><string>standard</string></dict></dict>'

killall Dock Finder SystemUIServer 2>/dev/null || true
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
echo "Done. Log out and back in for trackpad, keyboard and font smoothing changes."
