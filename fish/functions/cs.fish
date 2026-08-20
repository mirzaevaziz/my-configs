function cs --description 'codesearch: ensure daemon is up, then semantic search (jina-code)'
    # Guarantees the serve daemon (live file-watch across all repos) is running before searching,
    # so results are always fresh with no --sync needed. Usage: cs "your query" [extra flags]
    if not curl -s -m 2 localhost:39725/health >/dev/null 2>&1
        echo "⏳ codesearch daemon down — starting..." >&2
        codesearch serve start --model jina-code --quiet true &
        disown
        while not curl -s -m 2 localhost:39725/health >/dev/null 2>&1
            sleep 1
        end
        echo "✅ daemon up" >&2
    end
    # -q drops the startup banner; --create-index=false fails fast instead of
    # kicking off a 2-minute reindex. Both overridable by passing the flag yourself.
    codesearch search $argv --model jina-code -q --create-index=false
end
