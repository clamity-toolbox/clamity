# THIS FILE MUST WORK FOR ALL SUPPORTED SHELLS: zsh, bash

# desc: provides exteneded capabilities to the aws command line utility

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
	clamity $cmd assume-role ... [options]
	clamity $cmd { aws-cmd-and-args }
"


[ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" "$cmd"; return 1; }

_cmd_exists aws || _warn "aws command not found"
_cmds_needed aws || { _error "unable to run aws CLI"; return 1; }



# aws sts assume-role --role-arn "arn:aws:iam::12345678:role/OrganizationAccountAccessRole" --role-session-name aws	
_vecho "passing command thru to the aws cli..."
_run aws "$subcmd" "$@"
