#!/usr/bin/env bash

# desc: keep your clamity installation up to date

# this script is sourced.
# Supported shells: bash, zsh

source $CLAMITY_ROOT/lib/_.sh || exit 1

function update_git_installation {
	_echo "git repo installation detected"
	pushd "$CLAMITY_ROOT" || return 1
	[ `git status -s | wc -l` -ne 0 ] && { _fatal "'git status' did not report a clean repo. update aborted." && popd; return 1; }
	local rc=0
	_run git pull origin || rc=1
	popd || rc=1
	return $rc
}

function update_tarball_installaton {
	_echo "tarball installation assumed ('cause it ain't a git repo)"
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
	local tarball="selfupdate.`date +%Y%M%D-%%H%M%S`.tgz"
	local rc=0
	local clamDirName=$(`basename "$CLAMITY_ROOT"`)
	_run tar czpf "$CLAMITY_HOME/backups/$tarball" "$clamDirName" || rc=1
	popd || rc=1
	return $rc
}

_ask "Backup clamity (Y/n)? " y && { backup_clamity || return 1; }

[ -d "$CLAMITY_ROOT/.git" ] && { update_git_installation || return 1; } || { update_tarball_installaton || return 1; }

_echo "updating python packages" && _run $CLAMITY_ROOT/bin/run-py update || return 1;

_clear_clamity_module_cache

return 0
