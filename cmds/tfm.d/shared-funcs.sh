function _tfm_prop {
	cat $TFM_REPO_ROOT/.clamity/config/settings.sh $TFM_REPO_ROOT/.clamity/local/settings.sh 2>/dev/null | grep "^$1=" | cut -f2- -d=
}

function _tfm_record_results {
	if [ "$(_tfm_prop record_output)" ]; then
		_echo "Creating OUTPUT.json"
		_vecho "_run terraform output -json | jq .props.value >OUTPUT.json"
		terraform output -json | jq .props.value >OUTPUT.json
	fi
	if [ "$$(_tfm_prop record_state)" ]; then
		_echo "Creating STATE.md"
		_vecho "terraform state list >STATE.md"
		echo -e "# Terraform State List - $(pwd | rev | cut -f1-2 -d/ | rev)\n" >STATE.md
		terraform state list >>STATE.md
	fi
	[ $(git diff --name-only | wc -l) -eq 0 ] && return 0
	_echo "Committing updated output and audit files post-apply"
	_run git diff --name-only
	_ask "Commit and push origin (Y/n)? " y && _run git commit -am "post-apply output and audit update" && _run git push origin
}
