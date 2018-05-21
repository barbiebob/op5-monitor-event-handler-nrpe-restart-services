#!/bin/bash
#
# Event handler script for executing an NRPE command on a given host when a service
# is in CRITICAL and HARD state.
#
# Return with a passive check result to inform Web IU and logs about actions performed
#

# Binaries
MON="/usr/bin/mon"

# Declare variables
OK=0
CRITICAL=2

STATE=$1        # eg. "OK","CRITICAL,"WARNING","UNKNOWN"
STATETYPE=$2    # eg. "SOFT","HARD"
HOST=$3         # hostaddress of where to execute nrpe command
SERVICE=$4      # service display_name in OP5
COMMAND=$5      # NRPE command on client side
LOGFILE="/opt/monitor/var/eventhandler.log" # logfile to store executions by this eventhandler

# Set date format: "2016-03-29 13:10 CEST"
DATE=$(/bin/date +"%Y-%m-%d %H:%M %Z")

# Convert hostaddress & service_description to matching object in OP5
# Host
HOST_IN_OP5=$("$MON" query ls hosts -c name address -ri "$HOST")
# Make sure host was found
if [ ! -z "$HOST_IN_OP5" ] ; then
	/bin/echo -en "$DATE | CRITICAL: Could not find a matching host-object for "$HOST" in OP5 Monitor. Exiting.\n" >> $LOGFILE
	exit $CRITICAL
fi

# Service
SERVICE_IN_OP5=$("$MON" query ls services -c host_name,description display_name -ri "$SERVICE" | grep "$HOST_IN_OP5" | cut -d";" -f2)
# Make sure service was found
if [ ! -z "$SERVICE_IN_OP5" ] ; then
    /bin/echo -en "$DATE | CRITICAL: Could not find a matching service-object for "$SERVICE" on "$HOST" in OP5 Monitor. Exiting.\n" >> $LOGFILE
    exit $CRITICAL
fi

# Set date format: "2016-03-29 13:10 CEST"
DATE=$(/bin/date +"%Y-%m-%d %H:%M %Z")

# Only trigger on CRITICAL state
case "$STATE" in
    CRITICAL)
        # Only trigger on HARD state
        if [ "$STATETYPE" = "HARD" ] ; then
            /bin/echo -en "$DATE | ${0##*/} Got state: <$STATE> and statetype: <$STATETYPE> on service <$SERVICE> Trying to restart <$SERVICE> on <$HOST>\n" >> $LOGFILE

            # Execute NRPE command and choose action depending on EXIT-status
            if /opt/plugins/check_nrpe -s -u -H "$HOST" -c "$COMMAND" -a "$SERVICE" >> $LOGFILE ; then
                # Send passive result with successful message
                "$MON" qh query command run "[$(date +%s)] PROCESS_SERVICE_CHECK_RESULT;$HOST_IN_OP5;$SERVICE_IN_OP5;0;OK: INFO: Event handler successfully restarted $SERVICE."
                exit $OK

            else
                # Send passive result saying we failed
                "$MON" qh query command run "[$(date +%s)] PROCESS_SERVICE_CHECK_RESULT;$HOST_IN_OP5;$SERVICE_IN_OP5;2;CRITICAL: Event handler could not restart $SERVICE."
                exit $CRITICAL
            fi
        fi
    ;;
esac
