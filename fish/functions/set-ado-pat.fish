function set-ado-pat --description "Set the Azure DevOps PAT (ADNOC_FEED_TOKEN, AZURE_DEVOPS_EXT_PAT) in global mise config"
    # Machine-local, mode 600, not mirrored to my-configs. AZURE_DEVOPS_EXT_PAT maps to it there.
    set -l file ~/.config/mise/config.local.toml
    set -l pat $argv[1]

    if test -z "$pat"
        read --silent --prompt-str="Azure DevOps PAT: " pat
        echo
    end
    # Azure DevOps PATs are alphanumeric; anything else would break the TOML line or the sed below.
    if not string match -qr '^[A-Za-z0-9]+$' -- "$pat"
        echo "set-ado-pat: no PAT given, or it has characters other than letters and digits. Nothing changed." >&2
        return 1
    end

    # Verify before persisting, so a bad paste never overwrites a working token.
    set -l code (curl -s -o /dev/null -w '%{http_code}' -u ":$pat" \
        "https://dev.azure.com/DevOpsAD/_apis/projects?api-version=7.0")
    if test "$code" != 200
        echo "set-ado-pat: PAT rejected (HTTP $code). Nothing changed." >&2
        return 1
    end

    if not test -f $file
        printf '%s\n' '[env]' 'AZURE_DEVOPS_EXT_PAT = { value = "{{ env.ADNOC_FEED_TOKEN }}", tools = true } # one PAT for both' >$file
    end
    chmod 600 $file
    if grep -q '^ADNOC_FEED_TOKEN = ' $file
        sed -i '' -E "s|^ADNOC_FEED_TOKEN = .*|ADNOC_FEED_TOKEN = \"$pat\"|" $file
    else
        # ponytail: appends to the last table; the file holds only [env]
        echo "ADNOC_FEED_TOKEN = \"$pat\"" >>$file
    end

    echo "PAT OK (HTTP 200). Written to $file; mise loads it at the next prompt (new shells and agents get it too)."
end
