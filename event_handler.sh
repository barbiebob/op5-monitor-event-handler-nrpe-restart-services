#!/bin/bash
#
# "THE BEER-WARE LICENSE" - - - - - - - - - - - - - - - - - -
# This file was initially written by Robert Claesson.
# As long as you retain this notice you can do whatever you
# want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return.
# - - - - - - - - - - - - - - - robert.claesson@gmail.com - -
#
# Event handler script for executing an NRPE command on a given host when a service
# is in CRITICAL and HARD state.
#
# Return with a passive check result to inform Web IU and logs about actions performed
#

# Binaries
mon=$(which mon)

# Declare variables
ok=0
critical=2
unknown=3

state=$1        # eg. "OK","CRITICAL,"WARNING","UNKNOWN"
statetype=$2    # eg. "SOFT","HARD"
host=$3         # hostaddress of where to execute nrpe command
service=$4      # service display_name in OP5
nrpe_command=$5      # NRPE command on client side
logfile="/opt/monitor/var/eventhandler.log" # logfile to store executions by this eventhandler

# Check that script was run on a OP5-server
if [[ -z "$mon" ]]
then
	echo "Could not find mon binary, was this script executed on a OP5-server?"
	exit "$unknown"
fi

# Set date format: "2016-03-29 13:10 CEST"
date=$(/bin/date +"%Y-%m-%d %H:%M %Z")

# Convert hostaddress & service_description to matching object in OP5
# Host
host_in_op5=$("$mon" query ls hosts -c name address -ri "$host")
# Make sure host was found
if [ ! -z "$host_in_op5" ]
then
	/bin/echo -en "$date | CRITICAL: Could not find a matching host-object for $host in OP5 Monitor. Exiting.\n" >> $logfile
	exit $critical
fi

# Service
service_in_op5=$("$mon" query ls services -c host_name,description display_name -ri "$service" | grep "$host_in_op5" | cut -d";" -f2)
# Make sure service was found
if [ ! -z "$service_in_op5" ]
then
	/bin/echo -en "$date | CRITICAL: Could not find a matching service-object for $service on $host in OP5 Monitor. Exiting.\n" >> $logfile
	exit $critical
fi

# Set date format: "2016-03-29 13:10 CEST"
date=$(/bin/date +"%Y-%m-%d %H:%M %Z")

# Only trigger on CRITICAL state
case "$state" in
	CRITICAL)
		# Only trigger on HARD state
		if [ "$statetype" = "HARD" ]
		then
			/bin/echo -en "$date | ${0##*/} Got state: <$state> and statetype: <$statetype> on service <$service> Trying to restart <$service> on <$host>\n" >> $logfile

			# Execute NRPE command and choose action depending on EXIT-status
			if /opt/plugins/check_nrpe -s -u -H "$host" -c "$nrpe_command" -a "$service" >> $logfile
			then

				# Send passive result with successful message
				"$mon" qh query command run "[$(date +%s)] PROCESS_SERVICE_CHECK_RESULT;$host_in_op5;$service_in_op5;0;OK: INFO: Event handler successfully restarted $service."
				exit $ok

			else
				# Send passive result saying we failed
				"$mon" qh query command run "[$(date +%s)] PROCESS_SERVICE_CHECK_RESULT;$host_in_op5;$service_in_op5;2;CRITICAL: Event handler could not restart $service."
				exit $critical
			fi
		fi
	;;
esac
