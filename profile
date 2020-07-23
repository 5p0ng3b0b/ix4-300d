#!/bin/sh
# optware-ng login script
# See https://github.com/5p0ng3b0b/ix4-300d

# Setup enviroment variables
# export PATH="/opt/bin:/opt/sbin:/opt/local/bin:$(echo $PATH | sed -e 's#/opt/bin##g' -e 's#/opt/sbin##g' -e 's#/opt/local/bin##g' -e 's/::/:/g' -e 's/::/:/g' -e 's/:$//')"
SRC=$(cat /mnt/pools/A/A0/.optsrc)
[ "$SRC" = "USB" ] && export OPKG_OFFLINE_ROOT=$(mount | grep "$(blkid | grep "$UUID" | awk -F ':' '{print $1}') on /mnt" | awk '{print $3}' | grep -v '/opt')
[ "$SRC" = "HDD" ] && export OPKG_OFFLINE_ROOT="/mnt/pools/A/A0/opt"
export "TERMINFO=/opt/share/terminfo"
export "TERM=xterm"
export "TMP=/mnt/pools/A/A0//opt/tmp"; export TEMP="$TMP"; export TMPDIR-"$TMP"
export "prefix=/opt"
export "sysconfdir=/opt/etc"
export HOME="/opt/home/$USER"
if [ ! "$USER" = "root" ]; then PS1='$'; else PS1='#'; fi
PS1='\[\e[33m\]\u@\h[\[\e[34m\]\w\[\e[33m\]]'$PS1'\[\e[0m\] '

# Define functions
log()           { # Write timestamped message to logfile.
                echo "$(date): $1" >>"/mnt/pools/A/A0/init-opt.log"; }
addpath()       { # Add a folder to the PATH environment variable only if the folder exists and without duplicating it.
                if [ -d "$1" ]; then export PATH="$1:$(echo $PATH | sed -e "s#$1##g" -e 's/::/:/g' -e 's/:$//')"; fi; }
embed_profile(){ # Embed this profile into init-opt.sh as a base64 encoded variable.
                local opwd="$(pwd)"; cd "/mnt/pools/A/A0"
                local ifile="init-opt.sh"; local tp="profile.64"; echo -e 'profile=\\\n' >"$tp"
                cp "$ifile" "$ifile.bak"; cat /opt/etc/profile | base64 | sed 's/$/\\\n/' >>"$tp"; echo " ">>"$tp"
                sed '/#begin_profile/,/#end_profile/ {/#begin_profile/n;/#end_profile/!d}' "$ifile" >"$ifile.tmp"
                awk -v i="$(cat $tp)" '$1=="#begin_profile"{p=1} p && $1=="#end_profile"{print i} 1' "$ifile.tmp" >"$ifile"
                rm "$ifile.tmp"; rm "$tp"; cd "$opwd"; }
embed_sohoprocs(){ # Embed sohoProcs.xml into init-opt.sh as a base64 encoded variable.
                local opwd="$(pwd)"; cd "/mnt/pools/A/A0"
                local ifile="init-opt.sh"; local tp="sohoprocs.64"; echo -e 'sohoprocs=\\\n' >"$tp"
                cp "$ifile" "$ifile.bak"; cat /usr/local/cfg/sohoProcs.xml | base64 | sed 's/$/\\\n/' >>"$tp"; echo " ">>"$tp"
                sed '/#begin_sohoprocs/,/#end_sohoprocs/ {/#begin_sohoprocs/n;/#end_sohoprocs/!d}' "$ifile" >"$ifile.tmp"
                awk -v i="$(cat $tp)" '$1=="#begin_sohoprocs"{p=1} p && $1=="#end_sohoprocs"{print i} 1' "$ifile.tmp" >"$ifile"
                rm "$ifile.tmp"; rm "$tp"; cd "$opwd"; }
banner1()       { # Print optware-ng banner.
                local mdl=$(printf '%-12s' "$(cat /mnt/apps/usr/local/cfg/Firmware.xml | grep 'Model=' | awk -F '"' '{print $4}')")
                local w='\e[37m'; local b='\e[34m'
                local ver=v$(printf '%-13s' "$(cat /etc/sohoFlash.xml | grep 'FirmwareRev' | awk -F '"' '{print $6}')")
                echo -e " _____       __"
                echo -e "|     |-----|  |_.--.--.--.-----.----.-----.__.-----.-----."
                echo -e "|  -  |  _  |   _|  |  |  |--_  |   _|  -__|__|     |  _  |"
                echo -e "|_____|   __|____|________|_____|__| |_____|  |__|__|__   |"
                echo -e "      |__|        $b$mdl        $ver$w|_____|"; }

# Remove duplicate calls to this file from ~/.profile
awk '!a[$0]++' ~/.profile >~/.profile.tmp; mv -f ~/.profile.tmp ~/.profile
chmod +x ~/.profile

# Setup alaises
alias oconfigure="./configure --prefix=/opt --sysconfdir=/opt/etc"
alias omake="make -e"

# Print login banner
clear
banner1

# Log session
log "Remote login from $SSH_CLIENT"

# Setup paths
addpath "/opt/bin"
addpath "/opt/sbin"
addpath "/opt/local/bin"
addpath "/opt/usr/bin"
addpath "/opt/usr/go/bin"

# Finish
cd "$HOME"
