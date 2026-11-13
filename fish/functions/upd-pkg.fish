# section banners: close the previous section with "done" or "failed", open the next one.
# No args = close the last section only.
function __upd_hdr
    if set -q __upd_cur
        if set -q __upd_err
            set_color -o red; echo "✗ $__upd_cur failed: "(string join ', ' $__upd_err); set_color normal
            set -ga __upd_failed $__upd_cur
        else
            set_color -o green; echo "✓ $__upd_cur done"; set_color normal
        end
        set -e __upd_cur __upd_err
    end
    test (count $argv) -eq 0; and return
    set -g __upd_cur "$argv"
    echo
    set_color -o cyan; echo "━━━ $argv ━━━"; set_color normal
end

# mark the current section failed; argv = what failed
function __upd_fail
    set -ga __upd_err $argv
end

function upd-pkg --description 'Update dotnet-sdk@10, pwsh, brew (--greedy), dotnet tools, npm globals, rustup, az extensions'
    set -e __upd_cur __upd_err __upd_failed  # clear leftovers from an interrupted run
    __upd_hdr 'dotnet-sdk@10'
    # 1. dotnet-sdk@10 lives in local tap local/dotnet (Homebrew moved dotnet-sdk to 11).
    #    Bump the cask to the latest 10.0 SDK; brew upgrade below installs it.
    set -l cask (brew --repository)/Library/Taps/local/homebrew-dotnet/Casks/dotnet-sdk@10.rb
    if test -f $cask
        set -l cur (string match -rg 'version "([^"]+)"' < $cask)
        # prints: version, pkg url, sha512
        set -l rel (curl -fsSL https://builds.dotnet.microsoft.com/dotnet/release-metadata/10.0/releases.json | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
v = d["latest-sdk"]
r = next(r for r in d["releases"] if r["sdk"]["version"] == v)
f = next(f for f in r["sdk"]["files"] if f["rid"] == "osx-arm64" and f["url"].endswith(".pkg"))
print(v); print(f["url"]); print(f["hash"])')
        if test (count $rel) -ne 3
            __upd_fail 'read release metadata'
        else if test "$rel[1]" != "$cur"
            echo "dotnet-sdk@10: $cur -> $rel[1]"
            sed -i '' "s/version \"$cur\"/version \"$rel[1]\"/" $cask
            # download straight into brew's cache so brew upgrade reuses it
            set -l dl (brew --cache --cask local/dotnet/dotnet-sdk@10)
            curl -fL -o $dl $rel[2]; or __upd_fail download
            if test (shasum -a 512 $dl | string split -f1 ' ') != "$rel[3]"
                __upd_fail 'sha512 mismatch, cask reverted'
                rm -f $dl
                sed -i '' "s/version \"$rel[1]\"/version \"$cur\"/" $cask
            else
                # ponytail: only the arm sha is refreshed; intel sha goes stale (arm-only machine)
                set -l sha (shasum -a 256 $dl | string split -f1 ' ')
                sed -i '' -E "s/(sha256 arm: +\")[0-9a-f]+/\1$sha/" $cask
            end
        else
            echo "dotnet-sdk@10: $cur up to date"
        end
    end

    __upd_hdr pwsh
    # 2. pwsh from Microsoft's self-contained pkg (brew's formula needs the brew dotnet formula)
    set -l url (curl -fsSL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | string match -rg '"(https://[^"]*osx-arm64\.pkg)"')
    set -l latest (string match -rg 'powershell-([0-9.]+)-osx' $url)
    set -l have (command -q pwsh; and pwsh --version | string split -f2 ' ')
    if test -z "$latest"
        __upd_fail 'read latest release'
    else if test "$latest" != "$have"
        echo "pwsh: $have -> $latest"
        curl -fL -o /tmp/pwsh.pkg $url; and sudo installer -pkg /tmp/pwsh.pkg -target /; and rm /tmp/pwsh.pkg
        or __upd_fail install
    else
        echo "pwsh: $have up to date"
    end

    __upd_hdr 'brew (--greedy)'
    # 3. brew formulae + casks (also installs the bumped dotnet-sdk@10)
    brew update; or __upd_fail update
    brew upgrade --greedy; or __upd_fail upgrade

    __upd_hdr 'dotnet global tools'
    # 4. dotnet global tools (after the SDK upgrade). dotnet-ef pinned to the SDK major,
    #    roslyn-language-server only ships prereleases. Corporate NuGet feed may be unreachable off VPN.
    for id in (dotnet tool list -g | tail -n +3 | string split -f1 ' ')
        set_color yellow; echo "→ $id"; set_color normal
        switch $id
            case dotnet-ef
                dotnet tool update -g $id --ignore-failed-sources --version '10.*'
            case roslyn-language-server
                dotnet tool update -g $id --ignore-failed-sources --prerelease
            case '*'
                dotnet tool update -g $id --ignore-failed-sources
        end
        or __upd_fail $id
    end

    # 5. npm globals, rust toolchain, az CLI extensions
    __upd_hdr 'npm globals'
    npm update -g; or __upd_fail 'npm update'
    __upd_hdr rustup
    rustup update; or __upd_fail 'rustup update'
    __upd_hdr 'az extensions'
    for e in (az extension list --query '[].name' -o tsv)
        set_color yellow; echo "→ $e"; set_color normal
        az extension update -n $e; or __upd_fail $e
    end
    __upd_hdr
    echo
    if set -q __upd_failed
        set_color -o red; echo "✗ finished with failures: "(string join ', ' $__upd_failed); set_color normal
        set -e __upd_failed
        return 1
    end
    set_color -o green; echo '✓ all done'; set_color normal
end
