
# core clamity shell funcs
# must support bash, zsh

# echo "_.sh($0, before): $__clammod_loaded" >&2
[ -n "$__clammod_loaded" ] && return 0 || __clammod_loaded=1
# echo "_.sh($0, after): Loading _.sh" >&2

source $CLAMITY_ROOT/lib/options-parser.sh || return 1

# clamity command execution & library management
# ----------------------------------------------
function _clear_clamity_module_cache {
	# echo "_clear_clamity_module_cache()"
	local i
	for i in `declare 2>&1|grep __clammod_|cut -f1 -d=`; do	unset $i; done
	unset __clammod_loaded
	source $CLAMITY_ROOT/lib/_.sh
}

# These functions are used by both the main loader.sh and other funcs.
function _load_clamity_aliases {
	# load clamity aliases - User Aliases(1) OR Default Aliases(2)
	[ -f "$CLAMITY_HOME/aliases.sh" ] && source "$CLAMITY_HOME/aliases.sh"
	[ ! -f "$CLAMITY_HOME/aliases.sh" ] && { source "$CLAMITY_ROOT/etc/aliases.sh" || { echo "source $CLAMITY_HOME/aliases.sh failed" >&2 && return 1; } }
}

function _load_clamity_defaults {
	local envFile="`_defaults DefaultConfigFile`"
	_load_clamity_aliases || return 1

	# default envFile is optional
	[ ! -f "$envFile" ] && return 0

	_debug "_load_clamity_defaults: $envFile ($CLAMITY_load_defaults_opts)"
	_set_evars_from_env_file_if_not_set "$envFile" "$CLAMITY_load_defaults_opts"
}

# the command search path allows for introudcing and 'overloading' commands
function _run_clamity_cmd {	# opt. search path($1), cmd($2), optional cmd args($@). sets env and run cmd
	local searchPath="$1" cmd="$2"
	[ -n "$cmd" ] && shift 2 || { [ -n "$searchPath" ] && shift; }
	[ -z "$searchPath" ] && searchPath="$CLAMITY_ROOT/cmds" && [ -n "$CLAMITY_cmds_path" ] && searchPath="$CLAMITY_cmds_path:$searchPath"
	local cmdsDir ec=-1

	# normally, changes made to modules won't be seen until a new shell is launched
	_is_true $CLAMITY_disable_module_cache && _clear_clamity_module_cache

	# PATH is _not_ used to find clamity top level commands. path is restored after each command
	local pathBefore="$PATH"
	export PATH="$CLAMITY_ROOT/bin:$CLAMITY_HOME/pyvenv/bin:$PATH"

	# parse options and set defaults from a file before every command
	_load_clamity_defaults || { echo "failed to load defaults & parse opts" >&2 && return 1; }

	# FIXME: this will get flumexed if any directory paths have embedded spaces
	for cmdsDir in `echo $searchPath | tr : ' '`
	do
		[ -z "$cmd" ] &&  { [ -x "$cmdsDir/help" ] && "$cmdsDir/help"; ec=1; break; }
		[ "$cmd" = help ] && { [ -x "$cmdsDir/help" ] && "$cmdsDir/help" --full "$@"; ec=1; break; }

		# command names determine how they're executed.
		# *.sh commands are are sourced into the current shell, not executed.
		[ -f "$cmdsDir/$cmd.sh" ] && { source "$cmdsDir/$cmd.sh" "$@"; ec=$?; break; }
		[ -x "$cmdsDir/$cmd" ] && { "$cmdsDir/$cmd" "$@"; ec=$?; break; }
		[ -x "$cmdsDir/$cmd.py" ] && { $CLAMITY_ROOT/bin/run-py $cmdsDir/$cmd.py "$@"; ec=$?; break; }
		[ -x "$cmdsDir/$cmd.js" ] && { $CLAMITY_ROOT/bin/run-mode $cmdsDir/$cmd.js "$@"; ec=$?; break; }
		[ -x "$cmdsDir/$cmd.ts" ] && { $CLAMITY_ROOT/bin/run-node $cmdsDir/$cmd.ts "$@"; ec=$?; break; }
	done
	export PATH="$pathBefore"
	[ $ec -eq -1 ] && echo "unknown: $cmd. Try 'help' instead." >&2
	return $ec
}

function _run_clamity_subcmd {
	local cmd="$1" subcmd="$2"
	shift 2
	_run_clamity_cmd "$CLAMITY_ROOT/cmds/$cmd.d" "$subcmd" "$@"
}


# Data handling
# -------------
function _is_false {	# evaluate value as boolean
	[ -z "$1" ] || echo "$1" | egrep -qie '^(0|no|n|false|f|off|null|none|undef|undefined)$'
}

function _is_true {		# evaluate value as boolean
	! _is_false "$1"
}

function _ltrim {	# remove leading blanks from string
	awk '{$1=$1};1'
}

function _is_debug {	# true if debug mode
	_is_true $CLAMITY_debug
}

function _is_verbose {	# true if verbose mode
	_is_true $CLAMITY_verbose
}

function _is_quiet {	# true if quiet mode
	_is_true $CLAMITY_quiet
}

function _is_dryrun {	# true if dryrun mode
	_is_true $CLAMITY_dryrun
}

function _float_lt {  # true of $1 < $2
	[ $(echo "$1 < $2" | bc) -eq 1 ]
}

function _float_lte {  # true of $1 <= $2
	[ $(echo "$1 <= $2" | bc) -eq 1 ]
}

function _float_gt {  # true of $1 > $2
	[ $(echo "$1 > $2" | bc) -eq 1 ]
}

function _float_gte {  # true of $1 >= $2
	[ $(echo "$1 >= $2" | bc) -eq 1 ]
}

function  _opt {   # true if option($1) is in option-string($2)
	local option="$1" opts="$2"
	echo ",$opts," | grep -q "$option"
}


# manipulate environment variables / defaults
# -------------------------------------------
function _evar_is_set {		# eval evar; true if defined as non-null string
	[ -n "`eval echo \$$1`" ]
}

function _evar_is {		# eval evar; true if defined as non-null string
	eval echo \$$1
}

function _set_evars_from_env_file_if_not_set {	# set e vars from file ('VAR=VALUE'). def = -no-override
	local envFile="$1" opts="$2"
	for _e in `grep = $envFile | grep -v '^#' | cut -f1 -d=`
	do
		! _evar_is_set "$_e" || _opt -override "$opts" || continue
		grep -q ^$_e= $envFile || continue
		eval `echo -n "export "; grep ^$_e= $envFile`
	done
}

function _prepend_to_path_if {	# add all dirs to beginning of path if not in path
	local dir="" pathAdditions=""
	for dir in "$@"; do
		echo ":$PATH:" | grep -q $dir && continue	# $dir already in path
		[ -z "$pathAdditions" ] && pathAdditions="$dir" || pathAdditions="$pathAdditions:$dir"
	done
	[ -n "$pathAdditions" ] && export PATH="$pathAdditions:$PATH"
}

# i/o & logging
# -------------
function _error {	# report non-fatal errors
	echo "ERROR: ""$@" >&2
}

function _fatal {	# report fatal errors
	echo "FATAL: ""$@" >&2
}

function _warn {	# report warnings
	echo "$@" >&2
}

function _debug {	# report in debug mode
	_is_debug && echo "DEBUG: ""$@" >&2
	return 0
}

function _echo {	# default output handler
	! _is_debug && _is_quiet && return 0
	echo "$@"
}

function _vecho {	# output only in verbose or debug modes
	_is_quiet && return 0
	{ _is_debug || _is_verbose; } && echo "$@" && return 0
}

function _ask {	# prompt($1) for a y/n question and default($2). succes if 'yes'
	local prompt="$1" def_ans="$2"
	local ans=""
	[ -z "$def_ans" ] && def_ans=n
	echo -n $prompt
	_is_true $CLAMITY_yes && echo "auto-yes" && return 0
	read ans
	[ -z "$ans" ] && ans=$def_ans
	echo ",$ans," | egrep -qie ",(y|yes)," || return 1
	return 0
}


# command execution
# -----------------
function _run {	# run a command
	_is_dryrun && { echo DRYRUN: "$@"; return 0; }
	# send stdout to /dev/null in silent mode
	_is_debug && _is_quiet && { "$@" >/dev/null; return $?; }
	# log the command in debug or verbose mode before execution
	{ _is_debug || _is_verbose; } && echo "$@"
	"$@"
}

function _ask_to_run {	# prompt y/n before executing a command
	_is_true $CLAMITY_yes && { _run "$@"; return $?; }
	echo "$@"
	echo "Execute (y/N)? "
	local ans=""
	read ans
	[ "$ans" == y -o "$ans" == yes ] || return 1
	"$@"
}

function _sudo {	# execute command using sudo
	_run sudo "$@"
}

function _run_py {	# Run a python script in the clamity environment
	_run $CLAMITY_ROOT/bin/py-run "$@"
}


# OS detection and utility funcs
# ------------------------------
# macOS : >= 12
# al2 | al2023 : any
function __os_info_via_sw_vers {
	local prodName=`sw_vers --productName`
	local prodVersion=`sw_vers --productVersion`
	case "$prodName" in
		macOS)	software_version_1_gt_2 $prodVersion 12 || { _error "macOS >= 12 required"; return 1; }
				echo "macos";;
		*) 		_error "unable to identofy OS using sw_vers" && return 1;;
	esac
	return 0
}

function __os_info_via_sysrel {
	local osName=""
	cat /etc/system-release | grep -q "^Amazon Linux release 2 " && osName="al2"
	case "$osName" in
		al2) return 0;;  # all OS versions supported
		*) _error "unable to identify OS using /etc/system-release" && return 1;;
	esac
}

function _os {	# return supported OS (osx | al2 | al2023 | ubuntuXXX | ... )
	which sw_vers >/dev/null 2>&1 && { __os_info_via_sw_vers; return $?; }
	[ -f /etc/system-release ] && { __os_info_via_sysrel; return $?; }
	_error "Unable to identify OS"
	return 1
}

function _os_ver {	# report the OS version. some linux distro's use kernel ver.
	local os=`_os`
	case "$os" in
		osx) sw_vers --productVersion;;
		al2) uname -r | cut -f1 -d-;;  # use kernel version
		*) _error "unsupported OS: $os"; return 1;;
	esac
	return 0
}

function _os_arch {	# report host's architecture (arm64, x86_64, ...)
	case "`_os`" in
		macos) uname -m;; # eg. arm64
		al2) uname -m;; # eg. x86_64
	esac
}

# Poor man's JIT package management
# ---------------------------------
function _cmds_exist {	# verify command dependency
	_run $CLAMITY_ROOT/bin/run-clamity os pkg installed --ask-to-install "$@"
}
