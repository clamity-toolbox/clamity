
# Provides a relatively easy (limited) way to manage options for shell scripts
# and the environment so simple tasks can be added to clamity w/o having to rely
# on any particular language's run-time configuration.
#
# Also provides basic usage and man page components for creating consistant
# command line help.

# Options are EXPORTED env vars prefixed with 'CLAMITY_', Such as:
#   CLAMITY_verbose="1"
#   CLAMITY_optWithValue="sub-value"

# Options (shell env vars) are strings. Those evaluated as boolean use the
# _is_false() shell function in  (lib/_.sh) to evaulate truthiness.

# clamity has support for groups of options (option groups) which facilitates
# providing consistency between commands. One group of note, common options,
# are included by default for all commands. See etc/options/common.sh.

# This libarary contains hard-coded values taken from etc/options/common.json
# and should be kept in sync with that file.



# --------------------------------

# Usage statements are generated on demand relying upon the '# desc:' comment
# line in all command and sub-command scripts.
#
# Man Pages for commands are implemented as sspecial functions named
# 'command_man_page' (one per command). See cmds/_templates/shell-command

function __desc_of {	# pull the description of a command from the comment
	grep '^# desc:' "$1" | cut -f2 -d: | _ltrim
}

function _usage {	# standard command usage (see cmds/_templates/)
	local customCmdDesc="$1" cmd="$2" subcmd="$3"
	[ -z "$subcmd" ] && _brief_usage "$customCmdDesc" "$cmd" "$subcmd" && return 1
	# shift 3
	[ "$subcmd" = help ] && __usage_help "$customCmdDesc" "$cmd" "$subcmd" | less && return 1
	# no usage was required, return success
	return 0
}

function _brief_usage {
	local customCmdDesc="$1" cmd="$2"
	echo -e "USAGE\n$__Usage"
	__describe_sub_commands "$customCmdDesc" "$cmd" action
	return 0
}

function _sub_man_page {
	local customCmdDesc="$1" subcmd="$2"
	__usage_help "$customCmdDesc" "$subcmd" action | less
}

function _man_page {
	local customCmdDesc="$1" cmd="$2" flags="$3"
	__usage_help "$customCmdDesc" "$cmd" "$flags" | less
}

function __usage_help {
	local customCmdDesc="$1" cmd="$2" flags="$3"
	echo -e "USAGE\n$__Usage"
	echo -e "ABSTRACT\n\t$__Abstract"
	__describe_sub_commands "$customCmdDesc" "$cmd" "$flags"
	[ -n "$__CommandOptions" ] && echo -e "COMMAND OPTIONS\n\t$__CommandOptions"
	echo $flags | grep -q '\-no-common-opts' || _parse_options_help common
	[ -n "$__CustomSections" ] && echo -e "$__CustomSections"
	[ -n "$__EnvironmentVariables" ] && echo -e "ENVIRONMENT VARIABLES\n\t$__EnvironmentVariables"
	[ -n "$__Examples" ] && echo -e "EXAMPLES\n\t$__Examples"
	return 0
}

function __describe_sub_commands {	# print cmds descriptions
	local customUsage="$1"  	# custom string prefixed to sub commands section
	local cmd="$2"				# usage for this sub command or clamity string for top level
	local flags="$3"
	# local formatFor="$3"		# manpage | usage - formats output
	# local skipFinalEcho="$4"	# true to skip final echo (more formatting)
	local dir="$CLAMITY_ROOT/cmds/$cmd.d"

	local optsTitlePrefix="SUB-"
	local optsTitle="COMMANDS"
	[ "$cmd" = clamity ] && cmd=clamity && dir="$CLAMITY_ROOT/cmds" && optsTitlePrefix=""
	echo "$flags" | grep -q 'action' && optsTitlePrefix="" && optsTitle="ACTIONS"

	[ -n "$customUsage" ] && echo -e "$customUsage" >/tmp/usage$$ || echo -e "" >/tmp/usage$$
	if [ -d "$dir" ]; then
		# pull out the '# desc:' string from all sub-command scripts
		local _cmd
		for _cmd in $(cd "$dir" && ls); do
			[ ! -x $dir/$_cmd -o -d $dir/$_cmd ] && continue
			local dispCmd=$(basename $dir/$_cmd|cut -f1 -d.)
			echo -e "\t$dispCmd - `__desc_of $dir/$_cmd`" >>/tmp/usage$$
		done
	fi
	if [ `cat /tmp/usage$$ | grep -v '^$' | wc -l` -gt 0 ]; then
		echo -e "`echo $cmd | tr '[a-z]' '[A-Z]'` ${optsTitlePrefix}${optsTitle}\n" || echo
		cat /tmp/usage$$ | grep -v '^$' | sort
		echo
	fi
	/bin/rm -f /tmp/usage$$
	return 0
}

# --------------------------------

# The options parser is implemeted as two function calls. The first prepares the
# defaults and option spec. The second parses the options.
#
# Upon completion, the option values will exist as exported environment
# variables prefiexed with 'CLAMITY_' and the shell's input variables will
# represent the positional arguments passed to the command (if applicable).

# This first call identifies all the options (not including common options
# which are always available) and sets their defaults in the environment.
#
# setup_clamity_options_parser \
# 	optVarName    --opt-name    "<value-if-set>"  "<default>" \
# 	boolOpttName  --opt2-name   1                 0 \
# 	optWithValue  --val-opt     :                 ""       # : expects 1 arg

# This does the parsing work and sets each option to its correct value,
# and exports the environment variable.
#
# parse_clamity_options "$@"

# This last line accomodates an optional '--' which sometimes can be used to
# identify the start of positional arguments.
#
# eval set -- ${PARGS_POSITIONAL[@]}

source $CLAMITY_ROOT/etc/options/common.sh || return 1
__clamity_known_props=`__c_opts_common_list`

# This should all sync up with etc/options/*.json.
# It's probably not tenable

function _parse_options_help {  # $1 = variable group (common, ...)
	case "$1" in
		common) __c_opts_common_help;;
	esac
	return 0
}

function _defaults {	# source of truth for hard coded properties
	local x=$(grep ^$1= $CLAMITY_ROOT/etc/options/defaults.sh | cut -d= -f2-)
	[ -n "$x" ] && eval echo $x
}


function _print_clamity_config_options {
	local i
	for i in `echo $__clamity_known_props`; do echo $i; done | sort
}

function _is_known_prop {	# success if property is known
	echo "$__clamity_known_props" | grep -q "$1"
}

function _is_one_of {	# success if value($1) is found in the remaining arg list($@)
	local value="$1" i
	shift
	for i in "$@"; do [ "$value" = "$i" ] && return 0; done
	return 1
}

function _is_prop_ok {	# validate known properties
	local prop="$1" value="$2"
	case "$prop" in
		package_manager)
			_is_one_of "$value" port brew yum && _cmd_exists "$value" && return 0
			_warn "bad package manager: $value. Maybe it's not installed?"
			;;
		*)
			return 0;;
	esac
	return 1
}

# array object performs an action($1, init|get|add|print|indexOf) on an array($2, space delimited string)
function __c_array {
	# echo "__c_array($*)" >&2
	local action="$1" arrayVar="$2"
	shift 2
	case "$action" in
		init)	# initialize array
			eval $arrayVar="";;
		get)	# return Nth element
			local ndx=`expr $1 + 1` && _evar_is $arrayVar | cut -d' ' -f $ndx;;
		add)	# append value to array
			eval "$arrayVar=\"\$$arrayVar $1\"";;
		print)	# print the array
			echo "   $arrayVar = \"`_evar_is $arrayVar`\"";;
		indexOf)	# return index of element in array (255 for not found)
			local elt ndx=0
			for elt in `_evar_is $arrayVar`; do
				[ "$elt" = "$1" ] && return $ndx || ndx=`expr $ndx + 1`
			done
			return 255
	esac
}

# create the input parameter list to be passed to parse_clamity_options.
# This is not tenable. Generate something from etc/options/common.json
function __parse_common_options {
	local optionDefault optionSwitches optionSetTo opt
	for opt in $__clamity_known_props; do
		# echo "opt=$opt" >&2
		case $opt in
			verbose|debug|quiet|yes)
				optionSwitches="-`echo $opt|cut -c1`|--$opt"
				_is_true `_evar_is CLAMITY_$opt` && optionDefault="1" || optionDefault="0"
				optionSetTo=1
				;;
			dryrun)
				optionSwitches="-n|--dryrun"
				_is_true `_evar_is CLAMITY_dryrun` && optionDefault="1" || optionDefault="0"
				optionSetTo=1
				;;
			output_format)
				optionSwitches="-of|--output-format"
				optionDefault="json"
				optionSetTo=":"
				;;
			output_redirection)
				optionSwitches="-or|--output-redirection"
				optionDefault="none"
				optionSetTo=":"
				;;
		esac
		# echo "$opt $optionSwitches $optionSetTo $optionDefault " >&2
		echo -n "$opt $optionSwitches $optionSetTo $optionDefault "
	done
}

# prepare the options parser
function __set_option_defaults_2 {
	# poor man's tuples. Strings are space delimited
	#      (switch[0], varname[0], setTo[0]), ...
	# [0]: (-v, verbose, 1)
	# [1]: (--verbose, verbose, 1)
	# [2]: (-n, dryrun, 1)
	__c_array init PARGS_SWITCHES     # contains variable names
	__c_array init PARGS_VARNAMES     # contains option switches (-N, --yes, etc...)
	__c_array init PARGS_SWITCHARGS   # contains ':' when arg expected, value to assign
	__c_array init PARGS_POSITIONAL   # positional arguments left over

	# _debug "argCount=$#"
	# echo -e "\n__set_options_defaults_2($*)" >&2
	local assignment="" s=""
	IFS='|'
	while (( "$#" )); do
		# echo "numparms=$# :: " "$@" >&2
		local varName="$1" optionSwitches="$2" switchArgOrSetValue="$3" defaultValue="$4"
		for s in $optionSwitches; do
			# echo "varName=$varName, optionSwitches=$optionSwitches, s=$s, switchArg=$switchArgOrSetValue, defaultValue=$defaultValue" >&2
			__c_array add PARGS_SWITCHES $s
			__c_array add PARGS_VARNAMES $varName
			__c_array add PARGS_SWITCHARGS $switchArgOrSetValue
			[ "$defaultValue" != '-' ] && assignment="CLAMITY_$varName='$defaultValue'" && eval $assignment
			# echo "enter" >&2 && read
		done
		shift 4
	done
	unset IFS
}

function setup_clamity_options_parser {	# Prepares the parser and establishes defaults
	__set_option_defaults_2 $(__parse_common_options) "$@"
}

function __parse_check_option {
	[ -n "$2" ] && echo "$2"|grep -vq '^-' && return 0
	echo "value for $1 is missing" >&2
	return 1
}

function parse_clamity_options {	# sets CLAMITY_ vars based on command line args
	# echo "parse_clamity_options..." >&2
	while (( "$#" )); do
		[ "$1" = "--" ] && shift && break
		__c_array indexOf PARGS_SWITCHES "$1"
		index=$?
		if [ $index -eq 255 ]; then
			echo "$1" | grep -q '^-' && { echo "bad option: " "$1" && exit 1; } || break;
		fi
		local varName=`__c_array get PARGS_VARNAMES $index`
		local switchArg=`__c_array get PARGS_SWITCHARGS $index`
		# echo "varName=$varName, switchArg=$switchArg" >&2
		if [ "$switchArg" = ":" ]; then
			__parse_check_option "$1" "$2" || exit 1
			switchArg="$2"
			shift
		fi
		# echo "parse_clamity_options: export CLAMITY_$varName='$switchArg'" >&2
		eval "export CLAMITY_$varName='$switchArg'"
		shift
	done
	PARGS_POSITIONAL="$@"
}
