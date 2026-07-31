# BVM fish shell initialization
set -q BVM_HOME; or set -gx BVM_HOME $HOME/.bvm
set -q BOXLANG_HOME; or set -gx BOXLANG_HOME $HOME/.boxlang

fish_add_path --prepend $BVM_HOME/bin

if test -d $BVM_HOME/current/bin
    fish_add_path --prepend $BVM_HOME/current/bin
end

fish_add_path --prepend $BOXLANG_HOME/bin
