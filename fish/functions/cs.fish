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
    codesearch search $argv --model jina-code
end
