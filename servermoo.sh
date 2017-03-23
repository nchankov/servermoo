#!/bin/bash

#########################################
#                                       #
# Servermoo daemon                      #
# for more information visit:           #
# https://servermoo.com/about           #
#                                       #
#########################################

#
# Where the config file will be placed.
# 
CONFIG_FILE="/etc/servermoo.conf"

#
# Where is the main directory of the agent
#
SERVERMOO_DIR="/usr/share/servermoo"

# Where is the daemon location
#
DAEMON_DIR="/etc/init.d"

# 
# The directory of this script
#
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#
# Asking for api key and store it in to a file file
#
get_api_key() {

	# Check if the servermoo location exists in the /etc folder
	# and if not request the api key in the user prompt
	if [ ! -f "$CONFIG_FILE" ]; then
		echo "" # for better spacing

		# Ask the user to provide the api key
		read -p "Please provide your api key: " api
		
		# Check if the user pass any info
		if [ ! -z "$api" ]; then
			
			# Check if there is template configuration file
			if [ -f "$CURRENT_DIR/servermoo.conf.dist" ]; then

				echo "Copy the configuration file into it's place..."
				# Copy the template location into the config dir
				cp -v $CURRENT_DIR/servermoo.conf.dist $CONFIG_FILE 

				#replace the api sting into the config file
				sed  -i "s/YOUR_SERVERMOO_API_KEY/$api/g" $CONFIG_FILE
			fi

			echo "Config file is stored at $CONFIG_FILE"
			echo ""
		else
			
			# If there is no api key provided print a message and stop here
			echo ""
			echo "The servermoo init has been terminated"
			echo "Reason: no api key has been provided"
			echo ""

		fi

	else
		
		echo "The servermoo config file is already in $CONFIG_FILE"

	fi

}

# 
# Place the files in their locations
# This include agent.sh daemon.sh and plugins
# 
place_files() {
	
	# Create servermoo directory if not exists
	if [ ! -d $SERVERMOO_DIR ]; then
	
		mkdir $SERVERMOO_DIR
	
	fi

	# Copy the agent.sh into the scripts main directory
	if [ -f "$CURRENT_DIR/agent.sh" ]; then
	
		echo "Copy the agent file ..."
		cp -v $CURRENT_DIR/agent.sh $SERVERMOO_DIR 

		# Changing the file permissions
		chmod +x "$SERVERMOO_DIR/agent.sh"
	
	else 
	
		echo "Error: File agent.sh is not found in the current directory"
	
	fi

	# Move the daemon to it's location
	if [ -f "$CURRENT_DIR/daemon.sh" ]; then
	
		echo "Copy the daemon file ..."
		cp -v $CURRENT_DIR/daemon.sh "$DAEMON_DIR/servermoo" 
		
		# Changing the file permissions
		chmod +x "$DAEMON_DIR/servermoo"
	
	else 
		
		echo "Error: File daemon.sh is not found in the current directory"
	
	fi

	# Copy the plugins directory
	if [ -d "$CURRENT_DIR/plugins" ]; then
	
		echo "Copy the plugins ..." 
		cp -vR "$CURRENT_DIR/plugins" $SERVERMOO_DIR
	
	fi

	# Create the scripts directory
	if [ ! -d "$SERVERMOO_DIR/scripts" ]; then
	
		echo "Creating scripts directory ..." 
		mkdir -v "$SERVERMOO_DIR/scripts"
	
	fi

}

#
# Attempting to start the daemon and 
# adding it to the start sequence on boot
#
start_daemon() {
	
	# Debian and alike
	if [ -f /usr/sbin/update-rc.d ]; then
	
		update-rc.d servermoo defaults
	
	fi

	# RPM systems
	if [ -f /sbin/chkconfig ]; then
	
		chkconfig --add servermoo
		chkconfig servermoo on
	
	fi

	echo "Attempting to start the daemon..."

	# Start the daemon
	$DAEMON_DIR/servermoo start

}

# 
# Install the agent and daemon 
# 
install() {
	
	echo ""
	echo ""
	echo "#########################################################"
    echo "#                                                       #"
    echo "#                Servermoo installation                 #"
    echo "#                                                       #"
    echo "#########################################################"
	echo ""
	
	#
	# Request an api key from user input
	# 
	get_api_key
	if [ $? -ne 0 ]; then
		exit
	fi


	#
	# Try to place the files into the appropriate locations 
	# 
	place_files
	if [ $? -ne 0 ]; then
		exit
	fi

	start_daemon
	if [ $? -ne 0 ]; then
		exit
	fi
	
	echo "Servermoo instalation has been complete"

}

#
# Just calling the daemon uninstall option which will do the rest
#
uninstall() {

	if [ -f "$DAEMON_DIR/servermoo" ]; then 

		$DAEMON_DIR/servermoo uninstall

	fi

}

#switch between the cases
case "$1" in
  install)
    install
    ;;
  uninstall)
    uninstall
    ;;
  *)
	echo ""
    echo "Usage: $0 {install|uninstall}"
	echo ""
esac
