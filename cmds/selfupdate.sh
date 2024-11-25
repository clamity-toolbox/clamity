#!/usr/bin/env bash

# desc: update clamity and your OS packages


# THIS FILE IS SOURCED INTO AND THEREFORE MUTATES THE CURRENT SHELL

# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

cmd=selfupdate
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
	Use selfupdate to update the clamity software, package managers and
	packages and all matter of software under clamity's umbrella.
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity $cmd [help] [options]
"

# Don't include common options here
__CommandOptions=""
# __CommandOptions="
# 	--opt-a
# 		No additional arg. boolean. Use _is_true() and _is_false() funcs
# 		to evaluate.
#
# 	--opt-name <name>
# 		the name of the thing you specifed using --opt-name.
# "

# For commands that have their own special env vars, inlude this section in
# the man page.
__EnvironmentVariables=""
# __EnvironmentVariables="
# 	CLAMITY_SHCMD_FEATURE
# 		This means something to my shell script and is managed by me and
# 		not the config settings module. Possible values include a, true
# 		or a bag of potato chips.
# "

# Optional pre-formatted section inserted towards end before Examples
__CustomSections="SUPPORTED SHELLS

	bash, zsh
"


# Showing examples for comman tasks proves to be very useful in man pages.
__Examples="
	Update clamity
		clamity selfupdate
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
# ---------------------------------------------------------------------------


function update_clamity_git_installation {
	_echo "git repo installation detected"
	pushd "$CLAMITY_ROOT" || return 1
	[ `git status -s | wc -l` -ne 0 ] && { _fatal "git status does not show a clean repo. update aborted." && popd; return 1; }
	local rc=0
	_run git pull origin || rc=1
	popd || rc=1
	_echo "software updated. reloading"
	source "$CLAMITY_HOME/loader.sh"
}

function update_clamity_tarball_installaton {
	_echo "tarball installation assumed (git not detected)."
	_echo "not implemented yet"
	return 1
	pushd "$CLAMITY_ROOT/.." || return 1
	local clamDirName=$(`basename "$CLAMITY_ROOT"`)
	_run mv "$CLAMITY_ROOT" "$CLAMITY_ROOT.undo" || { _fatal "can't create undo dir" && popd; return 1; }
	local rc=0
	echo "teach me how to do this" || { rc=1 && _fatal "update failed. undoing..." && mv "$CLAMITY_ROOT" "CLAMITY_ROOT.failed" && mv "$CLAMITY_ROOT.undo" "$CLAMITY_ROOT"; }
	popd
	return $rc
}

function backup_clamity {
	[ ! -d "$CLAMITY_HOME/backups" ] && { mkdir "$CLAMITY_HOME/backups" || return 1; }
	pushd "$CLAMITY_ROOT/.." || return 1
	local rc=0
	local now=`date +%Y%m%d-%H%M%S`
	local tarball="clamity-software.$now.tgz"
	local clamDirName="$(basename "$CLAMITY_ROOT")"
	_run tar czpf "$CLAMITY_HOME/backups/$tarball" "$clamDirName" || rc=1
	popd || rc=1

	[ ! -d "$HOME/.clamity" ] && return $rc
	pushd "$CLAMITY_HOME" || return 1
	tarball="clamity-data.$now.tgz"
	_run tar --exclude backups/ -czpf backups/$tarball . || rc=1
	popd || rc=1
	[ $rc -eq 0 ] && ls -1 $CLAMITY_HOME/backups/*.$now.*
	[ $rc -eq 0 ] && _run find $CLAMITY_HOME/backups -type f -mtime +30 -delete

	return $rc
}

function update_git_installation {
	cd "$CLAMITY_ROOT" || return 1
	[ `git status -sb | wc -l` -ne 1 ] && _warn "clamity repo does not look clean" && return 1
	git pull origin
}

function _c_update_clamity {
	_ask "Backup clamity before we begin (Y/n)? " y && { backup_clamity || return 1; }
	[ -d "$CLAMITY_ROOT/.git" ] && { update_git_installation || return 1; } || { update_tarball_installaton || return 1; }
	_echo "Updating python packages in clamity venv" && _run $CLAMITY_ROOT/bin/clam-py update || return 1;
	[ -n "$CLAMITY_os_preferred_pkg_mgr" ] && { _ask "Update OS package manager '$CLAMITY_os_preferred_pkg_mgr' (Y/n) " y && { _run $CLAMITY_ROOT/bin/run-clamity os pkg selfupdate || return 1; } }
	_clear_clamity_module_cache
}

[ -z "$subcmd" ] && subcmd=update
# [ -z "$subcmd" ] && { _brief_usage "$customCmdDesc" "$subcmd"; return 1; }
[ "$subcmd" = help ] && { _man_page "$customCmdDesc" config; return 1; }
[ -n "$1" ] && _warn "selfupdate doesn't expect any args" && return 1

# Execute sub-commands
case "$subcmd" in
	update) _c_update_clamity || return 1;;
	*) _warn "unknown sub-command $subcmd. Try 'help'." && return 1;;
esac
return 0
