
# desc: manage clamity configuration settings

# THIS FILE IS SOURCED INTO AND THEREFORE MUTATES THE CURRENT SHELL

# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

function _c_config_usage {
	echo "
clamity $cmd {sub-command} [options]

CONFIG SUB-COMMANDS

	list                        list config variables (sorted)
	set [default] <prop> <val>  set config variable
	show [defaults]             report environment and default settings
	unset [default] <prop>      unset config variable
"
}

function _c_config_man_page {
	_c_config_usage
	echo "ABSTRACT

	The config cmd is where you manage your clamity settings. When
	you set an option, you define it in your current shell only.
	When you set it as a default, you set it in your current shell
	_and_ in a local file that will be seen by all active and future
	clamity	terminal shells.

	Unsetting a variable affects both the current shell and if
	default is specified, removes the setting accordingly. However,
	unsetting a variable will _not_ affect other active shells.

USAGE

	list
	set [ default ] <config-option> <value>
	show [ defaults ]
	unst [ default ] <config-option>

SUB-COMMANDS

	list
		List config options

	set [default] <config-option> <value>
		Sets the config option accordingly. For booleans, use 0 or 1.
		With 'default', value will be saved in a file and enabled by
		default for all clamity sessions.

	show [defaults]
		Shows current settings (env variables prefixed with CLAMITY_).
		Add 'defaults' to see what's in your local defaults file.

	unset [default] <config-option>
		Unsets an option (returning to its built in default state).

EXAMPLES
"
	return 0
}

function _c_show_config_settings {
	DefaultCfgFile="`_defaults DefaultConfigFile`"
	[ -z "$1" ] && echo -e "\nEnvironment Variables\n---------------------" && env|grep ^CLAMITY_|sort && return 0
	[ "$1" = "defaults" -o "$1" = "default" ] || { echo "usage: clamity config show [defaults]" && return 1; }
	[ ! -f "$DefaultCfgFile" ] && echo "No defaults defined" && return 0
	echo -e "\nDefaults from $DefaultCfgFile:\n---------------------------" && cat $DefaultCfgFile || return 1
	echo
}

# very very poor man's file editing - add 'eVar=val' to default config file
function _c_set_var {
	local prop="$1" val="$2" setDefault="$3"
	# echo "export CLAMITY_$prop=\"$val\""
	local eVar="CLAMITY_$prop"
	eval `echo "export $eVar=$val"`   # update the current shell's env
	# eval `echo export $prop="$val"`
	[ $setDefault -eq 0 ] && env|grep "^$eVar=" && return 0

	# Save as default setting
	[ ! -d $CLAMITY_HOME/config ] && { mkdir -p $CLAMITY_HOME/config || return 1; }

	# append or create if option not present
	if [ ! -f "$DefaultCfgFile" ]; then
		echo "$eVar=$val" >$DefaultCfgFile || return 1
	else
		# backup pre-existing config and update
		cp -p "$DefaultCfgFile" "$DefaultCfgFile.undo" || return 1
		(grep -v "$eVar=" $DefaultCfgFile.undo; echo "$eVar=$val")|sort >$DefaultCfgFile || return 1
	fi
	echo "`grep ^$eVar= $DefaultCfgFile` (defaulted)"
}

# remove eVar from default config file
function _c_unset_var {
	local prop="$1" setDefault
	shift
	[ "$2" = "default" ] && setDefault=1 && shift || setDefault=0
	local eVar="CLAMITY_$prop"
	unset $eVar
	local rc=0
	[ -n "`_evar_is $eVar`"] && _error "$eVar still set?" && rc=1
	[ $setDefault -eq 0 ] && return $rc

	if [ -f "$DefaultCfgFile" ]; then
		grep -q "$eVar=" "$DefaultCfgFile" || return $rc	# config parm not in defaults
		# comment out parm
		cp -p $DefaultCfgFile $DefaultCfgFile.undo || return 1
		grep -v "$eVar=" $DefaultCfgFile.undo |sort >$DefaultCfgFile
	fi
	return $rc
}

function _c_set_config {
	local DefaultCfgFile="`_defaults DefaultConfigFile`"
	local setAsDefault=0 UnSet=0
	# _debug "_c_set_config: $*"
	# extended 'default' option
	case "$1" in
		default)	# set default
			setAsDefault=1 && shift;;
		unset)		# unset [default]
			UnSet=1 && shift
			[ "$1" = "default" ] && setAsDefault=1 && shift;;
	esac
	local prop="$1" val="$2"
	# echo "Prop=$prop   val=$val"

	# validate input
	! _is_known_prop "$prop" && _warn "unknown config property: $prop" && return 1
	[ $UnSet -eq 1 ] && [ -n "$val" ] && _warn "unset does not accept a value" && return 1
	[ $UnSet -eq 0 ] && [ -z "$val" ] && _warn "set requires a property and value" && return 1

	[ $UnSet -eq 0 ] && { _c_set_var "$prop" "$val" "$setAsDefault"; return $?; }
	_c_unset_var "$prop" "$setAsDefault"
}


# Handle usage and command man page
subcmd="$1"
[ -z "subcmd" ] && _c_config_usage && return 1
[ "$subcmd" = help ] && _c_config_man_page && return 1
shift

# Execute sub-commands
case "$subcmd" in
	show) _c_show_config_settings "$@" || return 1;;
	set|unset) _c_set_config "$@" || return 1;;
	list) _print_clamity_config_options || return 1;;
	*) _c_config_usage && return 1;;
esac
return 0
