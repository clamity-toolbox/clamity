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
	clamity $cmd { mystate | apply | vars | smart-import } [options]
	clamity $cmd common { report | update | new-root <state-group> <module-name> }
	clamity $cmd { terraform-cmd-and-args }
"

# Don't include common options here
__CommandOptions="
	--none-yet
		Need some

MORE

	The 'common' subcommand syncs the code residing in the lib/ directory
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

customCmdDesc=""
# customCmdDesc="
# \n\tlist - list config variables
# \n\tset - set a config variable
# \n\tshow - report env and default settings
# \n\tunset - unset config variable
# "
# ---------------------------------------------------------------------------



[ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" "$cmd"; return 1; }

_cmd_exists terraform || _warn "terraform command not found"
_cmds_needed terraform || { _error "unable to run terraform"; return 1; }

# Establish this is a clamity compatible terraform repo
TFM_REPO_ROOT="`_git_repo_root`"
tfmRepo=1
[ -f "$TFM_REPO_ROOT/.clamity/config/settings.sh" ] && grep -q '^terraform_repo=1$' "$TFM_REPO_ROOT/.clamity/config/settings.sh" || tfmRepo=0
[ -z "$TFM_REPO_ROOT"  -o  $tfmRepo -eq 0 ] && echo "this does not look like a clamity compatible terraform repo" && return 1

if [ -x "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" ]; then
	export TFM_REPO_ROOT="$TFM_REPO_ROOT"
	"$CLAMITY_ROOT/cmds/tfm.d/$subcmd" "$@"
	rc=$?
	unset TFM_REPO_ROOT
	return $rc
fi

_vecho "passing command thru to terraform..."
_run terraform "$subcmd" "$@"
return $?
