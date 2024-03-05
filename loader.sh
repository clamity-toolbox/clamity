
# Loads the clamity shell function.
#
# Supported shells: bash, zsh

function clamity {
	# setup clamity home dir
	[ ! -d "$CLAMITY_HOME/logs" ] && { mkdir -p "$CLAMITY_HOME/logs" || { echo "cannot create $CLAMITY_HOME/logs" >&2 && return 1; } }

	# run a clamity command
	_run_clamity_cmd "" "$@"
}

# set CLAMITY_ROOT - where the clamity code is located
_scriptDir=$(cd `dirname $0` && pwd)
[ -z "$CLAMITY_ROOT" ] && export CLAMITY_ROOT="$_scriptDir"
[ "$_scriptDir" != "$CLAMITY_ROOT" ] && echo "loader script location ($_scriptDir) does not match CLAMITY_ROOT ($CLAMITY_ROOT)" >&2 && return 1

source $CLAMITY_ROOT/lib/_.sh || return 1

# set CLAMITY_HOME - location of clamity local configuration and working data
[ -z "$CLAMITY_HOME" ] && export CLAMITY_HOME="$HOME/.clamity"

_load_clamity_defaults || return 1

echo $* | grep -q '\--quiet' || echo "Type 'clamity' for usage, 'clamity help' for more."

return 0
