# Loads the fish completions that sit next to this file.
set -l dir (dirname (status --current-filename))
for f in $dir/fish/*.fish
    source $f
end
