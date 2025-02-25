# desc: update clamity and OS packages

# THIS FILE IS SOURCED INTO, AND THEREFORE MUTATES, THE CURRENT SHELL
# supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || return 1

# ---------------------------------------------------------------------------
# Define content for brief help and the manpage for this command. Comment out
# any that does not apply. The formatting of the strings is important to
# maintain - shell data handling is simplistic.
# ---------------------------------------------------------------------------

# More descriptive overview of the command. Paragraph(s) allowed. This is
# included on a man page. (REQUIRED)
__Abstract="
	Update the clamity software, package managers and packages and all
	matter of software under clamity's umbrella.

	The full monty includes:
	 - backup clamity data and software ($CLAMITY_ROOT/, ~/.clamity/)
	 - update clamity software (git pull)
	 - update clamity python env
	 - update selected package manager (apt, brew, macports, ...) pkgs
"

# one or more lines detailing usage patterns (REQUIRED)
__Usage="
	clamity selfupdate help
	clamity selfupdate [update] [ -y ] [ --no-pkg-mgr ]
"

# Don't include common options here
__CommandOptions="
# 	--no-pkg-mgr
# 		Update the clamity installation without including the package manager.
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
	Update clamity interactively
		clamity selfupdate

	Update clamity non-interactively without the including the package manager
		clamity selfupdate --no-pkg-mgr
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

customCmdDesc="
\n\tupdate - update clamity software (default action)
"
# ---------------------------------------------------------------------------

function _c_clamity_repo_is_clean {
	local rc=0
	pushd $CLAMITY_ROOT || return 1
	[ $(git status -sb | wc -l) -ne 1 ] && _warn "clamity repo does not look clean" && rc=1
	popd || return 1
	return $rc
}

function _c_update_git_installation {
	cd "$CLAMITY_ROOT" || return 1
	git pull origin
}

function _c_update_tarball_installaton {
	_echo "tarball installation assumed (git not detected)."
	_echo "not implemented yet"
	return 1
}

function _c_backup_clamity {
	[ ! -d "$CLAMITY_HOME/backups" ] && { mkdir "$CLAMITY_HOME/backups" || return 1; }
	pushd "$CLAMITY_ROOT/.." || return 1
	local rc=0
	local now=$(date +%Y%m%d-%H%M%S)
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
	[ $rc -eq 0 ] && _run find $CLAMITY_HOME/backups -type f -mtime +21 -delete

	return $rc
}

function _c_update_clamity {
	[ -d "$CLAMITY_ROOT/.git" ] && { _c_clamity_repo_is_clean || return 1; }
	_ask "Backup clamity before we begin (Y/n)? " y && { _c_backup_clamity || return 1; }
	[ -d "$CLAMITY_ROOT/.git" ] && { _c_update_git_installation || return 1; } || { _c_update_tarball_installaton || return 1; }
	_echo "Updating python packages in clamity venv" && _run $CLAMITY_ROOT/bin/clam-py update || return 1
	[ "$_opt_no_pkg_mgr" -eq 0 ] && _ask "Update OS packages (Y/n)? " y && { _run $CLAMITY_ROOT/bin/run-clamity os pkg selfupdate || return 1; }
	_clear_clamity_module_cache
}

cmd=selfupdate
{ [ -z "$1" ] || [[ "$1" = -* ]]; } && subcmd=update || { subcmd="$1" && shift; }
_usage "$customCmdDesc" "$cmd" "$subcmd" -command || return 1

# _cmds_needed aws || { _error "unable to run aws CLI" && return 1; }

_sub_command_is_external $cmd $subcmd && {
	_run_clamity_subcmd $cmd $subcmd "$@"
	return $?
}

_set_standard_options "$@"
echo "$@" | grep -q '\--no-pkg-mgr' && _opt_no_pkg_mgr=1 || _opt_no_pkg_mgr=0

# Execute sub-commands
rc=0
case "$subcmd" in
update)
	_c_update_clamity || rc=1
	;;
*)
	_warn "unknown $cmd sub-command '$subcmd'. Try 'clamity $cmd help'." && rc=1
	;;
esac

_clear_standard_options _opt_no_pkg_mgr
return $rc
