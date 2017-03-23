#!/bin/bash

######################################################
#                                                    #
# Servermoo monitoring agent                         #
# for more information visit:                        #
# https://servermoo.com/docs                         #
#                                                    #
######################################################

CONFIG_FILE="/etc/servermoo.conf"

#
# Include the Servermoo configuration file
# 
source $CONFIG_FILE

#
# Get server ip
# We are using the outside ip, but this will be used to 
# identify the server if it's behind a proxy
# 
get_ip() {
    
    local ip myip line nl=$'\n'

    # Loop through ifconfig and extract the ip address
    while IFS=$': \t' read -a line ; 
    do 
    	
    	[ -z "${line%inet}" ] && 
    	ip=${line[${#line[1]}>4?1:2]} && 
    	[ "${ip#127.0.0.1}" ] && 
    	myip=$ip

    done< <(LANG=C /sbin/ifconfig)
    
    # Construct the ip node
    echo $myip
}

#
# collect file names from $SCRIPTS_DIR directory
# 
get_scripts() {

	local permisions scripts

	# Check if the directory exists and there are files in it
	if [ -d $SCRIPTS_DIR ] && [ "$(ls -A $SCRIPTS_DIR)" ]; then

		for f in $SCRIPTS_DIR/*
		do

			# Get the file permissions
			permisions=`stat -c %A $f`

			# Add only those files which had owner executable permission
			if [ `stat -c %A $f | sed 's/...\(.\).\+/\1/'` == "x" ]; then
			  
				scripts="$scripts\"$(basename $f)\","

			fi

		done

	fi
	echo "[${scripts::-1}]"
}

#
# Construct the final json string from the plugins
# 
prepare_data() {

	# Local variables
	local module module_name plugin plugin_name
	local FILES=$PLUGINS_DIR/*.smoo

	# Final result variable
	local json=""

	# Loop through all files in the plugin directory
	for plugin in $FILES
	do
		# Get basename of the file and remove the suffix
		plugin_name="$(basename "$plugin")"
		plugin_name="${plugin_name%.*}"

		# include the plugin file
		source $plugin

		# Check whether the function exists
		if [ "$(type -t $plugin_name)" = 'function' ]; then
	
			# Plugin function result
			module="$($plugin_name)"
			
			# Append the module to the final result variable
			json="$json$module,"
		
		fi
	done

	# Return the prepared json
	# First removing the last trailing comma
	echo "{
		\"ip\": \"$(get_ip)\",
		\"scripts\": $(get_scripts),
		\"resources\": ["${json::-1}"]
	}"
}

#
# Read the response and behave based on the flag passed on the script
# it could pass multiple flags comma separated
# 
# The log contain the following information:
# 1. Start time - the time when the curl command has been executed
# 2. End time - the time when the response from the server has been received
# 3. The response which could be "OK" or list of commands to be executed
#
process_response() {
	
	# Assigning response to a variable
	local response=$1
	
	# This is the start time when we attempt to send the data to the server
	local start=$2
	
	# This is the time when the server respond to the curl request
	local end=`date +%Y-%m-%d:%H:%M:%S`
	
	# Log entry
	echo "$start - $end server response \"$response\""
	
	# Execute commands
	execute_response_commands $response

}

#
# Execute commands in the order of their appearence
# Servermoo will return only the command names, 
# what is the command is responsibility of the server admin.
# Therefore be careful and prorect $SCRIPTS_DIR directory and
# it's contentd from unauthorized access
#
execute_response_commands() {
	
	# Check if the first variable is not empty
	if [ ! -z "$1" ]; then
		
		# Loop through all command names
		for command in $(echo $1 | tr "," "\n")
		do
			# Check if the file exists
			if [ -f $SCRIPTS_DIR/$command ]; then
		  	
		  		# Execute the script from /etc/servermoo directory  
		  		eval $SCRIPTS_DIR/$command
		  	
		  	fi
		done

	fi

}

#
# Send the data with curl to the endpoint
# 
submit_data() {
	
	local start=`date +%Y-%m-%d:%H:%M:%S`

	# Store response from the curl in a variable	
	local response=$(curl \
		-H "Accept: application/json" \
		-H "X-Token: $API_KEY" \
		--silent \
		-X POST \
		-d "$(prepare_data)" \
		$ENDPOINT
	)

	# Handle the reponse if there are some flags passed
	if [ ! -z "$response" ]; then
		process_response $response $start
	else
		echo "$start No response from the server"
	fi
}

# Send server call on every 20 seconds

while :
do
	
	submit_data
	sleep 60

done
