#!/bin/sh
# Lenovo EMC USB recovery firmware image maker.
# Finally had time to write this. Might come in handy now support for these products has ended. Did support ever really begin?
# Make a folder and put this script in it along with your firmware image downloaded from lenovo and run. Good luck!
# Search google for 'http://download.lenovo.com/nas/lifeline' if you don't already have a firmware for your device.
# Notes/info at end of script.
# 
clear
echo ' __________________________________________________'
echo "|   Lenovo EMC USB recovery firmware image maker   |"
echo '|__________________________________________________|'
pause(){ read -n 1 -s -r -p "    Press any key to continue."; echo; }
# FW_ENC=filename of downloaded encrypted firmware
FW_ENC=$(ls *.tgz)
# Decrypt firmware
if [ ! -f "$FW_ENC" ]; then
    echo "    No firmware found."; echo "    Terminating program."; exit
	  else
    FW_CODE=$(echo "$FW_ENC" | awk -F '-' '{print $1}')
    echo "    Found firmware file $FW_ENC."
	  echo "    Decrypting and unpacking firmware."
    openssl enc -d -md md5 -aes-128-cbc -in "$FW_ENC" -k "EMCNTGSOHO" -out "${FW_ENC%.tgz}-decrypted.tar.gz" 2>/dev/null
    fi
rm -Rf extracted; mkdir -p extracted
tar xzvf "${FW_ENC%.tgz}-decrypted.tar.gz" -C extracted/ >/dev/null
rm "${FW_ENC%.tgz}-decrypted.tar.gz"
rm -Rf apps; mkdir -p apps
rm -f /dev/loop3
mknod -m0660 /dev/loop3 b 7 3
mount -o loop,rw extracted/apps apps
sleep 1
if [ -f "apps/usr/local/cfg/Firmware.xml" ]; then
    model=$(cat "apps/usr/local/cfg/Firmware.xml" | grep 'Model=' | awk -F '"' '{print $4}')
    echo "    Detected firmware for $model."
    fi
cp -p apps/usr/local/cfg/config.gz extracted/
echo "    Extraction complete. Now to rebuild the image."

# Uncomment if you intend to replace any images with custom stuff. 
#pause 

while true; do sleep 3; umount apps 2>/dev/null; if [ ! $? -eq 0 ]; then break; fi; done
rm -Rf apps
gunzip extracted/config.gz
touch extracted/config.md5
echo "    Regenerating firmware MD5 checksums."
imgs="$(find extracted)"
for img in ${imgs} ; do
    if [ -f $img.md5 ] ; then
        md5="$(md5sum $img)"
        md5="${md5% *}"
        md5="${md5% }"
    echo "$md5" > "$img.md5"
    fi
done
echo "    Building USB recovery firmware image."
rm -Rf usb; mkdir -p usb/images
cp extracted/initrd usb/images
cp extracted/zImage usb/images
mkdir -p "usb/emctools/"$FW_CODE"_images"

# Uncomment to preserve drive data. Hard men don't do backups but they cry alot.
#touch "emctools/"$FW_CODE"_images/noreinstall"

# Uncomment to preserve temp folder.
#touch "emctools/"$FW_CODE"_images/noextraction"

cd extracted
tar czvf "../usb/emctools/"$FW_CODE"_images/${FW_ENC%.tgz}_imager.tgz" * > /dev/null
sleep 1
cd ..
rm -Rf extracted
[ -f "${FW_ENC%.tgz}-usb-recovery.zip" ] && rm "${FW_ENC%.tgz}-usb-recovery.zip"
cd usb
echo "    Creating ${FW_ENC%.tgz}-usb-recovery.zip."
zip -r -0 "${FW_ENC%.tgz}-usb-recovery.zip" * >/dev/null
mv *.zip ../
cd ..
rm -Rf usb
echo ' __________________________________________________'
echo "|  All done. Now extract the files in the zip file |"
echo "|  to the root of a FAT32 formatted USB stick.     |"
echo "|  Note: Not all USB sticks are recognised in      |"
echo "|  recovery mode so try another if no luck.        |"
echo "|  Recovery takes about 10 minutes. Be patient!    |"
echo "|  Have a nice day :)                              |"
echo '|__________________________________________________|'

exit

# Notes:
# This is all I have to say on the subject so far.
# This script will take a Lenovo NAS firmware (tested on IX4-300D), unencypt it, and convert it to a USB imaging/recovery update.
# Extract the resulting zip archive to the root of a FAT32 or EXT2 formatted USB stick. Do not use windows exFAT or vFAT format.
# You should have 2 folders in the root of the stick named 'images' and 'emctools' with files/folders within them.
# If the file /usb_drive/emctools/h4c_images/noreinstall exists, then in theory you should retain your drive data (h4c_images folder name may vary by device model).
# The file /usb_drive/emctools/h4c_images/preimage.sh will run before the update if it exsists.
# Not all USB sticks are recognised in recovery mode so try using another if no luck. 4gb/8gb sticks are best but again, it might not be recognised.
# The recovery process unpacks the image to the USB drive temporarily so you need enough free space for this so 2gb might be pushing it (/usb_drive/emctools/h4c_images/temp).
# If the file /usb_drive/emctools/h4c_images/noextraction exists, then the temporary unpacked image folder will remain.
# SDK apps in the /usb_drive/emctools/h4c_images/SDKApps will also be installed if they still exsist.
# Make sure you have the USB stick in the correct port (top rear for IX4-300d google your device).
# Insert USB stick into NAS, hold reset button in, plug in power lead and keep reset button pressed for 5 seconds before releasing.
# If you cannot get USB working, TFTP boot recovery is slower but works. Only one ethernet port works (eth0), can't remember which though.
# Setup a basic TFTP server with static ip address 10.4.50.5. Copy zImage and initrd to the root along with the extracted contents of the zip file (like USB stick).
# Recovery takes about 10 minutes (longer for TFTP). Be patient and wait for the unit to reboot!
# The first boot will take some time too, 20 minutes if I recall but this was a complete wipe.
# You will likely lose all data on the drives. Not great but at least your unit will be working again.
# If you use ssh access, the root password will be the password you created prefixed with 'sohoadmin'.
# Enable ssh by going to http://yourlenovoipaddress/manage/diagnostics.html
# Search google for http://download.lenovo.com/nas/lifeline/ if you don't already have a firmware for your device.
# Don't buy lenovo again. If you are reading this, you probably already know.
# Lenovo stuff will break in the end, and support will fob you off more than an ISP call center (Typical support ticket: "We will look into it, closed......Nothing").
