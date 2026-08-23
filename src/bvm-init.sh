#!/bin/sh

# BVM shell initialization
BVM_HOME="${BVM_HOME:-$HOME/.bvm}"
BVM_BIN="$BVM_HOME/bin"
BOXLANG_HOME="${BOXLANG_HOME:-$HOME/.boxlang}"
BOXLANG_BIN="$BOXLANG_HOME/bin"
export BVM_HOME
export BOXLANG_HOME

# Add BVM bin directory to PATH if it is not already present
case ":${PATH:-}:" in
    *":$BVM_BIN:"*) ;;
    *) PATH="$BVM_BIN${PATH:+:$PATH}" ;;
esac

# Add current BVM version bin directory to PATH if it exists and is not already present
if [ -d "$BVM_HOME/current/bin" ]; then
    case ":$PATH:" in
        *":$BVM_HOME/current/bin:"*) ;;
        *) PATH="$BVM_HOME/current/bin:$PATH" ;;
    esac
fi

# Add BoxLang HOME bin directory to PATH if it is not already present
case ":$PATH:" in
    *":$BOXLANG_BIN:"*) ;;
    *) PATH="$BOXLANG_BIN:$PATH" ;;
esac

export PATH

# Load BVM command completion when supported by the current shell
if [ -s "$BVM_HOME/scripts/bvm-completions.sh" ]; then
    . "$BVM_HOME/scripts/bvm-completions.sh"
fi

# Load bash completions contributed by installed BoxLang modules (see
# `boxlang.completions` in a module's box.json). Each module's script is
# expected to self-register its own `complete` binding.
if [ -n "${BASH_VERSION:-}${ZSH_VERSION:-}" ] && [ -d "$BOXLANG_HOME/completions" ]; then
    for bx_completion_file in "$BOXLANG_HOME"/completions/*.sh; do
        [ -f "$bx_completion_file" ] && . "$bx_completion_file"
    done
    unset bx_completion_file
fi
