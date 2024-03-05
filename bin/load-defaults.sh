
# Load core shell library and set defaults before each command.
# Sourced into shell (mutates the shell environment).
#
# Supported shells: zsh, bash

# source $CLAMITY_ROOT/lib/_.sh || return 1

# envFile="`_defaults DefaultConfigFile`"
# _load_clamity_aliases || return 1

# # default envFile is optional
# [ ! -f "$envFile" ] && return 0

# _debug "load-defaults.sh: $envFile ($CLAMITY_load_defaults_opts)"
# _set_evars_from_env_file_if_not_set "$envFile" "$CLAMITY_load_defaults_opts"

# return 0
