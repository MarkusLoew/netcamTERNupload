---------------------------
Netcam image upload to TERN
---------------------------
 
Upload images from Stardot NetcamLive2 to TERN server using sFTP with SSH key authentication
This script takes a RGB photo, switches to IR mode, takes an IR photo, and uploads both to the TERN server using sFTP.
NDVI can later be calculated as NDVI = (NIR - Red) / (NIR + Red) from the corresponding RGB and IR images.

Use the camera web interface for the basic settings like admin password, timezone, and image overlay text. 
This script will not configure these settings.

The Stardot NetcamLive2 has a built-in SSH, but the version that is used (Dropbear v2016.74 for 
firmware StarDot/NetCamLIVE- P130 VER 1.0.22-B9112) can not handle other ports than the default 22! 
The TERN server is using port 2222 for sFTP! 
Therefore, this script creates a wrapper to use ssh to specify the port within the sftp command.
The wrapper script is created each time the script runs.
 
No interactive shell is availble on the TERN server. A batch file is created to upload the images. 
The batch file is created each time the script runs.

This script "upload_TERN.sh" is to be placed in /mnt/cfg1 on the camera file system. 
Following the advice from Stardot regarding wearing out the flash memory do not place any scripts with frequent red/writes outside of /var/tmp
(See advanced settings in the camera webinterface). 
Only this script should be created at /mnt/* locations, everyting else should be created in /var/tmp/ to avoid wearing out the flash memory.
Hence, all dynamic scripts are created as temporary files in /var/tmp to store the image and the batch file for sFTP
without wear on the flash memory.
 
Use 
chmod +x /mnt/cfg1/upload_TERN.sh 
to make the script executable.

To run the script manually: /mnt/cfg1/upload_TERN.sh

Edit /mnt/cfg1/schedule/admin to schedule the script to run at desired intervals. It uses crontab nomenclature.
For example, to run every 30 minutes between 10:00 and 14:00, add the following:
0,30 10-14 * * * /mnt/cfg1/upload_TERN.sh
Reboot the camera after editing the crontab to ensure the changes take effect. See "advanced" options in the camera webinterface.
