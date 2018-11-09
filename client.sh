#!/bin/bash

# USB drive monitoring script

# Save current process ID
PIDFILE="/tmp/client.pid"
if [[ ! -f $PIDFILE ]]; then
	echo "No PIDfile found"
	> "$PIDFILE"
fi

# Process handling 
if ps -p "$(< $PIDFILE)" &> /dev/null; then
	echo "Process already running"
	echo $(< $PIDFILE) && exit 0
else
	echo "Saving PID and proceeding"
	echo "$$" > "$PIDFILE"
fi

# Filesystem mount path
MNTPATH="/tmp/test"

# Server signal socket
SOCKET="/tmp/client_socket.ini"

# Remote server
SERVER="127.0.0.1"

# Remote service URI
SERVER_URI="http://$SERVER/service/index.php"

# Flush environment
flush() {

	# Client-side username
	USER="$(whoami)"

	# USB virtual device
	USBDEV=""

	# USB partitions
	USBPART=""

	# USB partition type
	USBFSTYPE=""
	
}

# Send status message to server
send_message() {

	echo $1
	# write message to file
	echo "client_message=$1" > "$SOCKET"

	# send to server
	scp "$SOCKET" "$SERVER:$SOCKET" &> /dev/null

	sleep 5
}

# Get server status
get_server_status() {
	SOURCE_PATH="$(curl $SERVER_URI?source_path 2> /dev/null)"

	DATA_READY="$(curl $SERVER_URI?data_ready 2> /dev/null)"

	DATA_AMOUNT="$(curl $SERVER_URI?data_amount 2> /dev/null)"
}

# Download data from server to USB
get_data() {
	for (( i = 1; i < 5; i++ )); do

		send_message "Transferring data..."

		if rsync -qurP -e 'ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' "$USER@$SERVER:$SOURCE_PATH" "$MNTPATH/"; then
			i=5; # break loop
		fi

	done
}

get_device_name() {
	while [[ -z $USBDEV ]]; do
		send_message "Please insert USB drive..."
		USBDEV="$(lsblk -pln -o name,tran | grep usb | cut -d ' ' -f1)"
	done
}

get_partition_name() {
	USBPART=$(lsblk -l -p -o name,type "$1" | grep part | cut -d ' ' -f1)
}

get_filesystem_type() {
	USBFSTYPE=$(lsblk -l -n -p -o fstype "$1")
}

get_partition_size() {
	USBPARTSIZE=$(sudo df -a --output=avail "$1" | tail -n 1)
}

check_filesystem() {
	sudo fsck."$1" -a "$2" &> /dev/null
}

check_server_path() {
	if [[ -n $SOURCE_PATH ]]; then
		return 0
	else
		send_message "Can't get data source path from server"
		return 1
	fi
}

check_partition_size() {
	if [[ -n $DATA_AMOUNT ]]; then
		(( $USBPARTSIZE > $DATA_AMOUNT )) && return 0
	else
		send_message "Space on USB drive isn't enough"
		return 1
	fi
}

mount_partition() {
	for (( i = 1; i < 5; i++ )); do

		# check if already mounted
		if mount | grep -q "$MNTPATH"; then
			i=5; # break loop
			return 0
		# else try to mount
		else
			send_message "Mounting partition..."
			sudo mount -o uid=$(id -u $USER),gid=$(id -g $USER) "$1" "$MNTPATH"
		fi

	done

	if mount | grep -q "$MNTPATH"; then
		return 0
	else
		send_message "Can't mount partition, please contact support"
		return 1
	fi
}

unmount_partition() {
	while mount | grep -q "$1"; do
		send_message "Unmounting partition..."
		sudo umount "$1" && return 0
	done
}

# Initialize environment for the first time
flush; 

# Detect plugged in USB drive
get_device_name && send_message "Detected disk: $USBDEV"

# Search disk partitions
if lsblk "$USBDEV" | grep -q part; then

	get_partition_name "$USBDEV"
	get_filesystem_type "$USBPART"
	get_partition_size "$USBPART"
	check_filesystem "$USBFSTYPE" "$USBPART"

	send_message "Partition: $USBPART"

elif lsblk "$USBDEV" &> /dev/null; then

	send_message "USB drive not partitioned."
	exit 1

fi

# Check if mount path exists, re-create if not
[[ ! -d $MNTPATH ]] && mkdir "$MNTPATH"

# Expect OK from server to download data
while [[ $DATA_READY != "yes" ]]; do
	send_message "Expecting OK from server to download..."
	get_server_status
done

check_server_path || exit 1
check_partition_size || exit 1

# Try to mount partition
mount_partition "$USBPART"
lsblk -n "$USBPART" && send_message "Partition mounted"

#**********************************	
# !!! WRITE DATA !!!
#get_data && send_message "Data successfully written"
# !!! END WRITING DATA !!!
#**********************************

# Try to unmount partition
unmount_partition "$USBPART" && echo "Partition unmounted"
	
send_message "USB drive can be removed now"

exit 0
