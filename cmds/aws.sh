# desc: provides exteneded capabilities to the aws command line utility

# THIS FILE IS SOURCED INTO, AND THEREFORE MUTATES, THE CURRENT SHELL
# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

# More descriptive overview of the command. Paragraph(s) allowed. This is
# included on a man page. (REQUIRED)
__Abstract="
	This wraps the 'aws' cli to provide extended capabilities.
"

__Usage="
	clamity $cmd { whoami | assume-role | profile [<profile>] | login [sso-session] } [options]
	clamity $cmd { aws-cmd-and-args }
"

__CommandOptions=""

customCmdDesc="
\n\twhoami - aws sts get-caller-identity
\n\tprofile - alias for 'clamity env aws-profile'
\n\tlogin - login to an aws sso session
"

function _caws_login {
	[ -z "$CLAMITY_aws_default_sso_session$1" ] && echo "Default AWS session not set. Specify one or set a default with 'clamity config set default aws_default_sso_session <session-name>'" && return 1
	[ -n "$1" ] && local session="$1" || local session="$CLAMITY_aws_default_sso_session"
	_run aws sso login --sso-session $session
}

# aws sts assume-role --role-arn "arn:aws:iam::12345678:role/OrganizationAccountAccessRole" --role-session-name aws

cmd=aws
_usage "$customCmdDesc" "$cmd" "$1" -command || return 1
subcmd="$1" && shift

_cmds_needed aws || { _error "unable to run aws CLI" && return 1; }

_sub_command_is_external $cmd $subcmd && {
	_run_clamity_subcmd $cmd $subcmd "$@"
	return $?
}

_set_standard_options "$@"
# echo "$@" | grep -q '\--abc' && _opt_abc=1 || _opt_abc=0

rc=0
case "$subcmd" in
login)
	_caws_login "$@" || rc=1
	;;
whoami)
	echo "AWS_PROFILE=$AWS_PROFILE"
	aws sts get-caller-identity || rc=1
	;;
profile)
	clamity env aws-profile "$@" || rc=1
	;;
*)
	_vecho "passing command thru to the aws cli..."
	_run aws "$subcmd" "$@" || rc=1
	;;
esac

# _clear_standard_options _opt_abc
_clear_standard_options
return $rc
