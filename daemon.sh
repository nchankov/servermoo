#!/bin/bash
#
# servermoo 	Servermoo daemon
# 
# chkconfig: - 64 36
# description:  Servermoo monitoring agent daemon
# processname: servermoo
# config: /etc/servermoo.api
# pidfile: /var/run/servermoo.pid
# 

######################################################
#                                                    #
# Servermoo daemon                                   #
# for more information visit:                        #
# https://servermoo.com/docs                         #
#                                                    #
######################################################

#
# The script which we will execute
#
SCRIPT=/usr/bin/servermoo.sh

#
# The user which will be used to execute the script
# By default it's root and it's important to be
# "powerful" enough so if can run the commands from
# /etc/servermoo/ directory.
# 
# If you don't intend to use the commands you can change this
# to someother user
#
RUNAS=root

#
# Pid file of servermoo it will indicate whether the daemon is 
# working or not
#
PIDFILE=/var/run/servermoo.pid

#
# Log file of the servermoo
#
LOGFILE=/var/log/servermoo.log

#
# Where is the api key
#
API_LOCATION=/etc/servermoo.api

#
# Location of the command files
# 
# For more information about commands see
# https://servermoo.com/docs
# 
COMMANDS_LOCATION=/etc/servermoo

#
# Start the daemon
#
start() {

	if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE"); then

		echo "Service already running." >&2

		return 1

	fi

	echo 'Starting the service...' >&2

	local CMD="$SCRIPT &> \"$LOGFILE\" & echo \$!"

	su -c "$CMD" $RUNAS > "$PIDFILE"

	echo 'Service started' >&2

}

#
# Stop the daemon
# 
stop() {

	if [ ! -f "$PIDFILE" ] || ! kill -0 $(cat "$PIDFILE"); then
		
		echo 'Service not running' >&2
		
		return 1
	
	fi
	
	echo 'Stopping the service...' >&2
	
	kill -15 $(cat "$PIDFILE") && rm -f "$PIDFILE"
	
	echo 'Service stopped' >&2 

}

#
# Uninstall the daemon by removing the daemon from rc.d sequence
# and removing the daemon file
#
uninstall() {
	local sure
  
	echo ""
	echo -n "Are you really sure you want to uninstall servermoo daemon? [y|N] "
  
	read sure
  
	# Check if the user confirm the uninstall process
	if [ "$sure" = "yes" ] || [ "$sure" = "y" ] || [ "$sure" = "Y" ]; then
	
		# Stop the running service (if it's running)
		stop

		# Removing daemon from boot sequence
		
		if [ -f /usr/sbin/update-rc.d ]; then
			update-rc.d -f servermoo remove
		fi

		if [ -f /sbin/chkconfig ]; then
			chkconfig --del servermoo
		fi
		
		# Remove the main agent file
		if [ -f $SCRIPT ]; then
			
			rm -fv $SCRIPT
		
		fi

		# Remove the api key file
		if [ -f $API_LOCATION ]; then
			
			rm -fv $API_LOCATION
		
		fi

		# Check if the commands directory is empty if so, remove it
		# otherwise keep it 
		if [ ! "$(ls -A $COMMANDS_LOCATION)" ]; then
			
			rmdir -v $COMMANDS_LOCATION
		
		fi

		# Removing the daemon itself
		rm -fv "$0"
		
		echo ""
		echo "All files has been removed except:" >&2
		echo "'$LOGFILE'" >&2
		
		# Check if the commands stil exists if so print a message
		# that it is still there
		if [ -d $COMMANDS_LOCATION ]; then
		
			echo "'$COMMANDS_LOCATION'" >&2
		
		fi 
		
		echo ""
		echo "#########################################################"
		echo "#                                                       #"
		echo "#            Thank you for using servermoo              #"
		echo "#                                                       #"
		echo "#########################################################"
		echo ""

	fi

}


case "$1" in
  start)
	start
	;;
  stop)
	stop
	;;
  uninstall)
	uninstall
	;;
  restart)
	stop
	start
	;;
  *)
	echo "Usage: $0 {start|stop|restart|uninstall}"
esac
