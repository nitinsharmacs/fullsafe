#! /bin/bash

PROJECT_PATH=~/Learning/Projects/fullsafe
TEST_CONFIG_EXPECTED="${PROJECT_PATH}/tests/testing_data/test_config_expected"

TEST_CONFIG_ACTUAL="${PROJECT_PATH}/tests/testing_data/test_config_actual"
STORE_PATH="${PROJECT_PATH}/tests/.backups_bs_test"
STORE_PATH="$HOME/.backups_bs"

source "${PROJECT_PATH}/fullsafe_library.sh"
source "${PROJECT_PATH}/tests/general_test_functions.sh"
source "${PROJECT_PATH}/tests/generate_report.sh"

CONFIG_FILE=$TEST_CONFIG_ACTUAL

function test_assert_files_existence() {
	local test_description=$1
	local files=("${@:2:$(( $# - 2 ))}")
	local expected="${@:(-1)}"
	
	assert_files_existence "${files[@]}" &> /dev/null
	local actual=$?
	local inputs="Files : ${files[@]}"
	push $(verify_expectations $actual $expected) "assert_files_existence|${test_description}|${inputs}|${expected}|${actual}"
}

function test_cases_assert_files_existence() {
	test_assert_files_existence "should give zero return status if file exist" "${PROJECT_PATH}/fullsafe_library.sh" "0"
	test_assert_files_existence "should give 1 return status if file doesn't exist" "fullsafe.shh" "1"
}

# testing array_includes()
function test_array_includes() {
	local test_description=$1
	local searching_ele="$2"
	local array=("${@:3:$(( $# - 3 ))}")
	local expected="${@:(-1)}"
	
	local actual=$( array_includes $searching_ele "${array[@]}" )
	local inputs="Searching Ele : $searching_ele, Array : ${array[@]}"
	local test_result=$(verify_expectations "$actual" "$expected")
	push $test_result "array_includes|${test_description}|${inputs}|${expected}|${actual}"
}

function test_cases_array_includes() {	
	local array=(harry "jonathan william" 23)
	test_array_includes "should return element index if it exists" 23 "${array[@]}" 2
	test_array_includes "should return -1 if it doesn’t exist" something "${array[@]}" -1
}

# testing write_config_file()
function test_write_config_file() {
	local test_description=$1
	local configs=("${@:2:$(( $# - 2 ))}")
	local expected=${@:(-1)}
	
	write_config_file "${configs[@]}" &> /dev/null
	diff $TEST_CONFIG_EXPECTED $TEST_CONFIG_ACTUAL &> /dev/null
	local actual=$?

	local inputs="Files : $TEST_CONFIG_EXPECTED,$TEST_CONFIG_ACTUAL" 
	local test_result=$(verify_expectations "$actual" "$expected")
	push $test_result "write_config_file|${test_description}|${inputs}|${expected}|${actual}"
}

function test_cases_write_config_file() {
	local configs=("dir_name|test" "version|2" "files|test_config_expected")
	test_write_config_file "test_config_expected and test_config_actual should be same" "${configs[@]}" 0
}

# testing read_config_file()
function test_read_config_file() {
	local test_description=$1
	local expected_configs=("${@:2}")
	
	local actual_configs=($( read_config_file 2> /dev/null ))
	local test_result="pass"
	
	local config_index=0
	while [[ $config_index -lt ${#expected_configs[@]} ]]
	do
		if [[ "${expected_configs[$config_index]}" != "${actual_configs[$config_index]}" ]]; then
			test_result="fail"
			break
		fi
		config_index=$(( $config_index + 1 ))
	done
	
	local inputs="-"
	push $test_result "read_config_file|${test_description}|${inputs}|$( echo ${expected_configs[@]} | tr '|' ':')|$( echo ${actual_configs[@]} | tr '|' ':')"
}

function test_cases_read_config_file() {
	local configs=("dir_name|test" "version|2" "files|test_config_expected")
	test_read_config_file "should return an array of configs if it succeeds" "${configs[@]}"
}

#initialize_config_file
function test_initialize_config_file() {
	local test_description=$1
	local args=$2
	local expected=$3
	
		
}
function test_cases_initialize_config_file() {
	test_initialize_config_file "should give 0 return status if it succeeds" "" 0
	test_initialize_config_file "should give 5 return status for no arguments provided." "testing_dir" 5 
	test_initialize_config_file "should give 5 return status if backup directory name is taken." "fullsafe" 5
	test_initialize_config_file "should give 5 return status if any of the given files doesn’t exist." "temporary.sh" 5
}

function test_update_config_file() {
	local test_description=$1
	local key=$2
	local value=$3
	local expected=$4
	
	local actual=$( update_config_file "$key" "$value" )
	local inputs="key:$key, value:$value"
	local test_result=$( verify_expectations "$actual" "$expected" )
	push $test_result "update_config_file|${test_description}|${inputs}|${expected}|${actual}"
}
function test_cases_update_config_file() {
	test_update_config_file "should return “updated” if it succeeds" "version" "2" "updated"
	test_update_config_file "should return “key doesn’t exist”  if the key wasn't found" "wrong_key" "23" "key doesn't exist"
}

function test_obtain_value() {
	local test_description=$1
	local key=$2
	local expected=$3
	
	local actual=$( obtain_value "$key" 2> /dev/null )
	local inputs="Key : $key"
	local test_result=$( verify_expectations "$actual" "$expected" )
	push $test_result "obtain_value|${test_description}|${inputs}|${expected}|${actual}"
}
function test_cases_obtain_value() {
	test_obtain_value "should return value if the key matched" "version" "2"
	test_obtain_value "should return \"key doesn’t exist\" if key doesn’t exist" "wrong_key" "key doesn't exist"
}

function test_backup() {
	local test_description=$1
	
	local expected="Success : backup done !"
	local actual=$( backup 2> /dev/null )
	
	local test_result=$( verify_expectations "$actual" "$expected" )
	push $test_result "backup|${test_description}|-|${expected}|${actual}"
}
function test_cases_backup() {
	test_backup "should return “Success : backup done !” if it succeeds"
}

function test_updates_runner() {
    local test_description=$1
    local expected=$2

    local actual=$( updates_runner )

    local test_result=$( verify_expectations "$actual" "$expected" )
	push $test_result "updates_runner|${test_description}|-|${expected}|${actual}"
}
function test_cases_updates_runner() {
    local test_description="should rename old config file to new config"
    local expected=0
    test_updates_runner "$test_description" "$expected"

    test_description="should rename old fullsafe store folder"
    expected=0
    test_updates_runner "$test_description" "$expected"
}

function all_test_cases_fullsafe_library() {
	test_cases_assert_files_existence
	test_cases_array_includes
	test_cases_write_config_file
	test_cases_read_config_file
	test_cases_update_config_file
	test_cases_obtain_value
	test_cases_backup
    test_cases_updates_runner
}

function test_fullsafe_library() {
    echo "Running tests . . ."
	all_test_cases
	
	IFS=$'\n'
	local tests=($(get_tests))
	IFS=" "
	
	generate_report "${tests[@]}"
}