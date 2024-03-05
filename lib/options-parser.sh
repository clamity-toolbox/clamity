
# shell parameter parsing

# [ -n "$__clammod_options_parser_loaded" ] && return 0 || __clammod_options_parser_loaded=1

# A Simple shell options parser that exists at the clamity python option
# parser's good graces. It offers a relatively easy (limited) way to create
# shell scripts for automation w/o having to consider various run-time
# environments.

# Options are exported as env vars prefixed with 'CLAMITY_', such as:
#   CLAMITY_verbose="1"
#   CLAMITY_optWithValue="sub-value"

# Options are all strings. Those evaluated as boolean use the _is_false
# shell function as their source of truthiness.

# This module contains hard-coded values taken from etc/variables/common.json
# and so should be kept in sync with that file.



# --------------------------------

# Usage statements are generated on demand relying upon the '# desc:' comment
# line in all command and sub-command scripts.
#
# Man Pages for commands are implemented as sspecial functions named
# 'command_man_page' (one per command). See cmds/_templates/shell-command

function _usage {	# standard command usage (see cmds/_templates/)
	local cmd="$1" subcmd="$2" customCmdDesc="$3"
	# echo "__usage. cmd=$1 subcmd=$2 customUsage=$3" >&2
	[ -z "$subcmd" ] && __usage2 "$cmd" "$subcmd" "$customCmdDesc" && return 1
	# *** command_man_page MUST be defined ***
	[ "$subcmd" = help ] && __usage2 "$cmd" "$subcmd" "$customCmdDesc" && command_man_page "$cmd" "$customCmdDesc" && return 1
	return 0
}

function __usage2 {	# generic usage for clamity command
	local cmd="$1" subcmd="$2" customUsage="$3"
	# echo "__usage2. cmd=$1 subcmd=$2 customUsage=$3" >&2
	echo "
	clamity $cmd {sub-command} [options]

`echo $cmd|tr a-z A-Z` SUB-COMMANDS

`_describe_sub_commands $CLAMITY_ROOT/cmds/$cmd.d "$customUsage"`
"
}

function __desc_of {	# pull the description of a command from the comment
	grep '^# desc:' "$1" | cut -f2 -d: | _ltrim
}

function _describe_sub_commands {	# print cmds desc from dir($1). Includes optional commands($2).
	local dir="$1" customUsage="$2" subcmd
	# echo "_describe_sub_commands($*)" >&2
	[ -n "$customUsage" ] && echo -e $customUsage >/tmp/usage$$ || >/tmp/usage$$
	for subcmd in $(cd "$dir" && ls); do
		[ ! -x $dir/$subcmd -o -d $dir/$subcmd ] && continue
		local dispCmd=$(basename $dir/$subcmd|cut -f1 -d.)
		local cmdDesc="`__desc_of $dir/$subcmd | _ltrim`"
		echo -e "\t$dispCmd - $cmdDesc" >>/tmp/usage$$
	done
	cat /tmp/usage$$ | grep -v '^$' | sort
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

# This should all sync up with etc/variables/common.json.
# It's probably not tenable

function parse_common_options_help {
	echo "COMMON OPTIONS

	-d, --debug
		Debug mode provides additional, lower-level output (CLAMITY_debug=1). Debug
		messages are sent to stderr.

	-n, --dryrun
		Allows for execution of a script withot causing an underlying change to whatever
		data the script affects. It is up to each script to determine what that means.
		Some scripts do not support dryrun and will terminate immediately if it's enabled
		(CLAMITY_dryrun=1).

	-of, --ofmt, --output-format <format>
		Values include 'json', 'table' and 'csv' (CLAMITY_output_format="json").

	-q, --quiet
		Suppress all reporting except warnings and errors (CLAMITY_quiet=1).

	-v, --verbose
		Enable extra reporting (CLAMITY_verbose=1).

	-y, --yes
		Disables interactive mode in which commands that prompt for confirmation before
		doing things will automatically get answered with 'yes' (CLAMITY_yes=1).
"
}

function _defaults {	# hard coded properties in one place
	[ "$1" = DefaultConfigFile ] && echo "$CLAMITY_HOME/config/defaults.env"
}

__clamity_common_props="verbose dryrun debug quiet yes output_format"
__clamity_other_props="disable_module_cache"
__clamity_known_props="$__clamity_common_props $__clamity_other_props"

function _clamity_config_options {
	local i
	for i in `echo $__clamity_known_props`; do echo $i; done | sort
}

function _is_known_prop {	# success if property is known
	echo "$__clamity_known_props" | grep -q "$1"
}

function __c_array {	# treat a space delimited string as an array
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
	local optionDefault optionSwitches optionSetTo
	for opt in $__clamity_known_props; do
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
				optionSwitches="-of|--ofmt|--output-format"
				optionDefault="table"
				optionSetTo=":"
				;;
		esac
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
			[ "$defaultValue" != '-' ] && assignment="$varName='$defaultValue'" && eval $assignment
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

function parse_clamity_options {
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
