function cs-update-all --description 'Incrementally reindex every registered codesearch repo (jina-code)'
    # Reads repo paths from ~/.codesearch/repos.json so newly-added repos are covered automatically.
    # Pass --force for a full rebuild of every repo.
    set -l extra $argv
    for path in (python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.codesearch/repos.json'))); print('\n'.join(d['repos'].values()))")
        set -l name (basename $path)
        set -l t (date +%s)
        set -l n (codesearch index $path --model jina-code $extra 2>&1 | grep -cE '📝|indexed|Indexing')
        echo "$name: updated in "(math (date +%s) - $t)"s"
    end
    echo "✅ all repos updated"
end
