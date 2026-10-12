function set-ado-pat --description "Set one Azure DevOps PAT for both ADNOC_FEED_TOKEN and AZURE_DEVOPS_EXT_PAT"
    set -l secrets ~/.config/fish/conf.d/secrets.fish
    set -l pat $argv[1]

    if test -z "$pat"
        read --silent --prompt-str="Azure DevOps PAT: " pat
        echo
    end
    if test -z "$pat"
        echo "set-ado-pat: no PAT given." >&2
        return 1
    end

    # Verify before persisting, so a bad paste never overwrites a working token.
    set -l code (curl -s -o /dev/null -w '%{http_code}' -u ":$pat" \
        "https://dev.azure.com/DevOpsAD/_apis/projects?api-version=7.0")
    if test "$code" != 200
        echo "set-ado-pat: PAT rejected (HTTP $code). Nothing changed." >&2
        return 1
    end

    # Universal vars are the single fish source of truth. A global of the same
    # name (e.g. from secrets.fish) would shadow them, so strip and erase those.
    if test -f $secrets
        sed -i '' -E '/^set -gx (ADNOC_FEED_TOKEN|AZURE_DEVOPS_EXT_PAT) /d' $secrets
    end
    set -eg ADNOC_FEED_TOKEN 2>/dev/null
    set -eg AZURE_DEVOPS_EXT_PAT 2>/dev/null
    set -Ux ADNOC_FEED_TOKEN $pat
    set -Ux AZURE_DEVOPS_EXT_PAT $pat

    # Keep bash and zsh in step, so tools launched from those shells see the same PAT.
    for rc in ~/.bashrc ~/.zshenv
        test -f $rc; or touch $rc
        if grep -q '^export ADNOC_FEED_TOKEN=' $rc
            sed -i '' -E "s|^export ADNOC_FEED_TOKEN=.*|export ADNOC_FEED_TOKEN=\"$pat\"|" $rc
        else
            echo "export ADNOC_FEED_TOKEN=\"$pat\"" >> $rc
        end
        grep -q '^export AZURE_DEVOPS_EXT_PAT=' $rc
        or echo 'export AZURE_DEVOPS_EXT_PAT="$ADNOC_FEED_TOKEN"' >> $rc
    end

    echo "PAT OK (HTTP 200). Set as fish universal vars (-Ux) and written to ~/.bashrc, ~/.zshenv."
end
