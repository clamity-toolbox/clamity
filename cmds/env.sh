
# desc: mutate the shell's environment

# THIS FILE IS SOURCED INTO AND THEREFORE MUTATES THE CURRENT SHELL

# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

cmd=shenv
subcmd="$1"
[ -n "$subcmd" ] && shift


# ---------------------------------------------------------------------------
# Define content for brief help and the manpage for this command. Comment out
# any that does not apply. The formatting of the strings is important to
# maintain - shell data handling is simplistic.
# ---------------------------------------------------------------------------

# More descriptive overview of the command. Paragraph(s) allowed. This is
# included on a man page. (REQUIRED)
__Abstract="
	Mutate the current shell environment.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity env add-python
"

# Don't include common options here
__CommandOptions="
	None

MORE

	add-python
		Adds the clamity python virtual environment's bin/ directory to your
		shell's search path (PATH) making python package commands available.
		This will also reset your default python3 version to clamity's.
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

customCmdDesc=""
# ---------------------------------------------------------------------------


[ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" "$cmd"; return 1; }

# Execute sub-commands
case "$subcmd" in
	add-python) eval `$CLAMITY_ROOT/bin/clam-py venv`;;
	*) _warn "unknown sub-command $subcmd. Try 'help'." && return 1;;
esac
return 0
