# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# These must be accounted for in options-parser.sh: __parse_common_options()
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

function __c_is_known_prop { # success if property is known
	_trace "__c_is_known_prop()> checking '$*' against $(__c_clamity_known_props)"
	echo "$(__c_clamity_known_props)" | grep -q "$1"
}

function __c_clamity_known_props {
	echo "$(__c_opts_common_list) $(__c_opts_other_list)"
}

function __c_opts_common_list {
	echo "debug  dryrun  output_format  quiet  yes  verbose  trace"
}

function __c_opts_other_list {
	echo "disable_module_cache  os_preferred_pkg_mgr  aws_sso_session"
}

# other opts that cannot be overridden
# ------------------------------------
# output_redirection
# logfile
# cmds_path

function __c_opts_common_help {
	echo "COMMON OPTIONS

	-d, --debug
		Debug mode provides additional, lower-level output (CLAMITY_debug=1). Debug
		messages are sent to stderr.

	-n, --dryrun
		Allows for execution of a script withot causing an underlying change to whatever
		data the script affects. It is up to each script to determine what that means.
		Some scripts do not support dryrun and will terminate immediately if it's enabled
		(CLAMITY_dryrun=1).

	-of, --output-format { json | text | csv }
		Specifies format of output where applicable (CLAMITY_output_format). Defaults
		to json.

	-or, --output-redirection { none | log }
		Sets up output redirection. 'none' leaves stdout and stderr untouched (this is
		the default setting). 'log' captures both stdout and stderr to one log file and
		sets CLAMITY_logfile to the full path and name of the logfile, using that value
		if already set (CLAMITY_output_redirection=\"{none | log}\").

	-q, --quiet
		Suppress (or minimize) all reporting except warnings and errors (CLAMITY_quiet=1).

	-v, --verbose
		Enable extra reporting (CLAMITY_verbose=1). Includes printing the commands being
		run under the hood to stdout.

	-y, --yes
		Disables interactive mode in which commands that prompt for confirmation before
		doing things will automatically get answered with 'yes' (CLAMITY_yes=1).
"
}
