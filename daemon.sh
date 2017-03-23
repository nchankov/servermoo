#!/bin/bash
#
# servermoo 	Servermoo daemon
# 
# chkconfig: 234 64 36
# description:  Servermoo monitoring agent daemon
# processname: servermoo
# config: /etc/servermoo.api
# pid_file: /var/run/servermoo.pid
# 
### BEGIN INIT INFO
# Provides:          servermoo
# Required-Start:    $network $syslog
# Required-Stop:     $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start servermoo agent at boot time
### END INIT INFO

######################################################
#                                                    #
# Servermoo daemon                                   #
# for more information visit:                        #
# https://servermoo.com/docs                         #
#                                                    #
######################################################

CONFIG_FILE="/etc/servermoo.conf"

#
# include the configuration file
# 
source $CONFIG_FILE

#
# The script which we will execute
#
SCRIPT="$SERVERMOO_DIR/agent.sh"

#
# Attempt to remove the daemon from the booth sequence
remove_daemon() {

	echo "Attempting to remove the daemon..."
	
	# Debian and alike
	if [ -f /usr/sbin/update-rc.d ]; then
	
		update-rc.d -f servermoo remove
	
	fi

	# RPM systems
	if [ -f /sbin/chkconfig ]; then
	
		chkconfig servermoo off
		chkconfig --del servermoo
	
	fi

}

#
# Start the daemon
#
start() {

	if [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE"); then

		echo "Service already running." >&2

		return 1

	fi

	echo 'Starting the service...' >&2

	local CMD="$SCRIPT &> \"$LOG_FILE\" & echo \$!"

	su -c "$CMD" $RUNAS > "$PID_FILE"

	echo 'Service started' >&2

}

#
# Stop the daemon
# 
stop() {

	if [ ! -f "$PID_FILE" ] || ! kill -0 $(cat "$PID_FILE"); then
		
		echo 'Service not running' >&2
		
		return 1
	
	fi
	
	echo 'Stopping the service...' >&2
	
	kill -15 $(cat "$PID_FILE") && rm -f "$PID_FILE"
	
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
		remove_daemon
		
		# Remove the main agent file
		if [ -f $SCRIPT ]; then
			
			rm -fv $SCRIPT
		
		fi

		# Check if the commands directory is empty if so, remove it
		# otherwise keep it 
		if [ ! "$(ls -A $SCRIPTS_DIR)" ]; then
			
			rmdir -v $SCRIPTS_DIR
		
		fi

		# Remove plugins directory if it's empty 
		if [ ! "$(ls -A $PLUGINS_DIR)" ]; then
			
			rmdir -v $PLUGINS_DIR
		
		fi

		if [ -f $CONFIG_FILE ]; then
			rm -fv $CONFIG_FILE
		fi
		# Removing the daemon itself
		rm -fv "$0"
		
		echo ""
		echo "All files has been removed except:" >&2
		echo "'$LOG_FILE'" >&2
		
		# Check if the commands stil exists if so print a message
		# that it is still there
		if [ -d $SCRIPTS_DIR ]; then
			echo "'$SCRIPTS_DIR'" >&2
		fi 
		if [ -d $PLUGINS_DIR ]; then
			echo "'$PLUGINS_DIR'" >&2
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
