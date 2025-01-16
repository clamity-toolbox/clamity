#!/usr/bin/env bash

# desc: use the clamity python environment (clam-py)

source $CLAMITY_ROOT/lib/_.sh || return 1

__Abstract="
	Work with the clamity python virtual environment & run python scripts.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity py { activate }
	clamity py <python-command> <args>
"

# Don't include common options here
__CommandOptions="DESCRIPTIONS

	activate
		Activates a session with the clamity python virtual environment. To
		exit the session, type 'deactivate'.
"

# For commands that have their own special env vars, inlude this section in
# the man page.
__EnvironmentVariables=""
# __EnvironmentVariables="
# 	CLAMITY_SHCMD_FEATURE
# 		This means something to my shell script and is managed by me and
# 		not the config settings module. Possible values include a, true
# 		or a bag of potato chips.
# "

# Optional pre-formatted section inserted towards end before Examples
__CustomSections=""

# SUB-COMMANDS
#
# 	list
# 		List config options
#
# 	set [default] <config-option> <value>
# 		Sets the config option accordingly. For booleans, use 0 or 1.
# 		With default, value will be saved in a file and enabled by
# 		default for all clamity sessions.
#
# 	show [defaults]
# 		Shows current settings (env variables prefixed with CLAMITY_).
# 		Add 'defaults' to see what's in your local defaults file.
#
# 	unset [default] <config-option>
# 		Unsets an option (returning to its built in default state).

# Showing examples for comman tasks proves to be very useful in man pages.
__Examples=""
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Locally implement sub command help
#
# Locally impleneted sub commands are those which aren't implemented as scripts
# located in the $CLAMITY_ROOT/bin/cmds/<cmd>.d/ directory. In order to add them
# to the usage and man page output, maintain this variable.
#
# Note how each command is on its own line prefixed with '\n\t'.

customCmdDesc="
\n\tactivate - activate clamity's python virtual environment
"
# ---------------------------------------------------------------------------

cmd=py
_usage "$customCmdDesc" "$cmd" "$1" -command || return 1
subcmd="$1" && shift

# _cmds_needed cmd1 cmd2 || { _error "Command(s) not found. One of: cmd1 cmd2" && exit 1; }

_sub_command_is_external $cmd $subcmd && {
	_run_clamity_subcmd $cmd $subcmd "$@"
	return $?
}

_set_standard_options "$@"
# echo "$@" | grep -q '\--abc' && _opt_abc=1 || _opt_abc=0

# Execute sub-commands
rc=0
case "$subcmd" in
activate)
	$CLAMITY_ROOT/bin/clam-py activate
	eval $($CLAMITY_ROOT/bin/clam-py activate)
	;;
*)
	_run $CLAMITY_ROOT/bin/clam-py "$subcmd" "$@" || rc=1
	;;
esac

# _clear_standard_options _opt_abc
_clear_standard_options
return 0
