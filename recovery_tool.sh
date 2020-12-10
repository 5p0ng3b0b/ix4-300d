#!/bin/bash
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
#touch "usb/emctools/"$FW_CODE"_images/noreinstall"

# Uncomment to preserve temp folder.
#touch "usb/emctools/"$FW_CODE"_images/noextraction"

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
