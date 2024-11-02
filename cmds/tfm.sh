# THIS FILE MUST WORK FOR ALL SUPPORTED SHELLS: zsh, bash

# desc: provides exteneded capabilities to terraform

source $CLAMITY_ROOT/lib/_.sh || return 1

cmd=tfm
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
	This facility provides extended features for managing terraform through
	the CI/CD lifecycle, hopefully making repetative tasks and configurations
	simpler to manage.

	Use the 'clamity tfm' command as if it were an alias for the 'terraform'
	command. It intercepts custom sub-commands (extensions), passing the rest
	through to 'terraform' directly so 'clamity tfm state list' is identical
	to 'terraform state list'. Some terraform sub-commands are intercepted and
	the command line passed to 'terraform' modified to accomodate global settings
	for things like state management. For example, 'tfm init' will add the
	'-backend-config=xxx' arg for the appropriate config before passing through
	to 'terraform init'.

	To make these extensions useful, you must agree to manage your terraform root
	modules in a particular way.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity $cmd { mystate | shared | vars | smart-import } [options]
	clamity $cmd { terraform-cmd-and-args }
"

# Don't include common options here
__CommandOptions="
	--none-yet
		Need some

MORE

	The 'shared' subcommand syncs the code residing in the lib/ directory
	across all participating root modules. You can opt-in on a file-by-file
	basis simply by keeping a copy of the file with the same name within
	the root module directory. This	mechanism solves the problem whereby
	terraform code, at the outer-most level, requires specific attributes
	and properties for the deployment, such as provider definitions.
"

# For commands that have their own special env vars, inlude this section in
# the man page.
__EnvironmentVariables="
	TFM_REPO_ROOT
		Full path to and including this repo's root.

	TFM_ROOT_MODS
		Relative path from TFM_REPO_ROOT to the top of the root module
		tree (default = 'roots').

	TFM_TERRAFORM_CMD_ARGS
		Additional arguments to be passed to the terraform command. This
		is usually set in a root's ./.tfm.sh file.
"

# Optional pre-formatted section inserted towards end before Examples
__CustomSections="BOOLEAN EVALUATION

	Boolean truthiness defines 'false' as an empty string or a case insensitive
	match to anything matching to 'n|no|0|null|none|undefined|undef|f|false'.
	Convention for setting booleans is to set them to a value of 1.

	The 'lib/_.sh:_is_false()' shell function is the source of truth for
	truthiness.

SUPPORTED SHELLS

	bash, zsh

FILES

	TFM_REPO_ROOT/.tfm.local.sh
		Local variable declarations (not to be committed) sourced in when
		running all 'tfm' commands. This is git ignored.

	./.tfm.sh
		Root-specific variable declarations. To be committed.

	TFM_REPO_ROOT/TFM_ROOT_MODS/<top-dir>/.tfm.sh
		<top-dir> (eg. dev or prod)-specific variables such as account,
		user list, etc.. used to support imports and other conveniences.
		This file needs to be kept in sync with the values in the
		<top-dir>/shared/common-variables.tf file.
		Optional. Should be committed.
"


# Showing examples for comman tasks proves to be very useful in man pages.
__Examples="
	List your root modules

		A 'terraform.tf' file in a directory under \$TFM_REPO_ROOT/roots/
		designates a module root.

		clamity tfm shared

	Initializing Pre-canned State Configurations

		To facilitate custom strategies for managing backends and states,
		a '.tfm.sh' file, in the root's directory, may be used to setup the
		apporpriate parameters. It's a good habbit to initialize your state
		using this tool. Add '-dryrun' if you want to see what it would do.

		clamity tfm init
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

customCmdDesc=""
# customCmdDesc="
# \n\tlist - list config variables
# \n\tset - set a config variable
# \n\tshow - report env and default settings
# \n\tunset - unset config variable
# "
# ---------------------------------------------------------------------------



function _tfm_is_opt {
	local opt="$1"
	shift
	[ -z "$1" ] && local optString="$_TFM_OPTIONS" || local optString="$*"
	echo "$optString" | grep -q \\"$opt"
}

function _tfm_set_options {
	# accomodate ',' delimited option list inside one arg
	local o
	for o in `echo "$1" | tr , ' '`; do
		_TFM_OPTIONS="$_TFM_OPTIONS${o},"
	done
}

function _parse_opts {
	local o
	for o in "$@"; do
		# echo "Parsing $o"
		echo "$o"|grep -q "^-" && _tfm_set_options "$o"
	done
}

function _ask_first {
	local ans
	echo "$@"
	echo -n "Run (y/N)? "
	read ans
	[ \( "$ans" = y -o "$ans" = yes \) ] && return 0
	return 1
}

function _tfm_run {
	# expect the first arg to contain options like dryrun
	_tfm_is_opt -dryrun "$@" && { local dryrun="DRYRUN" && shift; } || local dryrun="CMD"
	echo -e "\n$dryrun [`_tfm_root_mod_relative_path`] >" "$@"
	echo
	[ "$dryrun" = "DRYRUN" ] && return 0
	"$@"
}

function _tfm_run_for_region {
	[ -n "$TF_VAR_region" ] && local region="$TF_VAR_region" || local region="undefined region"
	echo -e "\nCMD [`_tfm_root_mod_relative_path` : $region] >" "$@"
	echo
	"$@"
}

# eg. dev/shared
function _tfm_root_mod_relative_path {
	[ -z "$1" ] && local dir="`pwd`" || local dir="$1"
	echo $dir | sed "s|^$TFM_REPO_ROOT/$TFM_ROOT_MODS/||"
}

# print the top level directory under $TFM_ROOT_MODS/ (eg. dev | prod)
function _tfm_top_level_directory {
	echo `_tfm_root_mod_relative_path` | cut -f1 -d/
}

[ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" "$cmd"; return 1; }

_cmd_exists terraform || _warn "terraform command not found"
_cmds_needed terraform || { _error "unable to run terraform"; return 1; }

TFM_REPO_ROOT="`_git_repo_root`"
tfmRepo=1
[ -f "$TFM_REPO_ROOT/.clamity/config/settings.sh" ] && grep -q '^terraform_repo=1$' "$TFM_REPO_ROOT/.clamity/config/settings.sh" || tfmRepo=0
[ -z "$TFM_REPO_ROOT"  -o  $tfmRepo -eq 0 ] && echo "this does not look like a clamity compatible terraform repo" && return 1

# [ "$subcmd" = cd -a "$1" = roots ] && { _tfm_run cd $TFM_REPO_ROOT/$TFM_ROOT_MODS; return $?; }
# [ "$subcmd" = cd -a "$1" = modules ] && { _tfm_run cd $TFM_REPO_ROOT/modules; return $?; }

# intercept and embelish terraform these sub-commands
# echo ",init," | grep -q $subcmd && { "$CLAMITY_ROOT/cmds/tfm.d/exec" "$@"; return $?; }

# [ -z "`_tfm_top_level_directory`" ] && unset TFM_TOP_LEVEL_DIR || export TFM_TOP_LEVEL_DIR="$TFM_REPO_ROOT/$TFM_ROOT_MODS/`_tfm_top_level_directory`"

_TFM_OPTIONS=""  # global, not exported
# _parse_opts "$@" # sets _TFM_OPTIONS; does not change command line

[ -x "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" ] && { "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" "$_TFM_OPTIONS" "$@"; return $?; }

_echo "passing command thru to terraform..."
_run terraform "$subcmd" "$@"

return $?

# # This repo is where?
# [ -z "$TFM_REPO_ROOT" ] && [ -n "$BASH_SOURCE" ] && export TFM_REPO_ROOT="`dirname $BASH_SOURCE`"
# [ -z "$TFM_REPO_ROOT" ] && [ -n "$ZSH_VERSION" ] && setopt function_argzero && export TFM_REPO_ROOT="`dirname $0`"
# [[ "$TFM_REPO_ROOT" == .* ]] && export TFM_REPO_ROOT=`cd $TFM_REPO_ROOT && pwd`
# [ -z "$TFM_REPO_ROOT" ] && echo "unsupported shell. maybe try setting TFM_REPO_ROOT ?" && return 1
# [ ! -f "$TFM_REPO_ROOT/tfm-helper.sh" ] && echo "Is TFM_REPO_ROOT=$TFM_REPO_ROOT correct?  tfm-helper.sh isn't where it should be." && return 1

# # Where root terraform modules are stored
# [ -z "$TFM_ROOT_MODS" ] && export TFM_ROOT_MODS=roots

# _tfm_is_opt -load-tfm-data "$*" && [ -f "$TFM_REPO_ROOT/.tfm.local.sh" ] && { source "$TFM_REPO_ROOT/.tfm.local.sh" || return 1; }
# _tfm_is_opt -load-tfm-data "$*" && [ -f "$TFM_REPO_ROOT/$TFM_ROOT_MODS/`_tfm_top_level_directory`/.tfm.sh" ] && { source "$TFM_REPO_ROOT/$TFM_ROOT_MODS/`_tfm_top_level_directory`/.tfm.sh" || return 1; }
# _tfm_is_opt -load-tfm-data "$*" && [ -f .tfm.sh ] && echo "sourcing ./.tfm.sh" && { source .tfm.sh || return 1; }
# _tfm_is_opt -silent "$*" || echo "terraform wrapper func loaded. Type 'tfm'"

# return 0
