#!/bin/sh
# -------------------------------------------
# Markus Loew, University of Melbourne, 2026
# -------------------------------------------
# 
# Upload images from Stardot NetcamLive2 to TERN server using sFTP with SSH key authentication
#
# This script takes a RGB photo, switches to IR mode, takes an IR photo, and uploads both to the TERN server using sFTP.
# NDVI can later be calculated as NDVI = (NIR - Red) / (NIR + Red) from the corresponding RGB and IR images.
#
# Use the camera web interface for the basic settings like admin password, timezone, and image overlay text. 
# This script will not configure these settings.
# 
# The Stardot NetcamLive2 has a built-in SSH, but the version that is used (Dropbear v2016.74 for 
# firmware StarDot/NetCamLIVE- P130 VER 1.0.22-B9112) can not handle other ports than the default 22! 
# The TERN server is using port 2222 for sFTP! 
# Therefore, this script creates a wrapper to use ssh to specify the port within the sftp command.
# The wrapper script is created each time the script runs.
# 
# No interactive shell is availble on the TERN server. A batch file is created to upload the images. 
# The batch file is created each time the script runs.
#
# This script "upload_TERN.sh" is to be placed in /mnt/cfg1 on the camera file system. 
# Following the advice from Stardot regarding wearing out the flash memory do not place any scripts with frequent red/writes outside of /var/tmp
# (See advanced settings in the camera webinterface). 
# Only this script should be created at /mnt/* locations, everyting else should be created in /var/tmp/ to avoid wearing out the flash memory.
# Hence, all dynamic scripts are created as temporary files in /var/tmp to store the image and the batch file for sFTP
# without wear on the flash memory.
# 
# Use 
# chmod +x /mnt/cfg1/upload_TERN.sh 
# to make the script executable.
#
# To run the script manually: /mnt/cfg1/upload_TERN.sh
#
# Edit /mnt/cfg1/schedule/admin to schedule the script to run at desired intervals. It uses crontab nomenclature.
# For example, to run every 30 minutes between 10:00 and 14:00, add the following:
# 0,30 10-14 * * * /mnt/cfg1/upload_TERN.sh
# Reboot the camera after editing the crontab to ensure the changes take effect. See "advanced" options in the camera webinterface.

# -------------------------
# Configuration
# -------------------------

# Site name (default AU-Boo)
LOCATION="${1:-AU-Boo}"
# view id (default overstorey_oblique_01) see https://ternaus.atlassian.net/wiki/spaces/TERNSup/pages/2629730756/Phenocam for options
VIEW_ID="${2:-overstorey_oblique_01}"
# local volatile directory to store the photos and dynamic scripts temporarily
LOCAL_PHOTO_DIR="/var/tmp"
# Username on TERN server, usually the same as camera name. Check with TERN (Gerhard) to decide on the username!
# For the camera name, see the camera webinterface "Hostname" entry in basic settings, network tab. 
# Default name is a combination of camera model and last digits of the MAC address.
REMOTE_USER="netcamlive-3B0423"
# TERN server address. The port 2222 is specified in the SSH wrapper script as the embedded dropbear sftp version can not handle it internally.
REMOTE_HOST="sftp.tern.org.au"
REMOTE_PATH="."
# REMOTE PORT 2222 is hardcoded to 2222 in the SSH wrapper script!
#REMOTE_PORT=2222
# FLux towers usually upload their data at half-hourly intervals. To avoid overloading the network connection, a delay of 5 minutes is added before the first upload attempt. Upload of 10 Hz data from the flux tower is usually done within 4  minutes intervals. Upload of 20 Hz TOA5 file can take up to 9 minutes. Adjust UPload delay accordingly.
UPLOAD_DELAY=300
# before first use, create the SSH key pair on the camera and copy the public key to the TERN server. The private key is stored in /mnt/cfg1/camera_key
# use  dropbearkey -t ecdsa -s 521 -f /mnt/cfg1/camera_key to create the ssh key pair. The public key is in /mnt/cfg1/camera_key.pub
# use dropbearkey -y -f /mnt/cfg1/camera_key to get the public key in the format that can be added to the authorized_keys file on the TERN server. Send this public key to TERN support (Gerhard).
SSH_KEY="/mnt/cfg1/camera_key"
SSH_WRAPPER="/tmp/ssh-wrapper.sh"
BATCH_FILE="/tmp/sftp-batch.txt"
LOG_FILE="/tmp/upload-photo.log"

# ------------------
# End configuration
# ------------------

# Generate timestamp and filename following the TERN Phenocam naming convention.
# Netcamm Live2 does not provide exif data that usually used to extract metadata.
# Hence the filename and timestamp must follow the convention. 
TIMESTAMP=$(date +"%Y-%m-%d-%H-%M-%S")

# local file locations
LOCAL_PHOTO="$LOCAL_PHOTO_DIR/${LOCATION}_${VIEW_ID}_${TIMESTAMP}.jpg"
LOCAL_PHOTO_IR="$LOCAL_PHOTO_DIR/${LOCATION}_${VIEW_ID}_${TIMESTAMP}_IR.jpg"
REMOTE_PHOTO="$REMOTE_PATH/${LOCATION}_${VIEW_ID}_${TIMESTAMP}.jpg"
REMOTE_PHOTO_IR="$REMOTE_PATH/${LOCATION}_${VIEW_ID}_${TIMESTAMP}_IR.jpg"

echo "=== Script Start ===" | tee -a "$LOG_FILE"
echo "TIMESTAMP: $TIMESTAMP" | tee -a "$LOG_FILE"
echo "LOCAL_PHOTO: $LOCAL_PHOTO" | tee -a "$LOG_FILE"
echo "REMOTE_PHOTO: $REMOTE_PHOTO" | tee -a "$LOG_FILE"

# Create SSH wrapper script
echo "Creating SSH wrapper..." | tee -a "$LOG_FILE"

cat > "$SSH_WRAPPER" << 'WRAPPER'
#!/bin/sh
exec /usr/bin/ssh -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$@"
WRAPPER

chmod +x "$SSH_WRAPPER"
echo "SSH wrapper created at: $SSH_WRAPPER" | tee -a "$LOG_FILE"

# Capture photo from camera
echo "Capturing RGB photo..." | tee -a "$LOG_FILE"
/usr/sbin/set_ir.sh 0
echo "Waiting for camera to set RGB mode..." | tee -a "$LOG_FILE"
sleep 30
wget http://127.0.0.1/image.jpg -O "$LOCAL_PHOTO" >/dev/null 2>/dev/null

# Check if photo was captured successfully
if [ ! -f "$LOCAL_PHOTO" ]; then
    echo "Error: Failed to capture image" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Image captured successfully" | tee -a "$LOG_FILE"
ls -lh "$LOCAL_PHOTO" | tee -a "$LOG_FILE"

# Capture image from camera
echo "Capturing IR image..." | tee -a "$LOG_FILE"
/usr/sbin/set_ir.sh 1
echo "Waiting 30 seconds for IR mode..." | tee -a "$LOG_FILE"
sleep 30
wget http://127.0.0.1/image.jpg -O "$LOCAL_PHOTO_IR" >/dev/null 2>/dev/null 

# Check if image was captured successfully
if [ ! -f "$LOCAL_PHOTO_IR" ]; then
    echo "Error: Failed to capture IR image" | tee -a "$LOG_FILE"
    exit 1
fi

# switch back to RGB mode - no sleep delay here
# /usr/sbin/set_ir.sh 0

echo "IR image captured successfully" | tee -a "$LOG_FILE"
ls -lh "$LOCAL_PHOTO_IR" | tee -a "$LOG_FILE"


# Create SFTP batch file
echo "Creating SFTP batch file..." | tee -a "$LOG_FILE"
echo "put $LOCAL_PHOTO $REMOTE_PHOTO" > "$BATCH_FILE"
echo "put $LOCAL_PHOTO_IR $REMOTE_PHOTO_IR" >> "$BATCH_FILE"
echo "quit" >> "$BATCH_FILE"

echo "Batch file created at: $BATCH_FILE" | tee -a "$LOG_FILE"
cat "$BATCH_FILE" | tee -a "$LOG_FILE"

echo "Waiting $UPLOAD_DELAY seconds before upload..." | tee -a "$LOG_FILE"
sleep "$UPLOAD_DELAY"

# Upload images via SFTP
echo "Starting SFTP upload..." | tee -a "$LOG_FILE"
echo "Command: sftp -S $SSH_WRAPPER -i $SSH_KEY -b $BATCH_FILE $REMOTE_USER@$REMOTE_HOST" | tee -a "$LOG_FILE"

sftp -S "$SSH_WRAPPER" -i "$SSH_KEY" -b "$BATCH_FILE" "$REMOTE_USER@$REMOTE_HOST" 2>&1 | tee -a "$LOG_FILE"

UPLOAD_STATUS=$?

echo "SFTP exit code: $UPLOAD_STATUS" | tee -a "$LOG_FILE"

# Check upload status
if [ $UPLOAD_STATUS -eq 0 ]; then
    echo "Image uploaded successfully: $REMOTE_PHOTO" | tee -a "$LOG_FILE"
    echo "Image uploaded successfully: $REMOTE_PHOTO_IR" | tee -a "$LOG_FILE"
    rm -f "$LOCAL_PHOTO"
    rm -f "$LOCAL_PHOTO_IR"
    rm -f "$BATCH_FILE"
    echo "Cleanup complete" | tee -a "$LOG_FILE"
    exit 0
else
    echo "Error: Upload failed (exit code: $UPLOAD_STATUS)" | tee -a "$LOG_FILE"
    echo "Local image still at: $LOCAL_PHOTO" | tee -a "$LOG_FILE"
    echo "Local IR image still at: $LOCAL_PHOTO_IR" | tee -a "$LOG_FILE"
    exit 1
fi