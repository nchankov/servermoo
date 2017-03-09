#!/bin/bash

#########################################
#                                       #
# Servermoo daemon                      #
# for more information visit:           #
# https://servermoo.com/about           #
#                                       #
#########################################

#
# Location of the agent file
#
AGENT_URL="https://raw.githubusercontent.com/nchankov/servermoo/master/agent.sh"

#
# Location of the daemon file
#
DAEMON_URL="https://raw.githubusercontent.com/nchankov/servermoo/master/daemon.sh"


#
# Location where the api key will be stored
#
API_LOCATION="/etc/servermoo.api"

#
# Location of the commands
# 
COMMANDS_LOCATION="/etc/servermoo/"

#
# Agent Location
#
AGENT_LOCATION="/usr/bin/servermoo.sh"

#
# Daemon Location
#
DAEMON_LOCATION="/etc/init.d/servermoo"


#
# Asking for api key and store it in to a file file
#
get_api_key() {
	
	if [ ! -f "$API_LOCATION" ]; then
		
		echo ""
		
		# Ask the user to provide the api key
		read -p "Please provide your api key: " api
		
		# Check if the user pass any info
		if [ ! -z "$api" ]; then
			
			# Store the api key to the predefined location
			echo $api > $API_LOCATION
			echo "The api key has been stored in $API_LOCATION"
		
		else
			
			# If there is no api key provided print a message and stop here
			echo ""
			echo "The servermoo init has been terminated"
			echo ""

		fi

	else
		
		echo "The api key is already in $API_LOCATION"
	
	fi
}

# 
# Install the agent and daemon 
# 
install() {
	
	# Create a temp file
	SERVICE_FILE=$(mktemp)

	echo ""
	echo ""
	echo "#########################################################"
    echo "#                                                       #"
    echo "#                Servermoo installation                 #"
    echo "#                                                       #"
    echo "#########################################################"
	echo ""

	echo "Downloading the servermoo.sh agent ..."
	
	# Downloading the file
	curl -s -o "$SERVICE_FILE" $AGENT_URL
	
	# Changing the file permissions
	chmod +x "$SERVICE_FILE"

	# Move the file to it's location
	mv -v $SERVICE_FILE $AGENT_LOCATION
	

	echo "Downloading the servermoo.sh daemon ..."
	
	# Download the daemon
	curl -s -o "$SERVICE_FILE" $DAEMON_URL
	
	# Changing the file permissions
	chmod +x "$SERVICE_FILE"
	
	# Move the file to it's location
	mv -v $SERVICE_FILE $DAEMON_LOCATION

	#ask for api key and store it
	get_api_key

	if [ -f "$API_LOCATION" ]; then
		
		if [ ! -d $COMMANDS_LOCATION ]; then
			
			echo "Creating storage for commands"
			
			mkdir -v $COMMANDS_LOCATION

		fi

		echo "Installation has been complete"

		# Attempting to add the daemon into startup scripts so it will
		# start on boot
		
		# Debian and alike
		if [ -f /usr/sbin/update-rc.d ]; then
			update-rc.d servermoo defaults
		fi

		if [ -f /sbin/chkconfig ]; then
			chkconfig --add servermoo
			chkconfig servermoo on
		fi

		echo "Attempting to start the daemon..."

		# Start the daemon
		$DAEMON_LOCATION start
	fi
}

#
# Just calling the daemon uninstall option which will do the rest
#
uninstall() {
	if [ -f $DAEMON_LOCATION ]; then 
		$DAEMON_LOCATION uninstall
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
