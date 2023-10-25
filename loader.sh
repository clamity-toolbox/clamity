
# This is sourced into the current shell environment. Keep it brief!
#
# supported shells: bash, zsh
#
# optional args
#    $1  /path/to/clamity/project/repo  (CLAMITY_ROOT)

function _is_true {
    [ -n "$1" ] && echo "$1" | egrep -qie '1|yes|y|true|t'
}
function _is_false {
    ! _is_true "$1"
}
function _dirname {
    echo "$1" | grep -q '/' && (cd `dirname "$1"` && pwd)
}

# _is_false "$CLAMITY_SHELL_CACHE_DISABLE" && [ -n "$__clam_loaded" ] && return 0  # cache shell libs

[ -z "$CLAMITY_ROOT" ] && { [ -n "$1" ] && export CLAMITY_ROOT="$1" || export CLAMITY_ROOT=$(_dirname "$0"); }
[ -z "$CLAMITY_ROOT" ] && echo "Cannot determine CLAMITY_ROOT. Set it with 'export CLAMITY_ROOT=/full/path/to/repo'." >&2 && return 1

__clam_loaded=1

# Main CLI command is implemented as a shell function
function clamity {
    [ "$1" = "shell" ] && { shift && source $CLAMITY_ROOT/bin/clamity-shenv.sh -no-opts "$@"; return $?; }
    $CLAMITY_ROOT/bin/clamity.sh -no-opts "$@"
}
# export -f clamity

return 0
