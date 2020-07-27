#!/bin/bash

LOGDIR="/var/log/spotifyd"
LOGFILE="$LOGDIR/spotifyd-runner.log"
MAX_LOG_SIZE="2048" #in KB
SPOTIFYD="/usr/local/bin/spotifyd"  # not found?  try 'brew cask link spotifyd'
PIDFILE=$( mktemp /tmp/.spotifyd-runner-pid.XXXXX ) # e.g., /tmp/.spotifyd-runner-pid.CJjwn
MY_PID=$$

# we'll create the pid file again later -- its early presence will affect logic that kills
# other instances of this script
rm $PIDFILE 

ts() {
	date +'%m/%d/%Y %H:%M:%S'
}

die() {
	log "ERROR:  $1"
	exit 1
}

is_mac_os() {
	if [[ ! $( uname | tr 'a-z' 'A-Z' ) =~ ^DARWIN$ ]]; then 
		die "This script is for use with MacOS only."
	fi
}

log() {
	echo -e "$1" | sed -e "s#^#\[`ts`\] $$ - #"| tee -a $LOGFILE
}

rotate_log() {
	SIZE_IN_KB=$( du -k | cut -f1 )
	if [ $SIZE_IN_KB -gt $MAX_LOG_SIZE ]; then
		log "ROTATING LOGFILE..."
		mv -f $LOGFILE ${LOGFILE}.1
	fi
}

# another instance of spotifyd could have been started by 'brew services...' 
# or manually -- kill that process and warn user
kill_spotifyd() {
	local PS_LIST=$( ps -eo pid,command \
		| egrep -E "\d+\s+($SPOTIFYD|`basename $SPOTIFYD`)" )
	if [ ! -z "$PS_LIST" ]; then
		PS_LIST=$( echo $PS_LIST | head -1 | sed -e 's/^\s+//' )
		local S_PID=$( echo $PS_LIST | awk '{ print $1 }' )
		local MSG="$SPOTIFYD is already running:  PID=${S_PID}  Perhaps it's running as a brew"
	        MSG="$MSG service?\nHint:  'brew services stop spotifyd' will stop and disable the service."
		log "$MSG"
		log "Killing spotifyd PID $S_PID..."
		kill $S_PID

		# recursive call to self -- we only killed first matching process,
		# re-run to get others, if they exist (theoretically, they shouldn't due to a 
		# listening port having already been in use when such a process would've started
		kill_spotifyd
	else
		# zero processes matching $SPOTIFYD; this also serves as the base case to 
		# stop recursion in the if statement above.)
		log "No $SPOTIFYD instances appear to be running, proceeding with startup."
	fi
}

# (a) guarantee no other instances of this script are running
# (b) spotifyd could have been started by another process; kill & warn
kill_other_instance() {
	local OTHER_PIDFILE=$( ls /tmp/.spotifyd-runner-pid.* 2>/dev/null | head -1 )
	if [ -r "$OTHER_PIDFILE" ]; then
		local OTHER_PID=$( head -1 "$OTHER_PIDFILE" )
		log "Found PID $OTHER_PID to be associated with concurrent or past instance of this script."
		if ps -p $OTHER_PID >/dev/null; then
			log "PID $OTHER_PID still active -- killing it."
			kill -9 $OTHER_PID
		else 
			log "Stale PID file from prior run of this script found, removing."
		fi
		rm "$OTHER_PIDFILE"

		# recurse -- other pid files might need to be processed
		kill_other_instance
	else 
		# no more instances of the script to kill -- now kill any running spotifyd processes
		kill_spotifyd
	fi
}

logdir_die() {
	local WHOAMI=$( whoami )
	local MSG="Cannot write to directory $LOGDIR for logging.  Make sure account $WHOAMI can write there:"
	MSG="$MSG\n\n\t$ sudo mkdir -p -m 755 $LOGDIR"
	MSG="$MSG\n\t$ sudo chown $WHOAMI $LOGDIR\n"
	echo -e "$MSG"
	exit 1
}

cleanup() {
	if [ -e "$PIDFILE" ]; then
		rm "$PIDFILE"
	fi
	exit
}
trap cleanup EXIT


# pre-flight checks #
[ -w $LOGDIR ] || logdir_die
is_mac_os
[ -x $SPOTIFYD ] || die "Cannot find or execute $SPOTIFYD."
# end pre-flight checks #

kill_other_instance
echo $MY_PID > $PIDFILE

while true; do
	log "Starting spotifyd ($SPOTIFYD)"	
	$SPOTIFYD --no-daemon | tee -a $LOGFILE

	# it crashed :(
	log "ERROR:  $SPOTIFYD appears to have crashed; will restart in a moment."

	sleep 1
done
