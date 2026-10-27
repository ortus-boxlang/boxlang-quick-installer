# Loads the bash/zsh completions that sit next to this file.
# Safe to source more than once.
[ -n "${BX_COMPLETIONS_LOADED:-}" ] && return 0 2>/dev/null
if [ -n "${ZSH_VERSION:-}" ]; then
    _bx_completions_dir="${${(%):-%x}:A:h}"
    _bx_completions_ext="zsh"
elif [ -n "${BASH_VERSION:-}" ]; then
    _bx_completions_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    _bx_completions_ext="bash"
else
    return 0 2>/dev/null
fi

if [ "$_bx_completions_ext" = "zsh" ]; then
    # compdef is only available once the completion system is initialised
    if ! command -v compdef >/dev/null 2>&1; then
        autoload -U +X compinit && compinit -u
    fi
fi

for _bx_completion_file in "$_bx_completions_dir/$_bx_completions_ext"/*."$_bx_completions_ext"; do
    [ -f "$_bx_completion_file" ] && . "$_bx_completion_file"
done
BX_COMPLETIONS_LOADED=1
unset _bx_completions_dir _bx_completions_ext _bx_completion_file
