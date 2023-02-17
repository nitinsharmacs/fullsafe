#! /bin/bash

CONFIG_FILE=".fullsafe.config"
STORE_PATH="$HOME/.fullsafe_backups"
SEPARATOR=$(seq -f"-" -s"\0" 20)

# exit status
NOT_FOUND=4
WRONG_INPUT=5
FUNCTIONAL_ERROR=3

# Font formates
BOLD="\033[1m"
NORMAL="\033[0m"

#usages
FULLSAFE_COMMANDS="command|description|options|syntax

init | initialize fullsafe on your directory | - | fullsafe init <filenames_to_backup>
backup | to make backup | [-z zip] | fullsafe backup [-z]
restore | restore the backup | - | fullsafe restore <backup_file> <destination_directory>
delete | delete backups | - | fullsafe delete <backup file/s>
list | list the avaiable versions | - | fullsafe list
content | show the content of backup versions | - | fullsafe content <backup file/s>
update | update configs of backup | [-af add file/s] [-rf remove file/s] [-v version] [-d backup directory] | fullsafe update [-af] [-rf] [-v] [-d] <args..>
manual | open fullsafe manual in browser | - | fullsafe manual"

# helper functions
function assert_files_existence() {
	local files=($@)

	local file
	for file in "${files[@]}"
	do
		if [[ ! -e "$file" ]]; then
			echo "Error : \"$file\" didn't exit !"
			return 1
		fi
	done
}

function array_includes() {
	local searching_element=$1
	local array=("${@:2}")
	
	local element_index=0
	local array_ele
	for array_ele in "${array[@]}"
	do
		if [[ "$searching_element" == "$array_ele" ]]; then
			echo $element_index
			return 0
		fi
		element_index=$(( $element_index + 1 ))
	done
	echo -1
	return 1
}
# end of helper functions

# functions to handle .config.bs file
function write_config_file() {
	local configs=("$@")
	
	rm $CONFIG_FILE 2> /dev/null
	
	local config
	for config in "${configs[@]}"
	do
		echo $config >> "${CONFIG_FILE}.temp"
	done
	
	mv "${CONFIG_FILE}.temp" $CONFIG_FILE
}

function read_config_file() {
	local configs=()

	local config
	for config in $(cat $CONFIG_FILE)
	do
		configs[${#configs[@]}]=$config
	done
	echo ${configs[@]}
}

function initialize_config_file() {
	if [[ $# -eq 0 ]]; then
		echo "Error : Please enter alteast a file"
		return $WRONG_INPUT
	fi

	local files=$@
	files=$(echo "$files" | tr " " ",")
	
	local dir_name
	read -p "Enter backup directory name : " dir_name
	
	local backup_dir="${STORE_PATH}/${dir_name}"
	if [[ -d $backup_dir ]]
	then
		echo "Error : Please enter different backup directory"
		return $WRONG_INPUT
	fi
	mkdir -p $backup_dir
	
	local configs=("dir_name|${dir_name}" "version|0" "files|${files}")

	write_config_file ${configs[@]}
	echo "Success : fullsafe is initialized !"
}

function update_config_file() {
	local key=$1
	local value=$2
	
	local configs=($(read_config_file))
	local config
	local index=0
	for config in "${configs[@]}"
	do
		if echo "$config" | grep -q "^${key}"
		then
			configs[$index]="${key}|${value}"
			break
		fi
		index=$(( $index + 1 ))
	done
	
	if [[ $index -ge ${#configs[@]} ]]; then
		echo "key doesn't exist"
		return $NOT_FOUND
	fi
	
	write_config_file "${configs[@]}" &> /dev/null
	echo "updated"
}

function obtain_value() {
	local key=$1
	
	local value
	local configs=($(read_config_file $CONFIG_FILE))
	local config
	for config in "${configs[@]}"
	do
		if echo "$config" | grep -q "^${key}|"
		then
			value=$( echo "$config" | cut -f2 -d"|" )
			break
		fi
	done
	
	if [[ -z $value ]]; then
		echo "key doesn't exist"
		return $NOT_FOUND
	fi
	echo $value
}

# end of functions to handle .config.bs file

# usage function for commands and switches that require arguments to work on
function command_usages() {
	local command=$1
	echo -n "usage: "
	echo "$FULLSAFE_COMMANDS" | grep "^${command}" | cut -f4 -d"|"
}

function switch_usages() {
	local switch=$1
	
	local usages=("-af|usage: fullsafe update -af <files...>" "-rf|usage: fullsafe update -rf <files...>" "-d|usage: fullsafe update -d <directory_name>" "-v|usage: fullsafe update -v <version>")
	
	local usage
	for usage in "${usages[@]}"
	do
		if echo $usage | grep "^$switch" > /dev/null
		then
			echo $usage | cut -f2 -d"|"
		fi
	done
}
# end of usage function

# functions to deal with backups
function backup() {
	local switches=$1

	local extension="tar"
	local property
	if [[ $# -eq 1 && $switches == "-z" ]]
	then
		property="z"
		extension="tar.gz"
	fi
	
	local configs=($(read_config_file $CONFIG_FILE))
	local dir_name=$( echo "${configs[0]}" | cut -f2 -d"|" )
	local version=$( echo "${configs[1]}" | cut -f2 -d"|" )
	local files=$( echo "${configs[2]}" | cut -f2 -d"|" | tr "," " " )

	local backup_name="$(date "+%Y%m%d_%H%M%S")_v$(( $version + 1 )).${extension}"
	local destination="${STORE_PATH}/${dir_name}/${backup_name}"
	
    echo "Creating backup"
	tar cf${property} $destination $files
	
	configs[1]="version|$(( $version + 1 ))"
	write_config_file ${configs[@]}
	
	echo -e "Success : backup done !"
}

function show_versions() {
	local backup_dir=$(obtain_value "dir_name")
	
	local versions_output=$( ls -1tr "$STORE_PATH/$backup_dir"	)
	if [[ -z $versions_output ]]; then
		versions_output="No versions found"
	fi
	echo "$versions_output"
}

function delete_backups() {
	if [[ $# -lt 1 ]]; then
		command_usages "delete"
		return $WRONG_INPUT
	fi

	local dir_name=$(obtain_value "dir_name")
	cd $STORE_PATH/${dir_name}

	local file_names=($@)
	
	echo "Result|File Name|comment"
	echo $SEPARATOR	
	
	local message
	local file_name
	for file_name in "${file_names[@]}"
	do
		message="error|$file_name|file didn't find"
		if rm ${STORE_PATH}/${dir_name}/$file_name 2> /dev/null
		then
			message="success|$file_name| -"
		fi
		echo $message
	done
	cd - > /dev/null
}

function restore_backup() {
	if [[ $# -lt 2 || $# -gt 2 ]]; then
		command_usages "restore"
		return $WRONG_INPUT
	fi
	
	local file_name=$1
	local destination=$2

	local dir_name=$(obtain_value "dir_name")
	[[ ! -f "$STORE_PATH/${dir_name}/$file_name" ]] && echo "Error : Backup file didn't find" && return $NOT_FOUND
	[[ ! -e $destination ]] && mkdir -p $destination 2> /dev/null
	
	cd $destination
	
	local message="Success : backup restored"
	local return_status=0
	if tar xf "$STORE_PATH/${dir_name}/$file_name" 2> /dev/null; then
		mesage="Error : Backup didn't restore, try again !"
		return_status=$FUNCTIONAL_ERROR
	fi
	echo $message
	cd - > /dev/null
	return $return_status
}

function list_backup_content() {
	if [[ $# -lt 1 ]]; then
		command_usages "content"
		return $WRONG_INPUT
	fi
	
	local dir_name=$( obtain_value "dir_name")
	cd $STORE_PATH/${dir_name}
	
	local file_names=($@)

	local file_name
	for file_name in "${file_names[@]}"
	do
		echo  "File : \"$file_name\" >"
		
		tar tf "$STORE_PATH/${dir_name}/${file_name}" 2> /dev/null
			
		if [[ $? -eq 1 ]]; then
			echo "Error : file \"$file_name\" didn't exist !"
		fi
		echo
	done
	cd - > /dev/null
}

function add_new_files() {
	local files=($@)
	if [[ ${#files[@]} -lt 1 ]]; then
		switch_usages "-af"
		return $WRONG_INPUT
	fi
	
	! assert_files_existence "${files[@]}" && return $NOT_FOUND
	
	local old_files=$(obtain_value "files")
	files=$(echo "${files[@]}" | tr " " "," )
	local new_files="$(echo "$old_files,$files" | tr "," "\n" | sort | uniq | tr "\n" ",")"

	update_config_file "files" "$new_files"
	echo "Success : new files added"
}

function remove_files() {
	local files_to_remove=($@)
	if [[ ${#files_to_remove[@]} -lt 1 ]]; then
		switch_usages "-rf"
		return $WRONG_INPUT
	fi
	
	local present_files=$( obtain_value "files" | tr "," " ")

	echo -e "Result|File Name|Comment\n"
	
	local message
	local file
	for file in "${files_to_remove[@]}"
	do
		message="error|$file|didn't find"
		if array_includes "$file" ${present_files} > /dev/null
		then
			present_files=$(echo ${present_files} | tr " " "\n" | sort | uniq | grep -v "^$file$" )
			message="success|$file| -"
		fi
		echo $message
	done
	
	update_config_file "files" $( echo ${present_files} | tr " " "," )
}

function rename_backup_dir() {
	local new_dir_name=$1
	if [[ -z "$new_dir_name" ]]; then
		switch_usages "-d"
		return $WRONG_INPUT
	fi
	
	local dir_name=$(obtain_value "dir_name")
	
	if mv "$STORE_PATH/$dir_name" "$STORE_PATH/${args[@]}" 2> /dev/null
	then
		update_config_file "dir_name" "${args[@]}"
		echo "Success : Done"
		return 0
	fi
	echo "Error : Please enter different directory"
	return $WRONG_INPUT
}

function update_version() {
	local new_version=$1
	
	if ! echo "${args[@]}" | grep -q "^[0-9]*$"
	then
		echo "Error : Invalid version entry"
		return $WRONG_INPUT
	fi
	update_config_file "version" "${args[@]}"
	echo "Success : Done"
}

function update_config() {
	local switch=$1
	local args=("${@:2}")
	
	local switches=("-af" "-rf" "-d" "-v")
	local functions=("add_new_files" "remove_files" "rename_backup_dir" "update_version")
	local function_index=$(array_includes "$switch" "${switches[@]}")
	
	[[ $function_index -lt 0 ]] && command_usages "update" && return 1
	
	"${functions[$function_index]}" "${args[@]}"
}

#function to run new updates
# function updates_runner() {
#     if [[ -f .config.bs ]]; then
#         mv .config.bs $CONFIG_FILE
#     elif [[  ]]

# }

function setup() {
    local old_store_path="$HOME/.backups_bs"
    if [[ ! -f $CONFIG_FILE && -f .config.bs ]]; then
        mv .config.bs $CONFIG_FILE
    elif [[ ! -f $CONFIG_FILE && ! -f .config.bs ]]; then
        return 1
    fi

    if [[ ! -e $STORE_PATH && -e $old_store_path ]]; then
        mv $old_store_path $STORE_PATH
    fi
}
# usage function for command
function show_usage() {
	echo "usage: fullsafe [command] [options] [args]"
}

# show tool help
function show_help() {
	echo -e "Utility tool for making backup\n"
	show_usage
	echo
	echo -e "$FULLSAFE_COMMANDS"	
}

function open_manual() {
    open "https://nitinsharmacs.github.io/"
}
# show version
function version() {
	echo "fullsafe version 6.1"
}

function main() {
	local command=$1
	local data_values=("${@:2}")
	local switches=()

	if echo ${@:2} | grep -q "^-.*"
	then
		switches=($(echo ${@:2} | tr " " "\n" | grep "^\-." | tr "\n" " "))
		data_values=("${@:$(( 2 + ${#switches[@]} ))}")
	fi

	local commands=("init" "backup" "restore" "list" "delete" "content" "update" "--help" "manual" "--version")
	local functions=("initialize_config_file" "backup" "restore_backup" "show_versions" "delete_backups" "list_backup_content" "update_config" "show_help" "open_manual" "version" )
	
	local function_index=$( array_includes "$command" "${commands[@]}" )
	[[ $function_index -lt 0 ]] && show_usage && exit 1
	
    if [[ $(array_includes $command "--help" "manual" "--version" "init" ) -lt 0 ]]; then
        if ! setup; then
            echo "Please initialize the fullsafe on your directory, use --help for more info"
			exit 1
        fi
    fi

	${functions[$function_index]} "${switches[@]}" "${data_values[@]}"
	
	exit $?	
}