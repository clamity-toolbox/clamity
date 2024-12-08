# desc: manage clamity configuration settings

# THIS FILE IS SOURCED INTO, AND THEREFORE MUTATES, THE CURRENT SHELL
# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1
source $CLAMITY_ROOT/etc/options/common.sh || return 1

cmd=config
subcmd="$1"
[ -n "$subcmd" ] && shift

_trace "config.sh> CLAMITY_os_preferred_pkg_mgr=$CLAMITY_os_preferred_pkg_mgr"

# ---------------------------------------------------------------------------
# Define content for brief help and the manpage for this command. Comment out
# any that does not apply. The formatting of the strings is important to
# maintain - shell data handling is simplistic.
# ---------------------------------------------------------------------------

# More descriptive overview of the command. Paragraph(s) allowed. This is
# included on a man page. (REQUIRED)
__Abstract="
	The config cmd is where you manage your clamity settings. When
	you set an option, you define it in your current shell only.
	When you set it as a default, you set it in your current shell
	_and_ in a local file that will be seen by all active and future
	clamity	terminal shells.

	Unsetting a variable affects both the current shell and if
	default is specified, removes the setting accordingly. However,
	unsetting a variable will _not_ affect other active shells. For
	this, each shell would have to run 'clamity config reset'.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity $cmd list
	clamity $cmd { set | unset } [default] {config-opt} [value]
	clamity $cmd show [defaults]
"

# Don't include common options here
# __CommandOptions=""
__CommandOptions="DESCRIPTIONS

	list
		list common config options

	set ['default'] <config-opt> <value>
		Sets a configuration option <config-opt>. For a list of _some_
		config options, run 'clamity config list'. Options aren't managed
		centrally. The 'default' keyword stores the setting and applies to
		all current shells using clamity. Otherwise, the setting is only
		in the environment of the current terminal shell.

	show ['defaults']
		Print the options. 'default' shows the options from the persistent
		settings file. otherwise it lists the options set in the environment.

	unset ['default'] <config-opt>
		Unsets an option (see set).
"
# COMMAND OPTIONS

# 	--opt-a
# 		No additional arg. boolean. Use _is_true() and _is_false() funcs
# 		to evaluate.

# 	--opt-name <name>
# 		the name of the thing you specifed using --opt-name.
# "

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
__CustomSections="BOOLEAN EVALUATION

	Boolean truthiness defines 'false' as an empty string or a case insensitive
	match to anything matching to 'n|no|0|null|none|undefined|undef|f|false'.
	Convention for setting booleans is to set them to a value of 1.

	The 'lib/_.sh:_is_false()' shell function is the source of truth for
	truthiness.

SUPPORTED SHELLS

	bash, zsh
"
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
__Examples="
	Set verbose on by default (CLAMITY_verbose)
		clamity config set default verbose 1

	Set debug for my session only (CLAMITY_debug)
		clamity config set debug 1
"
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
\n\tlist - list config variables
\n\tset - set a config variable
\n\tshow - report env and default settings
\n\tunset - unset config variable
"
# ---------------------------------------------------------------------------

function _c_show_config_settings {
	DefaultCfgFile="$(_defaults DefaultsFile)"
	[ -z "$1" ] && echo -e "\nEnvironment Settings\n---------------------" && env | grep ^CLAMITY_ | sed -e 's/^CLAMITY_//' | sort && return 0
	[ "$1" = "defaults" -o "$1" = "default" ] || { _warn "usage: clamity config show [defaults]" && return 1; }
	[ ! -f "$DefaultCfgFile" ] && echo "No defaults defined" && return 0
	echo -e "\nDefaults from $DefaultCfgFile:\n---------------------------" && cat $DefaultCfgFile || return 1
	echo
}

function _c_is_var_defaulted {
	grep -q "^CLAMITY_$1=" $DefaultCfgFile
}

# poor man's file editing - add 'eVar=val' to default config file
function _c_set_var {
	local prop="$1" val="$2" setDefault="$3"
	# echo "export CLAMITY_$prop=\"$val\""
	local eVar="CLAMITY_$prop"
	eval $(echo "export $eVar=$val") # update the current shell's env
	# eval `echo export $prop="$val"`
	[ $setDefault -eq 0 ] && env | grep "^$eVar=" && return 0

	# Save as default setting
	[ ! -d $CLAMITY_HOME/config ] && { mkdir -p $CLAMITY_HOME/config || return 1; }

	# append or create if option not present
	if [ ! -f "$DefaultCfgFile" ]; then
		echo "$eVar=$val" >$DefaultCfgFile || return 1
	else
		# backup pre-existing config and update
		cp -p "$DefaultCfgFile" "$DefaultCfgFile.undo" || return 1
		(
			grep -v "$eVar=" $DefaultCfgFile.undo
			echo "$eVar=$val"
		) | sort >$DefaultCfgFile || return 1
	fi
	echo "$(grep ^$eVar= $DefaultCfgFile) (defaulted)"
}

# remove eVar from default config file
function _c_unset_var {
	local prop="$1" setDefault="$2"
	_c_is_var_defaulted "$prop" && [ $setDefault -eq 0 ] && echo "$prop has a default setting. Use 'unset default'" && return 1
	local eVar="CLAMITY_$prop"
	unset $eVar
	local rc=0
	[ -n "$(_evar_is $eVar)" ] && _error "why is $eVar still set?" && rc=1
	[ $setDefault -eq 0 ] && return $rc

	if [ -f "$DefaultCfgFile" ]; then
		grep -q "$eVar=" "$DefaultCfgFile" || return $rc # config parm not in defaults
		# comment out parm
		cp -p $DefaultCfgFile $DefaultCfgFile.undo || return 1
		grep -v "$eVar=" $DefaultCfgFile.undo | sort >$DefaultCfgFile
	fi
	return $rc
}

function _c_set_config {
	local DefaultCfgFile="$(_defaults DefaultsFile)"
	[ "$1" = "set" ] && local UnSet=0 || UnSet=1
	shift
	[ "$1" = "default" ] && local setAsDefault=1 && shift || local setAsDefault=0
	local prop="$1" val="$2"
	# echo "Prop=$prop   val=$val"

	# validate input
	! __c_is_known_prop "$prop" && _warn "unknown config property: $prop" && return 1
	[ $UnSet -eq 1 ] && [ -n "$val" ] && _warn "unset does not accept a value" && return 1
	[ $UnSet -eq 0 ] && [ -z "$val" ] && _warn "usage: clamity config set [default] <prop> <val>" && return 1

	[ $UnSet -eq 0 ] && {
		_c_set_var "$prop" "$val" "$setAsDefault"
		return $?
	}
	_c_unset_var "$prop" "$setAsDefault"
}

[ -z "$subcmd" ] && {
	_brief_usage "$customCmdDesc" "$subcmd"
	return 1
}
[ "$subcmd" = help ] && {
	_man_page "$customCmdDesc" "$cmd"
	return 1
}
_trace "config.sh> $CLAMITY_os_preferred_pkg_mgr=CLAMITY_os_preferred_pkg_mgr"

# Execute sub-commands
case "$subcmd" in
show) _c_show_config_settings "$@" || return 1 ;;
set | unset) _c_set_config "$subcmd" "$@" || return 1 ;;
list) _print_clamity_config_options || return 1 ;;
*) _warn "unknown sub-command $subcmd. Try 'help'." && return 1 ;;
esac
return 0
