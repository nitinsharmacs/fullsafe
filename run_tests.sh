#! /bin/bash

PROJECT_PATH=/Users/nitinsharma/Learning/Projects/fullsafe

source "${PROJECT_PATH}/fullsafe_library.sh"

TEST_FILES="$PROJECT_PATH/tests"

source $TEST_FILES/general_test_functions.sh
source $TEST_FILES/generate_report.sh
source $TEST_FILES/test_fullsafe_library.sh

function all_test_cases() {
    all_test_cases_fullsafe_library
}

function run_tests() {
	echo "Running tests . . ."
	all_test_cases
	
	IFS=$'\n'
	local tests=($(get_tests))
	IFS=" "
	
	generate_report "${tests[@]}"
}

run_tests

