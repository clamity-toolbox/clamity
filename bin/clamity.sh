#!/usr/bin/env bash

# primatives
function cprim__remove_leading_blanks {
	awk '{$1=$1};1'
}

# Pick up all directories in bin/plugins/
function plugin_dirs {
	local pluginDir
	for pluginDir in $(/bin/ls $CLAMITY_ROOT/bin/plugins); do
		[ -d "$CLAMITY_ROOT/bin/plugins/$pluginDir" ] && echo $pluginDir
	done
}

function list_plugins {
	ls "$CLAMITY_ROOT"/bin/plugins/*/$SUBCMD 2>/dev/null
}

# args: list of plugin directories to search
# prints custom commands part of usage statement
function list_action_plugins {
	local dir="" cmd=""
	for dir in "$@"; do
		[ -n "$cmd" ] && echo   # skip first iteration
		for cmd in $(echo $CLAMITY_ROOT/bin/plugins/$dir/*); do
			[ ! -x "$cmd" ] && continue    # exclude anything non-executable
			egrep -q '^(#|//)[[:blank:]]*brief_description:' "$cmd"  || continue  # no summary available
			echo -ne "\t`basename $cmd`\t\t"
			egrep '^(#|//)[[:blank:]]*brief_description:' "$cmd"|cut -f2 -d:|cprim__remove_leading_blanks
		done
	done
}

function usage {
	echo "
A structured platform framework for development & production operations and automation.

SYNOPSIS

	One of zillions of approaches to structure a development and operations platform
	for the purpose of automation, deployment, operational management and the
	facilition of the SDLC.

USAGE

	clamity [clamity-options] {sub-command} [parameters ...] [sub-command-options]

SUB-COMMANDS

	help			Provide useful assistance (like this message)"
	list_action_plugins $(plugin_dirs)
	# common_options_help
	echo "
CLAMITY OPTIONS

EXAMPLES

	Examples are always welcome.
"
}

[ -z "$2" ] && usage && exit 1
clamOptions="$1"
SUBCMD=$2
shift 2 || exit 1

# accomodate custom plugins - highest priority; if one exists execute it.

# two plugins with the same name is a no-no.
[ $(list_plugins | wc -l)  -gt 1 ] && { echo "duplicate found." >&2; list_plugins; exit 1; }

export PATH="$CLAMITY_ROOT/bin:$PATH"

if [ $(list_plugins | wc -l)  -eq 1 ]; then
	# Run custom plugin
	plugin=$(list_plugins)
	[ ! -x "$plugin" ] && echo "Plugin $plugin not executable. You probably shouldn't be running it." && exit 1
	$plugin $clamOptions "$@"
	exit $?
fi

export PYTHONPATH=$CLAMITY_ROOT/lib:$PYTHONPATH

# Last priority is to run clamity python
clamity.py "$@"
