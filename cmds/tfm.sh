# THIS FILE MUST WORK FOR ALL SUPPORTED SHELLS: zsh, bash

# desc: provides exteneded capabilities to terraform

source $CLAMITY_ROOT/lib/_.sh || return 1
source $CLAMITY_ROOT/cmds/tfm.d/shared-funcs.sh || return 1

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
	clamity $cmd { mystate | apply | vars | smart-import | record-results } [options]
	clamity $cmd common { report | update | new-root <state-group> <module-name> }
	clamity $cmd settings { show | [un]set aws-profile [profile] }
	clamity $cmd cicd complete
	clamity $cmd { terraform-cmd-and-args }
"

# Don't include common options here
__CommandOptions="
	--none-yet
		Need some

MORE

	cicd {complete}
		An interface into various CI/CD pipeline processes. 'complete' will
		execute a 'terraform plan' (and 'init' if need be) on all root modules
		in sequence.

	common
		The 'common' subcommand syncs the code residing in the common/ directory
		across all participating root modules. You can opt-in on a file-by-file
		basis simply by keeping a copy of the file with the same name within
		the root module directory. This	mechanism solves the problem whereby
		terraform code, at the outer-most level, requires specific attributes
		and properties for the deployment, such as provider definitions which
		often result in duplicated code.

	record-results
		Saves state listing to STATE.md and output to OUTPUT.json.

	settings
		You can set an aws_profile locally which will be used when running
		terraform commands. This is if you don't want to manage it with
		the AWS_PROFILE env variable.
"

# For commands that have their own special env vars, inlude this section in
# the man page.
__EnvironmentVariables="
	TFM_REPO_ROOT
		Full path to and including this repo's root.

	TFM_ROOT_MODS
		Relative path from TFM_REPO_ROOT to the top of the root module
		tree (default = 'roots').
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
		<top-dir>/common/common-variables.tf file.
		Optional. Should be committed.
"


# Showing examples for comman tasks proves to be very useful in man pages.
__Examples="
	List your root modules

		A 'terraform.tf' file in a directory under \$TFM_REPO_ROOT/roots/
		designates a module root.

		clamity tfm common

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

# customCmdDesc=""
customCmdDesc="
\n\trecord-results - saves state to STATE.md and output to OUTPUT.json
\n\tsettings - set properties for the repo
"
# ---------------------------------------------------------------------------


function set_props {
	local usage="usage: clamity tfm settings { show | [un]set aws-profile [profile] }"
	[ -z "$1" ] && _warn "$usage" && return 1
	[ "$1" = show ] && cat $TFM_REPO_ROOT/.clamity/config/settings.sh && cat $TFM_REPO_ROOT/.clamity/local/settings.sh 2>/dev/null && return 0
	[ "$2" != "aws-profile" ] && _warn "$usage" && return 1
	[ -f $TFM_REPO_ROOT/.clamity/local/settings.sh ] && cat $TFM_REPO_ROOT/.clamity/local/settings.sh | grep -v ^aws_profile= >/tmp/local-settings.sh.$$
	if [ "$1" = unset -a "$2" = "aws-profile" ]; then
		[ -f /tmp/local-settings.sh.$$ ] && { mv /tmp/local-settings.sh.$$ $TFM_REPO_ROOT/.clamity/local/settings.sh || return 1; }
		set_props show
		return 0
	fi
	[ "$1" = set -a "$2" = "aws-profile" -a -n "$3" ] && { echo "aws_profile=$3" >>/tmp/local-settings.sh && mv /tmp/local-settings.sh.$$ $TFM_REPO_ROOT/.clamity/local/settings.sh && set_props show; return $?; }
	_warn "$usage"
	return 1
}

function set_aws_profile {
	local _awsprof=""
	[ -f $TFM_REPO_ROOT/.clamity/local/settings.sh ] && _awsprof=`grep '^aws_profile=' $TFM_REPO_ROOT/.clamity/local/settings.sh|cut -f2 -d=`
	[ -z "$AWS_PROFILE"  -a  -z "$_awsprof" ] && return 0 # profile is not my problem
	[ -n "$AWS_PROFILE" -a -z "$_awsprof" ] && return 0   # profile set externally
	[ "$AWS_PROFILE" = "$_awsprof" ] && return 0          # no conflict
	[ -z "$AWS_PROFILE" ] && _run export AWS_PROFILE="$_awsprof" && return 0  # set profile for the run
	_warn "AWS_PROFILE($AWS_PROFILE) conflicts with local setting of $_awsprof"
	return 1  # conflict
}

[ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" "$cmd"; return 1; }

_cmd_exists terraform || _warn "terraform command not found"
_cmds_needed terraform || { _error "unable to run terraform"; return 1; }

# Establish this is a clamity compatible terraform repo
TFM_REPO_ROOT="`_git_repo_root`"
tfmRepo=1
[ -f "$TFM_REPO_ROOT/.clamity/config/settings.sh" ] && grep -q '^terraform_repo=1$' "$TFM_REPO_ROOT/.clamity/config/settings.sh" || tfmRepo=0
[ -z "$TFM_REPO_ROOT"  -o  $tfmRepo -eq 0 ] && echo "this does not look like a clamity compatible terraform repo" && return 1

__aws_prof_before="$AWS_PROFILE"
set_aws_profile || return 1

if [ -x "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" ]; then
	export TFM_REPO_ROOT="$TFM_REPO_ROOT"
	"$CLAMITY_ROOT/cmds/tfm.d/$subcmd" "$@"
	rc=$?
	unset TFM_REPO_ROOT
	[ -z "$__aws_prof_before" ] && unset AWS_PROFILE
	return $rc
fi

case "$subcmd" in
	record-results) { tfm_record_results; return $?; };;
	settings) { set_props "$@"; return $?; };;
esac

_vecho "passing command thru to terraform..."
_run terraform "$subcmd" "$@"
rc=$?

[ -z "$__aws_prof_before" ] && unset AWS_PROFILE
return $rc
