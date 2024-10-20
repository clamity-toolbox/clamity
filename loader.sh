
# Loads the clamity shell function.
#
# Supported shells: bash, zsh

# set CLAMITY_ROOT - determine shell compatibility
[ -z "$CLAMITY_ROOT" ] && [ -n "$BASH_SOURCE" ] && export CLAMITY_ROOT="`dirname $BASH_SOURCE`"
[ -z "$CLAMITY_ROOT" ] && [ -n "$ZSH_VERSION" ] && setopt function_argzero && export CLAMITY_ROOT="`dirname $0`"
[ -z "$CLAMITY_ROOT" ] && echo "unsupported shell. maybe try setting CLAMITY_ROOT ?" && return 1
[ ! -f "$CLAMITY_ROOT/loader.sh" ] && echo "Is CLAMITY_ROOT=$CLAMITY_ROOT correct? loader.sh isn't where it's supposed to be." && return 1

source $CLAMITY_ROOT/lib/_.sh || return 1

[ -n "`_os`" ] || return 1  # unsupported OS

# set CLAMITY_HOME - location of clamity local configuration and working data
[ -z "$CLAMITY_HOME" ] && export CLAMITY_HOME="`_defaults ClamityHome`"

function clamity {
	# setup clamity home dir
	[ ! -d "$CLAMITY_HOME/logs" ] && { echo "mkdir -p $CLAMITY_HOME/logs" && mkdir -p "$CLAMITY_HOME/logs" || { echo "cannot create $CLAMITY_HOME/logs" >&2 && return 1; } }

	# run a clamity command
	_run_clamity_cmd "" "$@"
}

_load_clamity_defaults || return 1

echo $* | grep -q '\--quiet' || echo "Type 'clamity' for usage, 'clamity help' for more."

return 0
