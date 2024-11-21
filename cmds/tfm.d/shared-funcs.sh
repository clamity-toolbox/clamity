
function tfm_record_results {
	_echo "Creating OUTPUT.json and STATE.md"
	_vecho "_run terraform output -json | jq .props.value >OUTPUT.json"
	terraform output -json | jq .props.value >OUTPUT.json
	echo -e "# Terraform State List\n" >STATE.md
	_vecho terraform state list >>STATE.md
	terraform state list >>STATE.md
}
