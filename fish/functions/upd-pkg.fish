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

function upd-pkg --description 'Update brew (--greedy), mise tools, az extensions, App Store apps, macOS'
    set -e __upd_cur __upd_err __upd_failed  # clear leftovers from an interrupted run
    __upd_hdr 'brew (--greedy)'
    # 1. brew formulae + casks (also upgrades mise itself)
    brew update; or __upd_fail update
    brew upgrade --greedy; or __upd_fail upgrade

    __upd_hdr mise
    # 2. global mise tools: dotnet SDK, node, python, uv, rust, pwsh, dotnet: and npm: tools.
    #    Run from ~: dotnet tool install reads NuGet.config up the cwd tree, and the work repos'
    #    one does <clear/> + maps * to the ADNOC feed, so nuget.org tools fail from inside them.
    pushd ~
    mise upgrade; or __upd_fail 'mise upgrade'
    popd
    # A .NET SDK install rewrites the shared dotnet host in place, and macOS then kills it on launch
    # (exit 137, stale code-signature cache). Replacing it with a fresh copy fixes that.
    set -l host ~/.local/share/mise/dotnet-root/dotnet
    cp -p $host $host.new; and mv -f $host.new $host; or __upd_fail 'refresh dotnet host'

    # 3. az CLI extensions
    __upd_hdr 'az extensions'
    for e in (az extension list --query '[].name' -o tsv)
        set_color yellow; echo "→ $e"; set_color normal
        az extension update -n $e; or __upd_fail $e
    end

    # 4. App Store apps. mas 7+ needs root to update; needs the App Store app signed in.
    __upd_hdr 'App Store'
    sudo mas upgrade; or __upd_fail 'mas upgrade'

    # 5. macOS updates last: may need a restart. No -R, so it never reboots mid-run;
    #    softwareupdate prints when a restart is required. -a skips major OS upgrades.
    __upd_hdr macOS
    sudo softwareupdate -i -a; or __upd_fail 'softwareupdate'
    __upd_hdr
    echo
    if set -q __upd_failed
        set_color -o red; echo "✗ finished with failures: "(string join ', ' $__upd_failed); set_color normal
        set -e __upd_failed
        return 1
    end
    set_color -o green; echo '✓ all done'; set_color normal
end
