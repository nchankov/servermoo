#!/bin/bash

######################################################
#                                                    #
# Servermoo monitoring agent                         #
# for more information visit:                        #
# https://servermoo.com/docs                         #
#                                                    #
######################################################

# 
# The url which the server will hit with the data collected 
# 
ENDPOINT='https://api.servermoo.com/endpoint'

#
# Location where the api key will be stored
#
API_LOCATION="/etc/servermoo.api"

#
# Commands location
#
COMMANDS_LOCATION="/etc/servermoo/"

#
# Get the token stored in a external file
# 
get_token() {
	
	local api
	
	if [ -f "$API_LOCATION" ]; then
		
		api=$(<$API_LOCATION)
		
		if  [ ! -z "$api" ]; then
			
			echo $api
		
		fi
	
	fi

}

#
# Get server ip
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
    echo "\"ip\": \"$myip\","

}

#
# Get server load
#
get_cpu () {

	# Get number of processors
	local processors=`grep -c ^processor /proc/cpuinfo`

	# Get processor loads
	local load1=`cat /proc/loadavg | awk '{print $1}'` # Last minute
	
	local load2=`cat /proc/loadavg | awk '{print $2}'` # Last 5 minutes
	
	local load3=`cat /proc/loadavg | awk '{print $3}'` # last 15 minutes

	# Construct the cpu node
	echo "
		\"cpu\": {
			\"processors\": $processors,
			\"load\": {
				\"l1\":$load1, 
				\"l2\": $load2, 
				\"l3\": $load3
			}
		},"

}

#
# Get server memory
#
get_memory() {
	
	# Available memory in bytes
	local available_memory=`free | awk 'NR==2{printf "%s", $2}'`
	
	# Used memory in bytes
	local used_memory=`free | awk 'NR==2{printf "%s", $3 }'`

	# Available swap
	local available_swap=`free | awk 'NR==4{printf "%s", $2}'`

	# Used swap
	local used_swap=`free | awk 'NR==4{printf "%s", $3}'`
	
	# Construct the memory node
	echo "\"memory\": {
		\"physical\": {
			\"available\": $available_memory, 
			\"used\": $used_memory
		},
		\"swap\": {
			\"available\": $available_swap, 
			\"used\": $used_swap
		}
	},"

}

#
# Get server disks
# 
get_disks() {

	local disks
	
	local fs size used avail use mnt
	
	local i=0

	# Loop through all disks
	while IFS=$': \t' read fs size used avail use mnt; 
	do
		
		# Single disk node
		disks="$disks{
			\"filesystem\": \"$fs\", 
			\"size\": \"$size\",
			\"used\": \"$used\",
			\"mount\": \"$mnt\"
		},"

	done< <(df | tail -n+2)
	
	# Remove the last comma and 
	# Construct the disks node
	echo "\"disks\": [${disks::-1}],"

}

#
# collect file names from /etc/servermoo/ directory
# 
get_commands() {

	local permisions commands

	# Check if the directory exists and thereare files in it
	if [ -d $COMMANDS_LOCATION ] && [ "$(ls -A $COMMANDS_LOCATION)" ]; then

		for f in $COMMANDS_LOCATION*
		do

			# Get file permissions
			permisions=`stat -c %A $f`

			# Add only those files which had owner executable permission
			if [ `stat -c %A $f | sed 's/...\(.\).\+/\1/'` == "x" ]; then
			  
				commands="$commands\"$(basename $f)\","

			fi

		done

		echo "\"commands\": [${commands::-1}],"
	fi
}

#
# Construct the final json string which will be send
# 
prepare_data() {
	
	# Json contents
	local json="$(get_ip)$(get_cpu)$(get_memory)$(get_disks)$(get_commands)"
	
	# Print the json which will be send to the server
	# and removing the last comma
	echo "{"${json::-1}"}"

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
# Servermoo will return only the command names, what is the 
# command is responsibility of the server admin.
# Therefore be careful and prorect /etc/servermoo directory and
# it's contentd from unauthorized access
#
execute_response_commands() {
	
	# Check if the first variable is not empty
	if [ ! -z "$1" ]; then
		
		# Loop through all command names
		for command in $(echo $1 | tr "," "\n")
		do
			# Check if the file exists
			if [ -f $COMMANDS_LOCATION$command ]; then
		  	
		  		# Execute the script from /etc/servermoo directory  
		  		eval $COMMANDS_LOCATION$command
		  	
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
		-H "X-Token: $(get_token)" \
		--silent \
		-X POST \
		-d "$(prepare_data)" \
		$ENDPOINT
	)

	# Handle the reponse if there are some flags passed
	process_response $response $start
	
}

# Send server call on every 20 seconds
while :
do
	
	submit_data
	sleep 20

done
