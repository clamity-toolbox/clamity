# core clamity shell funcs - must work with supported shells (bash, zsh, ...)

function __clamity_lib_cache_enabled {
	[ -z "$CLAMITY_disable_module_cache" ] && return 0
	# [ "$CLAMITY_disable_module_cache" -eq 0 ] && echo true || echo false
	[ "$CLAMITY_disable_module_cache" -eq 0 ]
}

# __clamity_lib_cache_enabled && [ -n "$__clammod_loaded" ] && return 0 || __clammod_loaded=1
# [ -n "$__clammod_loaded" ] && return 0 || __clammod_loaded=1

source $CLAMITY_ROOT/lib/_/options-parser.sh || return 1

# library management
# ------------------
function _clear_clamity_module_cache { # reload shell libraries upon next run
	# echo "_clear_clamity_module_cache()"
	# set 2>&1 | grep __clammod_
	local i
	return 0
	for i in $(set 2>&1 | grep __clammod_ | cut -f1 -d=); do unset $i; done
	unset __clammod_loaded
	source $CLAMITY_ROOT/lib/_.sh
}

# command execution
# -----------------
# These functions are used by both the main loader.sh and other funcs.
function _load_clamity_aliases { # load aliases (user >| default)
	# load clamity aliases - User Aliases(1) OR Default Aliases(2)
	local AliasesFile=$(_defaults AliasesFile)
	[ -f "$CLAMITY_HOME/aliases.sh" ] && {
		source "$CLAMITY_HOME/aliases.sh"
		return $?
	}
}

function _load_clamity_defaults { # load clamity defaults from cfg file
	local envFile="$(_defaults DefaultsFile)"
	_load_clamity_aliases || return 1

	# default envFile is optional
	[ ! -f "$envFile" ] && return 0

	_debug "_load_clamity_defaults: $envFile ($CLAMITY_load_defaults_opts)"
	_set_evars_from_env_file_if_not_set "$envFile" "$CLAMITY_load_defaults_opts"
}

# the command search path allows for 'overloading' (and adding) commands
function _run_clamity_cmd { #  sets env and run cmd. search-path:$1 (opt), cmd:$2, args:$@ (opt)
	local searchPath="$1" cmd="$2"
	[ -n "$cmd" ] && shift 2 || { [ -n "$searchPath" ] && shift; }
	[ -z "$searchPath" ] && searchPath="$CLAMITY_ROOT/cmds" && [ -n "$CLAMITY_cmds_path" ] && searchPath="$CLAMITY_cmds_path:$searchPath"
	local cmdsDir ec=-1

	# normally, changes made to modules won't be seen until a new shell is launched
	_is_true $CLAMITY_disable_module_cache && _clear_clamity_module_cache

	# PATH is _not_ used to find clamity top level commands. PATH is restored after each command
	# local pathBefore="$PATH"
	# export PATH="$CLAMITY_ROOT/bin:$CLAMITY_HOME/pyvenv/bin:$PATH"

	_trace "_run_clamity_cmd() before load> CLAMITY_os_preferred_pkg_mgr=$CLAMITY_os_preferred_pkg_mgr"

	# parse options and set defaults from a file before every command
	_load_clamity_defaults || { _warn "failed to load defaults & parse opts" >&2 && return 1; }

	_trace "_run_clamity_cmd() after load> CLAMITY_os_preferred_pkg_mgr=$CLAMITY_os_preferred_pkg_mgr"

	# FIXME: this will get flumexed if any directory paths have embedded spaces
	for cmdsDir in $(echo $searchPath | tr : ' '); do
		[ -z "$cmd" ] && {
			[ -x "$cmdsDir/help" ] && "$cmdsDir/help"
			ec=1
			break
		}

		[ "$cmd" = help ] && {
			[ -x "$cmdsDir/help" ] && "$cmdsDir/help" help "$@"
			ec=1
			break
		}

		# command names determine how they're executed.
		# *.sh commands are are sourced into the current shell, not executed.
		[ -f "$cmdsDir/$cmd.sh" ] && {
			_trace "_run_clamity_cmd() 1 $cmdsDir/$cmd.sh $* >> $CLAMITY_os_preferred_pkg_mgr"
			source "$cmdsDir/$cmd.sh" "$@"
			ec=$?
			break
		}
		[ -x "$cmdsDir/$cmd" ] && {
			_trace "_run_clamity_cmd() 2 $cmdsDir/$cmd" "$@"
			"$cmdsDir/$cmd" "$@"
			ec=$?
			break
		}
		[ -x "$cmdsDir/$cmd.py" ] && {
			_trace "_run_clamity_cmd() 3 $cmdsDir/$cmd" "$@"
			$CLAMITY_ROOT/bin/clam-py $cmdsDir/$cmd.py "$@"
			ec=$?
			break
		}
		[ -x "$cmdsDir/$cmd.js" ] && {
			_trace "_run_clamity_cmd() 4 $cmdsDir/$cmd" "$@"
			$CLAMITY_ROOT/bin/run-mode $cmdsDir/$cmd.js "$@"
			ec=$?
			break
		}
		# [ -x "$cmdsDir/$cmd.ts" ] && { $CLAMITY_ROOT/bin/run-node $cmdsDir/$cmd.ts "$@"; ec=$?; break; }
	done

	# export PATH="$pathBefore"

	[ $ec -eq -1 ] && _error "could not find $cmd. Try 'help' instead." && return 1
	return $ec
}

function _sub_command_is_external {
	local cmd="$1" subcmd="$2"
	local ext
	for ext in "" .sh .py .js; do
		[ -x "$CLAMITY_ROOT/cmds/$cmd.d/$subcmd$ext" ] && return 0
	done
	return 1
}

function _run_clamity_subcmd { # execute subcommand script ... cmd:$1, subcmd:$2, args:$@ (opt)
	_trace "_run_clamity_subcmd()> $*"
	local cmd="$1" subcmd="$2"
	shift 2
	_run_clamity_cmd "$CLAMITY_ROOT/cmds/$cmd.d" "$subcmd" "$@"
}

function _run { # run a command
	_is_dryrun && {
		echo DRYRUN: "$@"
		return 0
	}
	# supress stdout if running silent
	_is_quiet && {
		"$@" >/dev/null
		return $?
	}
	_vecho "$@"
	"$@"
}

function _vrun { # run a command verbosely (also ignore quiet)
	_is_dryrun && {
		echo DRYRUN: "$@"
		return 0
	}
	# supress stdout if running silent
	_echo "$@"
	"$@"
}

function _sudo { # execute command using sudo
	_run sudo "$@"
}

function _ask_to_run { # prompt y/n before executing a command
	{ _is_true $CLAMITY_yes || _is_true $_opt_yes; } && {
		_run "$@"
		return $?
	}
	echo "$@"
	echo "Execute (y/N)? "
	local ans=""
	read ans
	[ "$ans" = y -o "$ans" = yes ] || return 1
	"$@"
}

# function _run_py {	# Run a python script in the clamity environment
# 	_run $CLAMITY_ROOT/bin/py-run "$@"
# }

# data handling
# -------------
function _is_false { # evaluate value as boolean
	[ -z "$1" ] || echo "$1" | egrep -qie '^(0|no|n|false|f|off|null|none|undef|undefined)$'
}

function _is_true { # evaluate value as boolean
	! _is_false "$1"
}

function _ltrim { # remove leading blanks from string
	awk '{$1=$1};1'
}

function _is_debug { # true if debug mode
	_is_true $CLAMITY_debug
}

function _trace {
	_is_true $CLAMITY_trace && echo $* >&2
}

function _is_verbose { # true if verbose mode
	_is_true $CLAMITY_verbose
}

function _is_quiet { # true if quiet mode
	_is_true $CLAMITY_quiet
}

function _is_dryrun { # true if dryrun mode
	_is_true $CLAMITY_dryrun
}

function _float_lt { # true of $1 < $2
	[ $(echo "$1 < $2" | bc) -eq 1 ]
}

function _float_lte { # true of $1 <= $2
	[ $(echo "$1 <= $2" | bc) -eq 1 ]
}

function _float_gt { # true of $1 > $2
	[ $(echo "$1 > $2" | bc) -eq 1 ]
}

function _float_gte { # true of $1 >= $2
	[ $(echo "$1 >= $2" | bc) -eq 1 ]
}

function _opt_is_set { # true if option($1) is in option-string($2)
	local option="$1" opts="$2"
	echo ",$opts," | grep -q "$option"
}

function _evar_is_set { # eval env var; true if defined as non-null string
	[ -n "$(eval echo $$1)" ]
}

function _evar_is { # eval env var to stdout (eg: h=HOME && echo `_evar_is $h`)
	eval echo \$$1
}

function _set_evars_from_env_file_if_not_set { # set e vars from file ('VAR=VALUE'). def = -no-override
	local envFile="$1" opts="$2"
	for _e in $(grep = $envFile | grep -v '^#' | cut -f1 -d=); do
		! _evar_is_set "$_e" || _opt_is_set -override "$opts" || continue
		grep -q ^$_e= $envFile || continue
		eval $(
			echo -n "export "
			grep ^$_e= $envFile
		)
	done
}

function _prepend_to_path_if { # add all dirs to beginning of path if not in path
	local dir="" pathAdditions=""
	for dir in "$@"; do
		echo ":$PATH:" | grep -q $dir && continue # $dir already in path
		[ -z "$pathAdditions" ] && pathAdditions="$dir" || pathAdditions="$pathAdditions:$dir"
	done
	[ -n "$pathAdditions" ] && export PATH="$pathAdditions:$PATH"
}

# i/o & logging
# -------------
function _error { # report non-fatal errors
	echo "ERROR: ""$@" >&2
}

function _fatal { # report fatal errors
	echo "FATAL: ""$@" >&2
}

function _warn { # report warnings
	echo "$@" >&2
}

function _debug { # report in debug mode
	_is_debug && echo "DEBUG: ""$@" >&2
	return 0
}

function _echo { # default output handler (supressed if running silent)
	! _is_debug && _is_quiet && return 0
	echo "$@"
}

function _vecho { # output only in verbose or debug modes (and not silent)
	_is_quiet && return 0
	{ _is_debug || _is_verbose; } && echo "$@" && return 0
}

function _fecho { # always send to stdout (forced echo)
	echo "$@"
}

function _ask { # prompt($1) for a y/n question and default($2). succes if 'yes'
	local prompt="$1" def_ans="$2"
	local ans=""
	[ -z "$def_ans" ] && def_ans=n
	echo -n "$prompt"
	{ _is_true $CLAMITY_yes || _is_true $_opt_yes; } && echo "auto-yes" && return 0
	read ans
	[ -z "$ans" ] && ans=$def_ans
	echo ",$ans," | egrep -qie ",(y|yes)," || return 1
	return 0
}

# Utilities
# ---------
function _semver_ge { # semver (maj.min.patch) compare. True if $1 >= $2
	local maj1=$(echo $1 | cut -f1 -d.)
	local maj2=$(echo $2 | cut -f1 -d.)
	[ $maj1 -gt $maj2 ] && return 0
	[ $maj1 -lt $maj2 ] && return 1

	local min1=$(echo $1 | cut -f2 -d.)
	local min2=$(echo $2 | cut -f2 -d.)
	[ -z "$min1" -a -z "$min2" ] && return 0 # no minor, maj is equal
	[ -z "$min1" ] && min1=0
	[ -z "$min2" ] && min2=0
	[ $min1 -gt $min2 ] && return 0
	[ $min1 -lt $min2 ] && return 1

	local patch1=$(echo $1 | cut -f3 -d.)
	local patch2=$(echo $2 | cut -f3 -d.)
	[ -z "$patch1" -a -z "$patch2" ] && return 0 # no patch, maj/min are equal
	[ -z "$patch1" ] && patch1=0
	[ -z "$patch2" ] && patch2=0
	[ $patch1 -ge $patch2 ]
}

# OS detection and info
# ---------------------
function __os_info_via_sw_vers {
	# Supported:
	# 	macos        : >= 12
	which sw_vers >/dev/null 2>&1 || return
	local prodName=$(sw_vers --productName)
	local prodVersion=$(sw_vers --productVersion)
	case "$prodName" in
	macOS)
		_semver_ge $prodVersion 12 || { _error "macOS >= 12 required" && return; }
		echo "macos"
		;;
	*) _error "unable to identofy OS using sw_vers (productName = $prodName)" ;;
	esac
}

function __os_info_via_sysrel {
	local osName=""
	[ ! -f /etc/system-release ] && return
	cat /etc/system-release | grep -q "^Amazon Linux release 2 " && osName="al2"
	cat /etc/system-release | grep -q "^Amazon Linux release 2023 " && osName="al2023"
	case "$osName" in
	al2 | al2023) echo $osName ;; # all OS versions supported
	esac
}

function _os { # return supported OS (macos | al2 | al2023 | ubuntuXXX | ... )
	local os="$(__os_info_via_sw_vers)"
	[ -z "$os" ] && os="$(__os_info_via_sysrel)"
	[ -z "$os" ] && _error "Unable to identify OS" && return
	echo $os
}

function _os_ver { # report the OS version. some linux distro's use kernel ver.
	local os=$(_os)
	case "$os" in
	macos) sw_vers --productVersion ;;
	al2 | al2023) uname -r | cut -f1 -d- ;; # use kernel version
	*) _error "unsupported OS: $os" ;;
	esac
}

function _os_arch { # report host's architecture (arm64, x86_64, ...)
	case "$(_os)" in
	macos) uname -m ;; # eg. arm64
	al2) uname -m ;;   # eg. x86_64
	esac
}

# Poor man's JIT package management
# ---------------------------------
function _cmd_exists {
	while [ -n "$1" ]; do
		which $1 >/dev/null 2>&1 || return 1
		shift
	done
	return 0
}

function _cmds_needed { # verify command dependency
	_cmd_exists "$@" && return 0
	_run $CLAMITY_ROOT/bin/run-clamity os pkg installed --ask-to-install "$@"
}

# Git related
# -----------
function _git_repo_root { # find git repo root based on current directory
	local curDir="$(pwd)"
	while [ "$curDir" != "/" -a "$curDir" != "$HOME" ]; do
		_debug "checking $curDir for .git/"
		[ -d "$curDir/.git" ] && echo "$curDir" && return
		curDir="$(dirname $curDir)"
	done
}
