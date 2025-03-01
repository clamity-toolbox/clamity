# THIS FILE MUST WORK FOR ALL SUPPORTED SHELLS: zsh, bash

# desc: provides exteneded capabilities to terraform

source $CLAMITY_ROOT/lib/_.sh || return 1
source $CLAMITY_ROOT/cmds/tfm.d/shared-funcs.sh || return 1

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
	to 'terraform state list'. Some terraform commands are intercepted and
	the command line passed to 'terraform' modified to accomodate global settings
	for things like state management. For example, 'clamity tfm init' will add the
	'-backend-config=xxx' arg for the appropriate config before passing through
	to 'terraform init'.

	To make these extensions useful, you must agree to manage your terraform root
	modules in a particular way.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity $cmd { vars | smart-import | record-results } [-reconfigure] [tfm-options]
	clamity $cmd apply [--no-commit] [tfm-options]
	clamity $cmd common { report | update [mine] | new-root <state-group> <module-name> }
	clamity $cmd settings { show | [un]set aws-profile [profile] }
	clamity $cmd cicd complete [-reconfigure]
	clamity $cmd debug [ on | off ]  # (un)sets the 'TF_VAR_debug' env var
	clamity $cmd { terraform-cmd-and-args }
"

# Don't include common options here
__CommandOptions="
	-reconfigure
		Force -reconfigure with terraform init.

	--no-commit
		When running 'apply', don't commit and push changes to the repo.

SUB-COMMANDS

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
		You can set an aws_profile by state_group to use locally which when running
		terraform commands. This is if you don't want to manage it with the
		AWS_PROFILE env variable.

	smart-import
		System for reading resource data and importing it into state. This requires
		customizations specific to each terraform root module and is typically
		not used unless terraforming an existing installation.

	state-report
		List resource deployments (state list) by state group.

	vars
		Display variables associated with terraform (TF_*, TFM_*, CLAMITY_TFM_*).
"

# For commands that have their own special env vars, inlude this section in
# the man page.
__EnvironmentVariables="
	TFM_REPO_ROOT
		Full path to and including this repo's root.

	TFM_POST_COMMIT
		Controls execution of post-apply commit and push. Valid values are
		'commit-only' (won't push), 'none' (won't commit or push), or null
		(default) which will commit and push.
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
    TFM_REPO_ROOT/.clamity/config/settings.sh
		Configuration settings for the repo. This file should be committed.

    TFM_REPO_ROOT/.clamity/config/module-sequence.sh
		Script to provides the sequence in which root modules should be applied
		allowing for intra-module dependencies. This should be executed from
		within TFM_REPO_ROOT. This file should be committed.

    TFM_REPO_ROOT/.clamity/config/state-resource-prefix.sh
		Provides the resource prefix and region required for identifying backend
		state resources when creating new root modules. This should be executed
		from within TFM_REPO_ROOT. This file should be committed.

	TFM_REPO_ROOT/.clamity/local/settings.sh
		Configuration settings for the repo which should _not_ be committed.
		Examples include your desired AWS_PROFILE values by state group.
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
\n\tstate-report - summarize resource deployments by state group
"
# ---------------------------------------------------------------------------

function _set_unset {
	local action="$1" where="$2" prop="$3" val="$4"
	[ -f $TFM_REPO_ROOT/.clamity/$where/settings.sh ] && cat $TFM_REPO_ROOT/.clamity/$where/settings.sh | grep -v "^$prop=" >/tmp/$where-settings.sh.$$
	if [ "$action" = unset ]; then
		[ -f /tmp/$where-settings.sh.$$ ] && mv /tmp/$where-settings.sh.$$ $TFM_REPO_ROOT/.clamity/$where/settings.sh && return 0
		return 1
	elif [ "$action" = set -a -n "$val" ]; then
		echo "$prop=$val" >>/tmp/$where-settings.sh.$$ && mv /tmp/$where-settings.sh.$$ $TFM_REPO_ROOT/.clamity/$where/settings.sh && return 0
		return 1
	else
		_warn "$usage" && return 1
	fi
}

function _tfm_set_props {
	local usage="usage: clamity tfm settings { show | [un]set { aws_profile <state-group> [<profile>] | terraform_repo | record_state | record_output | audit_applies } }"
	local _tfm_local_vars="aws_profile"
	local _tfm_config_vars="terraform_repo|record_state|record_output|audit_applies"
	[ -z "$1" ] && _warn "$usage" && return 1

	local sub_cmd="$1" prop="$2" state_group="$3" prof="$4"
	[ "$prop" = "aws_profile" ] && local sg=":$state_group" || local sg=""
	[ "$prop" != "aws_profile" ] && prof=1

	case "$sub_cmd" in
	show) {
		cat $TFM_REPO_ROOT/.clamity/config/settings.sh $TFM_REPO_ROOT/.clamity/local/settings.sh 2>/dev/null
		return 0
	} ;;
	set | unset) {
		[ "$prop" = "aws_profile" ] && [ \( "$sub_cmd" = "set" -a -z "$prof" \) -o \( "$sub_cmd" = "unset" -a -n "$stage_group" \) ] && _warn "$usage" && return 1
		[ "$prop" != "aws_profile" ] && [ -n "$state_group" ] && _warn "$usage" && return 1
		echo $prop | egrep -qe "^($_tfm_local_vars)$" && {
			_set_unset "$sub_cmd" "local" "$prop$sg" "$prof" && _tfm_set_props show
			return $?
		}
		echo $prop | egrep -qe "^($_tfm_config_vars)$" && {
			_set_unset "$1" "config" "$prop$sg" "$prof" && _tfm_set_props show
			return $?
		}
	} ;;
	esac
	_vecho "option must be one of: $_tfm_local_vars|$_tfm_config_vars"
	return 1
}

function _set_aws_profile {
	local _awsprof=""
	__aws_prof_exists_before="$AWS_PROFILE" # THIS IS A GLOBAL!!!

	local state_group=$(pwd | rev | cut -f1-2 -d/ | rev | cut -f1 -d/)
	[ -f $TFM_REPO_ROOT/.clamity/local/settings.sh ] && _awsprof=$(grep "^aws_profile:$state_group=" $TFM_REPO_ROOT/.clamity/local/settings.sh | cut -f2 -d=)
	[ -z "$AWS_PROFILE" -a -z "$_awsprof" ] && return 0                      # profile is not my problem
	[ -n "$AWS_PROFILE" -a -z "$_awsprof" ] && return 0                      # profile set externally
	[ "$AWS_PROFILE" = "$_awsprof" ] && return 0                             # no conflict
	[ -z "$AWS_PROFILE" ] && _run export AWS_PROFILE="$_awsprof" && return 0 # set profile for the run
	# _warn "AWS_PROFILE($AWS_PROFILE) conflicts with local setting of $_awsprof" && return 1
	_run export AWS_PROFILE="$_awsprof" # overwrite profile for the run
	return 0
}

function _reset_aws_profile {
	[ -n "$__aws_prof_exists_before" ] && _vecho "restoring AWS_PROFILE=$__aws_prof_exists_before" && export AWS_PROFILE="$__aws_prof_exists_before" || unset AWS_PROFILE
	return 0
}

function _tfm_state_report {
	local stategroup="$1" dir
	[ -z "$stategroup" ] && _warn "usage: clamity tfm state-report <stage-group>" && return 1
	local state_dir="$TFM_REPO_ROOT/state-groups/$stategroup"
	for dir in $(ls $state_dir); do
		[ ! -f "$state_dir/$dir/STATE.md" ] && continue
		echo "\n--------------------------------------"
		echo "$stategroup/$dir"
		echo "--------------------------------------"
		cat $state_dir/$dir/STATE.md
	done
}

function _tfm_check_repo_before_apply {
	[ $(git status -s | awk '{print $1}' | grep '\?' | wc -l) -gt 0 ] && {
		_warn "untracked files in repo, commit, add or remove them before applying"
		git status -s | grep '\?'
		return 1
	}
	return 0
}

function _tfm_commit_and_push {
	[ $(git diff --name-only | wc -l) -eq 0 ] && return 0
	_echo "--------------------------------------------------------"
	_echo "Committing updated output and audit files post-apply"
	_echo "--------------------------------------------------------"
	_run git diff --name-only
	_echo
	[ "$TFM_POST_COMMIT" = "none" ] && return 0
	local c_msg="and push origin "
	[ "$TFM_POST_COMMIT" = "commit-only" ] && c_msg=""
	_ask "Commit $c_msg(Y/n)? " y && {
		local msg defaultMsg="audit, status and output update"
		echo -n "Commit message -  post-apply: "
		read msg
		[ -z "$msg" ] && msg="$defaultMsg"
		_run git commit -am "post-apply: $msg" || return 1
		[ -z "$c_msg" ] && return 0
		_run git push origin || return 1
	}
	return 0
}

function _tfm_set_debug {
	case "$1" in
	on) {
		export TF_VAR_debug=1
		_echo "tfm debug on"
	} ;;
	off) {
		unset TF_VAR_debug
		_echo "tfm debug off"
	} ;;
	*) {
		[ -n "$TF_VAR_debug" ] && _echo "tfm debug on" || _echo "tfm debug off"
		_echo "usage: clamity tfm debug { on | off }"
	} ;;
	esac
	return 0
}

cmd=tfm
_usage "$customCmdDesc" "$cmd" "$1" -command || return 1
subcmd="$1" && shift

# Establish this is a clamity compatible terraform repo
TFM_REPO_ROOT="$(_git_repo_root)"
tfmRepo=1
[ -f "$TFM_REPO_ROOT/.clamity/config/settings.sh" ] && grep -q '^terraform_repo=1$' "$TFM_REPO_ROOT/.clamity/config/settings.sh" || tfmRepo=0
[ -z "$TFM_REPO_ROOT" -o $tfmRepo -eq 0 ] && echo "this does not look like a clamity compatible terraform repo" && return 1

_cmds_needed terraform script jq yq || {
	_error "one or more commands not found: terraform, script, jq, yq"
	return 1
}

_set_aws_profile || return 1

if [ -x "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" ]; then
	export TFM_REPO_ROOT="$TFM_REPO_ROOT"
	if [ "$(_tfm_prop audit_applies)" -a $subcmd = apply ]; then
		_tfm_check_repo_before_apply || return 1

		local _opt_commit=1 argList="" var
		echo "$@" | grep -q '\--no-commit' && _opt_commit=0

		for var in "$@"; do [ "$var" != "--no-commit" ] && argList="$argList $var"; done

		echo "AUDIT APPLY: $CLAMITY_ROOT/cmds/tfm.d/$subcmd" $argList >AUDIT.log

		_run aws sts get-caller-identity || return 1

		script -a AUDIT.log "$CLAMITY_ROOT/cmds/tfm.d/$subcmd" $argList
		rc=$?

		echo "Script command returned $rc" | tee -a AUDIT.log
		[ $rc -ne 0 ] && _error "terraform apply failed" && return 1
		_tfm_commit_and_push || rc=1
	else
		"$CLAMITY_ROOT/cmds/tfm.d/$subcmd" "$@"
		rc=$?
	fi
	unset TFM_REPO_ROOT
	_reset_aws_profile
	return $rc
fi

# _set_standard_options "$@"
# echo "$@" | grep -q '\--abc' && _opt_abc=1 || _opt_abc=0

rc=0
case "$subcmd" in
record-results)
	_tfm_record_results || rc=1
	;;
settings)
	_tfm_set_props "$@" || rc=1
	;;
state-report)
	_tfm_state_report "$@" || rc=1
	;;
debug)
	_tfm_set_debug "$@" || rc=1
	;;
*)
	_vecho "passing command thru to terraform..." && _run terraform "$subcmd" "$@" || rc=1
	;;
esac

# _clear_standard_options _opt_abc
_reset_aws_profile
[ $rc -ne 0 ] && _warn "command returned status 1"
return $rc
