# Upload images from Stardot NetcamLive2 camera to TERN server

## via sFTP on non-standard port and SSH key authentication

*Markus Loew, University of Melbourne* *July 2026*

This script takes a RGB photo on the Stardot NetcamLive2 camera, switches to IR mode, takes an IR photo, and uploads both to the TERN server using sFTP. NDVI can later be calculated as `NDVI = (NIR - Red) / (NIR + Red)` from the corresponding RGB and IR images.

Use the camera web interface for the basic settings like admin password, timezone, and image overlay text. This script will not configure these settings!

The Stardot NetcamLive2 has a built-in SSH client. Unfortunately, the version that is used (`Dropbear v2016.74` for firmware `StarDot/NetCamLIVE- P130 VER 1.0.22-B9112` from 2024) can not handle other ports than the default 22! However, the TERN server is using port 2222 for sFTP! Therefore, this script creates a wrapper to use `ssh` to specify the port within the `sftp` command. The installed Dropbear `sftp` version does not allow to specify the `ssh` options inline, unfortunately. Therefore, the wrapper script is created each time the script runs and called from `sftp`.

**Alternatively**, specifying the ssh port via `user@server^2222` (using `^` instead of `:` (!) compared to the usual ssh syntax works in dropbear sftp (Suggested by Stardot support). E.g. `sftp -i /mnt/cfg1/camera_key user@server^2222` works. Then no wrapper script is needed (*not implemented in this script, though. This script is still using the wrapper script instead - offers more ssh options to be specified*)

No interactive shell is available on the TERN server. This requires the upload to be done via a batch file that holds all the commands needed to transfer the images. The batch file is created each time the script runs.

Connect to the camera via a terminal program. Use `ssh admin@192.168.xxx.xxx` to connect. You'll get prompted to type inthe password that you set earlier via the camera webinterface. Get the correct ipadress from your router. Within the TERN network, the camera ipaddress will start with 192.168.. 

After connection, before first use of the script, create the SSH key pair on the camera and copy the public key to the TERN server. The private key is stored in `/mnt/cfg1/camera_key`

Use `dropbearkey -t ecdsa -s 521 -f /mnt/cfg1/camera_key` to create the ssh key pair. The public key is in `/mnt/cfg1/camera_key.pub`

Use `dropbearkey -y -f /mnt/cfg1/camera_key` to display the public key in the format that can be added to the authorized_keys file on the TERN server. Send this public key to TERN support (Gerhard). Photo uploads can only take place after this key has been added to the TERN server!
Keep a copy of the private and public key in a safe location in case the camera memory gets wiped. Creating a new key on the camera requires to update the key on the TERN server as well. Hence, keep a copy of the keys in a safe location!

This script `upload_TERN.sh` is to be placed in the folder `/mnt/cfg1` on the camera file system. The script is following advice from Stardot regarding not wearing out the flash memory - hence it does not place any scripts with frequent read/writes outside of `/var/tmp`. Also, all images are stored in `/var/tmp` (see advanced settings in the camera webinterface for details on folders on the camera and wear and tear of the storage system). Only this script should be created/placed within the flash-storage at `/mnt/*` locations! All dynamic scripts that handle connection and upload are created as temporary files in `/var/tmp`. Images and the batch files are stored there as well. They are removed after successful uploads without wear on the flash memory due to space limitations.

All files in `/var/tmp` are lost when the camera loses power or when it reboots! Therefore all scripts are re-created from this upload script at runtime.

It is possible to add an optional micro SD-card to the camera if long-term storage is required that will survive camera reboots and power loss. In that case, adjust the `LOCAL_PHOTO_DIR` setting accordingly when storing images on an external SD-card - and remove the `rm -f" $LOCAL_PHOTO"` commands at the end of the script or images will still get deleted after successful upload!!

Use `chmod +x /mnt/cfg1/upload_TERN.sh` to make the script executable on the camera.

To run the script manually from the camera command line call: `/mnt/cfg1/upload_TERN.sh`

Edit the file `/mnt/cfg1/schedule/admin` to schedule the upload script to run at desired intervals. It uses `crontab` nomenclature. The `schedule` folder and files within are not lost during power outages or reboots. For example, to run every 30 minutes between 10:00 and 13:30 and once for 14:00 (default schedule for TERN phenocams), use the following commands to set up the schedule in the `../schedule/admin` file:

`echo "0,30 10-13 * * * /mnt/cfg1/upload_TERN.sh" > /mnt/cfg1/schedule/admin` 
`echo "0 14 * * * /mnt/cfg1/upload_TERN.sh" >> /mnt/cfg1/schedule/admin`

Reboot the camera (via its web interface, see "Reboot" button in "Advanced" settings) after editing the above crontab schedule to ensure the changes take effect. See "advanced" options in the camera webinterface.

The photos will appear on the TERN RDM file system within the `.Data/Ecoimages/camera/name/` folder of your site.