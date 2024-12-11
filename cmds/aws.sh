# desc: provides exteneded capabilities to the aws command line utility

# THIS FILE IS SOURCED INTO, AND THEREFORE MUTATES, THE CURRENT SHELL
# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

cmd=aws
subcmd="$1"
[ -n "$subcmd" ] && shift

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
	[ -z "$CLAMITY_aws_sso_session$1" ] && echo "Default AWS session not set. Specify one or set a default with 'clamity config set default aws_sso_session <session>'" && return 1
	[ -n "$1" ] && local session="$1" || local session="$CLAMITY_aws_sso_session"
	_run aws sso login --sso-session $session
}

# [ -z "$subcmd" ] && {
# 	_brief_usage "$customCmdDesc" "$cmd"
# 	# _usage "$customCmdDesc" "$cmd"
# 	return 1
# }
_usage "$customCmdDesc" "$cmd" "$subcmd" || return 1
# [ "$subcmd" = help ] && {
# 	_man_page "$customCmdDesc" "$cmd"
# 	return 1
# }

_cmd_exists aws || _warn "aws command not found"
_cmds_needed aws || {
	_error "unable to run aws CLI"
	return 1
}

[ -x "$CLAMITY_ROOT/cmds/aws.d/$subcmd.py" ] && { "$CLAMITY_ROOT/bin/clam-py" "$CLAMITY_ROOT/cmds/aws.d/$subcmd.py" "$@"; return $?; }
[ -x "$CLAMITY_ROOT/cmds/aws.d/$subcmd" ] && { "$CLAMITY_ROOT/cmds/aws.d/$subcmd" "$@"; return $?; }

case "$subcmd" in
login)
	_caws_login "$@"
	return $?
	;;
whoami)
	aws sts get-caller-identity
	return $?
	;;
profile)
	clamity env aws-profile "$@"
	return $?
	;;
esac

# aws sts assume-role --role-arn "arn:aws:iam::12345678:role/OrganizationAccountAccessRole" --role-session-name aws
_vecho "passing command thru to the aws cli..."
_run aws "$subcmd" "$@"
