
# echo clamity-shenv is meant to be sourced in.
#
# Supported shells: bash, zsh

function _local_usage {
	echo "
	clamity shell [sub-command] ...

	help                useful information
	vars                display CLAMITY env vars
	"
}

[ -z "$1" ] && _local_usage && return 1
[ "$1" = "vars" ] && { env|grep ^CLAMITY_ ; return $?; }

_local_usage
return 1
