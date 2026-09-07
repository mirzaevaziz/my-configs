function repos-review --description 'Source Control panel (repo tree + side-by-side diff) for every repo under a dir' --argument-names root
    set -q root[1]; or set root $PWD
    nvim -c "RepoDiff $root"
end
