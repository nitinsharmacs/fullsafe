#! /bin/bash

PROJECT_PATH=~/Learning/Projects/fullsafe

source "${PROJECT_PATH}/fullsafe.sh"
source "${PROJECT_PATH}/tests/general_test_functions.sh"
source "${PROJECT_PATH}/tests/generate_report.sh"


function test_updates_runner() {
    local test_description=$1
    local expected=$2

    local actual=$( update_runner )

    local test_result=$( verify_expecations "$actual" "$expected" )
    push $test_result "updates_runner|$test_description|-|$expected|$actual"
}
function test_cases_updates_runner() {
    test_updates_runner "should rename old config file to new config" "0"
    test_updates_runner "should rename old fullsafe store folder" "0"
}

function all_test_cases_fullsafe() {
    test_cases_updates_runner
}

function test_fullsafe() {
    echo "Running tests . . ."
	all_test_cases
	
	IFS=$'\n'
	local tests=($(get_tests))
	IFS=" "
	
	generate_report "${tests[@]}"
}
