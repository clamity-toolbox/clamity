function _tfm_prop {
	cat $TFM_REPO_ROOT/.clamity/config/settings.sh $TFM_REPO_ROOT/.clamity/local/settings.sh 2>/dev/null | grep "^$1=" | cut -f2- -d=
}

function _tfm_record_results {
	local rc=0
	if [ "$(_tfm_prop record_output)" ]; then
		_echo "Creating OUTPUT.json"
		_vecho "_run terraform output -json | jq .props.value >OUTPUT.json"
		terraform output -json | jq .props.value >OUTPUT.json || rc=1
	fi
	if [ "$$(_tfm_prop record_state)" ]; then
		_echo "Creating STATE.md"
		_vecho "terraform state list >STATE.md"
		echo -e "# Terraform State List - $(pwd | rev | cut -f1-2 -d/ | rev)\n" >STATE.md
		echo "\`\`\`" >>STATE.md
		terraform state list | sort >>STATE.md || rc=1
		echo "\`\`\`" >>STATE.md
	fi
	return $rc
}

function update_custom_dependencies {
	[ -x "./dependencies.eval.sh" ] && { echo "eval'ing output from ./dependencies.eval.sh - these settings will be retained in the environment" >&2 && eval $(./dependencies.eval.sh) || return 1; }
	[ -x "./dependencies.sh" ] && { _echo "executing ./dependencies.sh -f" && _run ./dependencies.sh -f || return 1; }
	return 0
}
