#!/bin/sh
# Version=1.08
# IX4-300D startup and optware-ng init script
# See https://github.com/5p0ng3b0b/ix4-300d

# Set drive for location of optware and apps use USB or HDD
# HDD is storage pool
# If USB then must specify UUID of USB drive below
files=HDD
UUID="0"

# Wait until storage pool is mounted
while [ ! "$(ls -a /mnt/pools/A/A0/ 2>/dev/null)" ]; do sleep 2; done
echo "$files" >/mnt/pools/A/A0/.optsrc
[ "$files" = "USB" ] && echo "$UUID" >>/mnt/pools/A/A0/.optsrc
# Wait for external usb if selected as data drive
[ "$files" = "USB" ] && while [ ! "$(blkid | grep "$UUID")" ]; do sleep 2; done

# Assign variables and define functions
[ "$files" = "USB" ] && OPT=$(mount | grep "$(blkid | grep "$UUID" | awk -F ':' '{print $1}') on /mnt" | awk '{print $3}' | grep -v '/opt')
[ "$files" = "HDD" ] && { OPT="/mnt/pools/A/A0/opt"; mkdir -p "$OPT"; }
HOME="/opt/home/$USER"
PROFILE="/opt/etc/profile"
v_gt() { [ "$(echo -e "$1\n$2" | sort -V | head -n 1)" != "$1" ] && echo "1"; }
log() { echo "$(date) : $1" >>"/mnt/pools/A/A0/init-opt.log"; }

log "Starting init-opt.sh with $files as optware source at $OPT."
# Setup folders and mounts
for DIR in "apps" "bin" "sbin" "etc" "var" "lib" "usr" "var" "include" "tmp" "home" "share" "opt" "ipkg" \
    "arm-buildroot-linux-uclibcgnueabi" "libexec" "local" "info" "doc" "docs" "man" "ssh"; do
    [ ! -d "$OPT/$DIR" ] && { mkdir -p "$OPT/$DIR"; log "Created $OPT/$DIR."; }
    [ -L "/opt/$DIR" ] && rm "/opt/$DIR"
    [ ! -L "/opt/$DIR" ] && { ln -s "$OPT/$DIR" "/opt/$DIR"; log "Linking $OPT/$DIR to /opt/$DIR."; }
    # Dunno why, but bind mounted folders gave problems when installing some ipkg modules so
    # symlinked all folders instead. 'ipkg install git' is an example.
    #[ ! -d "/opt/$DIR" ] && mkdir -p "/opt/$DIR"
    #[ ! "$(mount | grep " on /opt/$DIR ")" ] && mount --bind "$OPT/$DIR" "/opt/$DIR"
    if [ ! -d "$OPT/$DIR" ] && [ ! -L "/opt/$DIR" ]; then echo "Something went wrong with $DIR."; fi 
    done

for DIR in "usr/bin" "usr/sbin" "var/log" "var/tmp" "var/lock" "share/terminfo"; do
    mkdir -p "$OPT/$DIR"
    done

# Use storage pool for /var/tmp to prevent running out of space
[ ! -d "/mnt/pools/A/A0//opt/tmp" ] && mkdir -p "/mnt/pools/A/A0/opt/tmp"
mount --bind "/mnt/pools/A/A0/opt/tmp" "/var/tmp"
log "Mountpoints complete."

# Use storage pool for /opt/apps to prevent running out of space
[ ! -d "$OPT/apps" ] && mkdir -p "$OPT/apps"
#mount --bind "$OPT/apps" "/opt/apps"
rm -Rf /opt/apps
ln -s "$OPT/apps" "/opt/apps"

# Setup home folder
CURR_HOME="$(cat /etc/passwd | grep $USER | awk -F ':' '{print $6}')"
if [ ! "$CURR_HOME" = "$HOME" ]; then
    awk -v u="$USER" -v h="$HOME" 'BEGIN{FS=OFS=":"}$1==u{$6=h}1' "/etc/passwd" > "/etc/passwd.tmp"
    cat "/etc/passwd.tmp" > "/etc/passwd"; rm "/etc/passwd.tmp"
    fi
mkdir -p "$HOME"
[ ! -f "$HOME/.profile" ] && echo -e '#!/bin/sh\n. /opt/etc/profile' >"$HOME/.profile"
[ ! "$(cat $HOME/.profile | grep '. /opt/etc/profile')" ] && echo '. /opt/etc/profile' >>"$HOME/.profile"
awk '!a[$0]++' "$HOME/.profile" >"$HOME/.profile.tmp"; mv -f "$HOME/.profile.tmp" "$HOME/.profile"
chmod +x "$HOME/.profile"
log "Home folder complete."

# Install optware-ng if missing
if [ ! -f "/opt/bin/ipkg" ]; then
    log "Installing optware-ng."
    feed="http://ipkg.nslu2-linux.org/optware-ng/buildroot-armeabi-ng"
    ipk_name="$(wget -qO- $feed/Packages | awk '/^Filename: ipkg-static/ {print $2}')"
    wget -qO "/tmp/$ipk_name" "$feed/$ipk_name"
    tar -C /tmp -xzf "/tmp/$ipk_name" "./data.tar.gz"; tar -C /tmp -xzf "/tmp/data.tar.gz"; cp -r /tmp/opt/* $OPT/
    rm -f "/tmp/$ipk_name" "/tmp/data.tar.gz"; rm -rf "/tmp/opt"
    echo "src/gz optware-ng $feed" > "/opt/etc/ipkg.conf";  echo "dest /opt/ /" >> "/opt/etc/ipkg.conf"
    mv "/opt/bin/ipkg" "/opt/bin/ipkgbin"
    echo -e '#!/bin/sh\n/opt/bin/ipkgbin -t /opt/tmp -force-space $@' >"/opt/bin/ipkg"
    chmod +x "/opt/bin/ipkg"
    /opt/bin/ipkg update >/dev/null
    log "Optware-ng is installed."
    fi
# The default /opt/etc/profile script is base64 encoded below.
# If you mess up /opt/etc/profile just delete it and reboot to restore it.
# Ideally all your modifications to paths etc should go in $HOME/.profile.
# /opt/etc/profile is executed via $HOME/.profile
# Some packages install the optware version of bash which overwrites
# /opt/etc/profile. Do not move or change!
#begin_profile
profile=\
IyEvYmluL3NoCiMgb3B0d2FyZS1uZyBsb2dpbiBzY3JpcHQKIyBTZWUgaHR0cHM6Ly9naXRodWIu\
Y29tLzVwMG5nM2IwYi9peDQtMzAwZAoKIyBTZXR1cCBlbnZpcm9tZW50IHZhcmlhYmxlcwojIGV4\
cG9ydCBQQVRIPSIvb3B0L2Jpbjovb3B0L3NiaW46L29wdC9sb2NhbC9iaW46JChlY2hvICRQQVRI\
IHwgc2VkIC1lICdzIy9vcHQvYmluIyNnJyAtZSAncyMvb3B0L3NiaW4jI2cnIC1lICdzIy9vcHQv\
bG9jYWwvYmluIyNnJyAtZSAncy86Oi86L2cnIC1lICdzLzo6LzovZycgLWUgJ3MvOiQvLycpIgpT\
UkM9JChjYXQgL21udC9wb29scy9BL0EwLy5vcHRzcmMpClsgIiRTUkMiID0gIlVTQiIgXSAmJiBl\
eHBvcnQgT1BLR19PRkZMSU5FX1JPT1Q9JChtb3VudCB8IGdyZXAgIiQoYmxraWQgfCBncmVwICIk\
VVVJRCIgfCBhd2sgLUYgJzonICd7cHJpbnQgJDF9Jykgb24gL21udCIgfCBhd2sgJ3twcmludCAk\
M30nIHwgZ3JlcCAtdiAnL29wdCcpClsgIiRTUkMiID0gIkhERCIgXSAmJiBleHBvcnQgT1BLR19P\
RkZMSU5FX1JPT1Q9Ii9tbnQvcG9vbHMvQS9BMC9vcHQiCmV4cG9ydCAiVEVSTUlORk89L29wdC9z\
aGFyZS90ZXJtaW5mbyIKZXhwb3J0ICJURVJNPXh0ZXJtIgpleHBvcnQgIlRNUD0vbW50L3Bvb2xz\
L0EvQTAvL29wdC90bXAiOyBleHBvcnQgVEVNUD0iJFRNUCI7IGV4cG9ydCBUTVBESVItIiRUTVAi\
CmV4cG9ydCAicHJlZml4PS9vcHQiCmV4cG9ydCAic3lzY29uZmRpcj0vb3B0L2V0YyIKZXhwb3J0\
IEhPTUU9Ii9vcHQvaG9tZS8kVVNFUiIKaWYgWyAhICIkVVNFUiIgPSAicm9vdCIgXTsgdGhlbiBQ\
UzE9JyQnOyBlbHNlIFBTMT0nIyc7IGZpClBTMT0nXFtcZVszM21cXVx1QFxoW1xbXGVbMzRtXF1c\
d1xbXGVbMzNtXF1dJyRQUzEnXFtcZVswbVxdICcKCiMgRGVmaW5lIGZ1bmN0aW9ucwpsb2coKSAg\
ICAgICAgICAgeyAjIFdyaXRlIHRpbWVzdGFtcGVkIG1lc3NhZ2UgdG8gbG9nZmlsZS4KICAgICAg\
ICAgICAgICAgIGVjaG8gIiQoZGF0ZSk6ICQxIiA+PiIvbW50L3Bvb2xzL0EvQTAvaW5pdC1vcHQu\
bG9nIjsgfQphZGRwYXRoKCkgICAgICAgeyAjIEFkZCBhIGZvbGRlciB0byB0aGUgUEFUSCBlbnZp\
cm9ubWVudCB2YXJpYWJsZSBvbmx5IGlmIHRoZSBmb2xkZXIgZXhpc3RzIGFuZCB3aXRob3V0IGR1\
cGxpY2F0aW5nIGl0LgogICAgICAgICAgICAgICAgaWYgWyAtZCAiJDEiIF07IHRoZW4gZXhwb3J0\
IFBBVEg9IiQxOiQoZWNobyAkUEFUSCB8IHNlZCAtZSAicyMkMSMjZyIgLWUgJ3MvOjovOi9nJyAt\
ZSAncy86JC8vJykiOyBmaTsgfQplbWJlZF9wcm9maWxlKCl7ICMgRW1iZWQgdGhpcyBwcm9maWxl\
IGludG8gaW5pdC1vcHQuc2ggYXMgYSBiYXNlNjQgZW5jb2RlZCB2YXJpYWJsZS4KICAgICAgICAg\
ICAgICAgIGxvY2FsIG9wd2Q9IiQocHdkKSI7IGNkICIvbW50L3Bvb2xzL0EvQTAiCiAgICAgICAg\
ICAgICAgICBsb2NhbCBpZmlsZT0iaW5pdC1vcHQuc2giOyBsb2NhbCB0cD0icHJvZmlsZS42NCI7\
IGVjaG8gLWUgJ3Byb2ZpbGU9XFxcbicgPiIkdHAiCiAgICAgICAgICAgICAgICBjcCAiJGlmaWxl\
IiAiJGlmaWxlLmJhayI7IGNhdCAvb3B0L2V0Yy9wcm9maWxlIHwgYmFzZTY0IHwgc2VkICdzLyQv\
XFxcbi8nID4+IiR0cCI7IGVjaG8gIiAiPj4iJHRwIgogICAgICAgICAgICAgICAgc2VkICcvI2Jl\
Z2luX3Byb2ZpbGUvLC8jZW5kX3Byb2ZpbGUvIHsvI2JlZ2luX3Byb2ZpbGUvbjsvI2VuZF9wcm9m\
aWxlLyFkfScgIiRpZmlsZSIgPiIkaWZpbGUudG1wIgogICAgICAgICAgICAgICAgYXdrIC12IGk9\
IiQoY2F0ICR0cCkiICckMT09IiNiZWdpbl9wcm9maWxlIntwPTF9IHAgJiYgJDE9PSIjZW5kX3By\
b2ZpbGUie3ByaW50IGl9IDEnICIkaWZpbGUudG1wIiA+IiRpZmlsZSIKICAgICAgICAgICAgICAg\
IHJtICIkaWZpbGUudG1wIjsgcm0gIiR0cCI7IGNkICIkb3B3ZCI7IH0KZW1iZWRfc29ob3Byb2Nz\
KCl7ICMgRW1iZWQgc29ob1Byb2NzLnhtbCBpbnRvIGluaXQtb3B0LnNoIGFzIGEgYmFzZTY0IGVu\
Y29kZWQgdmFyaWFibGUuCiAgICAgICAgICAgICAgICBsb2NhbCBvcHdkPSIkKHB3ZCkiOyBjZCAi\
L21udC9wb29scy9BL0EwIgogICAgICAgICAgICAgICAgbG9jYWwgaWZpbGU9ImluaXQtb3B0LnNo\
IjsgbG9jYWwgdHA9InNvaG9wcm9jcy42NCI7IGVjaG8gLWUgJ3NvaG9wcm9jcz1cXFxuJyA+IiR0\
cCIKICAgICAgICAgICAgICAgIGNwICIkaWZpbGUiICIkaWZpbGUuYmFrIjsgY2F0IC91c3IvbG9j\
YWwvY2ZnL3NvaG9Qcm9jcy54bWwgfCBiYXNlNjQgfCBzZWQgJ3MvJC9cXFxuLycgPj4iJHRwIjsg\
ZWNobyAiICI+PiIkdHAiCiAgICAgICAgICAgICAgICBzZWQgJy8jYmVnaW5fc29ob3Byb2NzLywv\
I2VuZF9zb2hvcHJvY3MvIHsvI2JlZ2luX3NvaG9wcm9jcy9uOy8jZW5kX3NvaG9wcm9jcy8hZH0n\
ICIkaWZpbGUiID4iJGlmaWxlLnRtcCIKICAgICAgICAgICAgICAgIGF3ayAtdiBpPSIkKGNhdCAk\
dHApIiAnJDE9PSIjYmVnaW5fc29ob3Byb2NzIntwPTF9IHAgJiYgJDE9PSIjZW5kX3NvaG9wcm9j\
cyJ7cHJpbnQgaX0gMScgIiRpZmlsZS50bXAiID4iJGlmaWxlIgogICAgICAgICAgICAgICAgcm0g\
IiRpZmlsZS50bXAiOyBybSAiJHRwIjsgY2QgIiRvcHdkIjsgfQpiYW5uZXIxKCkgICAgICAgeyAj\
IFByaW50IG9wdHdhcmUtbmcgYmFubmVyLgogICAgICAgICAgICAgICAgbG9jYWwgbWRsPSQocHJp\
bnRmICclLTEycycgIiQoY2F0IC9tbnQvYXBwcy91c3IvbG9jYWwvY2ZnL0Zpcm13YXJlLnhtbCB8\
IGdyZXAgJ01vZGVsPScgfCBhd2sgLUYgJyInICd7cHJpbnQgJDR9JykiKQogICAgICAgICAgICAg\
ICAgbG9jYWwgdz0nXGVbMzdtJzsgbG9jYWwgYj0nXGVbMzRtJwogICAgICAgICAgICAgICAgbG9j\
YWwgdmVyPXYkKHByaW50ZiAnJS0xM3MnICIkKGNhdCAvZXRjL3NvaG9GbGFzaC54bWwgfCBncmVw\
ICdGaXJtd2FyZVJldicgfCBhd2sgLUYgJyInICd7cHJpbnQgJDZ9JykiKQogICAgICAgICAgICAg\
ICAgZWNobyAtZSAiIF9fX19fICAgICAgIF9fIgogICAgICAgICAgICAgICAgZWNobyAtZSAifCAg\
ICAgfC0tLS0tfCAgfF8uLS0uLS0uLS0uLS0tLS0uLS0tLS4tLS0tLS5fXy4tLS0tLS4tLS0tLS4i\
CiAgICAgICAgICAgICAgICBlY2hvIC1lICJ8ICAtICB8ICBfICB8ICAgX3wgIHwgIHwgIHwtLV8g\
IHwgICBffCAgLV9ffF9ffCAgICAgfCAgXyAgfCIKICAgICAgICAgICAgICAgIGVjaG8gLWUgInxf\
X19fX3wgICBfX3xfX19ffF9fX19fX19ffF9fX19ffF9ffCB8X19fX198ICB8X198X198X18gICB8\
IgogICAgICAgICAgICAgICAgZWNobyAtZSAiICAgICAgfF9ffCAgICAgICAgJGIkbWRsICAgICAg\
ICAkdmVyJHd8X19fX198IjsgfQoKIyBSZW1vdmUgZHVwbGljYXRlIGNhbGxzIHRvIHRoaXMgZmls\
ZSBmcm9tIH4vLnByb2ZpbGUKYXdrICchYVskMF0rKycgfi8ucHJvZmlsZSA+fi8ucHJvZmlsZS50\
bXA7IG12IC1mIH4vLnByb2ZpbGUudG1wIH4vLnByb2ZpbGUKY2htb2QgK3ggfi8ucHJvZmlsZQoK\
IyBTZXR1cCBhbGFpc2VzCmFsaWFzIG9jb25maWd1cmU9Ii4vY29uZmlndXJlIC0tcHJlZml4PS9v\
cHQgLS1zeXNjb25mZGlyPS9vcHQvZXRjIgphbGlhcyBvbWFrZT0ibWFrZSAtZSIKCiMgUHJpbnQg\
bG9naW4gYmFubmVyCmNsZWFyCmJhbm5lcjEKCiMgTG9nIHNlc3Npb24KbG9nICJSZW1vdGUgbG9n\
aW4gZnJvbSAkU1NIX0NMSUVOVCIKCiMgU2V0dXAgcGF0aHMKYWRkcGF0aCAiL29wdC9iaW4iCmFk\
ZHBhdGggIi9vcHQvc2JpbiIKYWRkcGF0aCAiL29wdC9sb2NhbC9iaW4iCmFkZHBhdGggIi9vcHQv\
dXNyL2JpbiIKYWRkcGF0aCAiL29wdC91c3IvZ28vYmluIgoKIyBGaW5pc2gKY2QgIiRIT01FIgo=\
 
#end_profile
[ ! -f "$PROFILE" ] && { echo "$profile" | base64 -d >"$PROFILE"; chmod +x "$PROFILE"; }
# Now we source ~/.profile to setup paths
. "$HOME/.profile"

# Configure nano settings
if [ ! -f "$HOME/.nanorc" ]; then
    nanov="$(nano -V | head -1 | awk '{print $4}')" # Get nano version number
    if [ "$(v_gt $nanov 2.7.0)" =  "1" ]; then echo 'set linenumbers' >>"$HOME/.nanorc"; fi # Add line numbers
    if [ "$(v_gt $nanov 2.2.6)" =  "1" ]; then echo 'set constantshow' >>"$HOME/.nanorc"; else echo 'set const' >>"$HOME/.nanorc"; fi
    awk '!a[$0]++' "$HOME/.nanorc" >"$HOME/.nanorc.tmp"; mv -f "$HOME/.nanorc.tmp" "$HOME/.nanorc"
    fi
# modded sohoProcs.xml stored here in base64. Do not change or move!
#begin_sohoprocs
sohoprocs=\
PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz48UHJvY2Vzc2VzPgo8R3JvdXAg\
TGV2ZWw9IjAiPgo8UHJvZ3JhbSBOYW1lPSJPblJlYm9vdCIgUGF0aD0ic2giPgoJPEFyZ3M+L2V0\
Yy9PblJlYm9vdDwvQXJncz4KCTxTeXNPcHRpb24gSW5pdE9ubHk9IjEiIE5vRXJyb3JzPSIxIi8+\
CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFtZT0iUm1SZWJvb3QiIFBhdGg9InJtIj4KCTxBcmdzPi9l\
dGMvT25SZWJvb3Q8L0FyZ3M+Cgk8U3lzT3B0aW9uIERlbGF5U3RhcnQ9IjMiIEluaXRPbmx5PSIx\
IiBOb0Vycm9ycz0iMSIvPgo8L1Byb2dyYW0+Cgo8UHJvZ3JhbSBOYW1lPSJkYnVzLXNldHVwIiBQ\
YXRoPSJzaCI+Cgk8QXJncz4vdXNyL2xvY2FsL2RidXMvYmluL2RidXMtc2V0dXA8L0FyZ3M+Cgk8\
U3lzT3B0aW9uIEluaXRPbmx5PSIxIiBOb0Vycm9ycz0iMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFt\
IE5hbWU9ImRidXMtZGFlbW9uIiBQYXRoPSIvdXNyL2Jpbi9kYnVzLWRhZW1vbiI+Cgk8QXJncz4t\
LW5vZm9yazwvQXJncz4KCTxBcmdzPi0tc3lzdGVtPC9BcmdzPgoJPFN5c09wdGlvbiBSZXN0YXJ0\
PSItMSIvPgo8L1Byb2dyYW0+CjwvR3JvdXA+Cgo8R3JvdXAgTGV2ZWw9IjEiPgo8UHJvZ3JhbSBO\
YW1lPSJldmVudGQiIFBhdGg9Ii91c3IvbG9jYWwvZXZlbnRkL2V2ZW50ZCI+CiAgICA8U3lzT3B0\
aW9uIE1heE1lbT0iOTZNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9\
ImluaXQtb3B0LnNoIiBQYXRoPSIvbW50L3Bvb2xzL0EvQTAvaW5pdC1vcHQuc2giPgo8U3lzT3B0\
aW9uIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPC9Hcm91cD4KCjxHcm91cCBMZXZlbD0iMiI+\
CjxQcm9ncmFtIE5hbWU9Ikhvc3RuYW1lZCIgUGF0aD0ic2giPgoJPEFyZ3M+L2V0Yy9pbml0LmQv\
aG9zdG5hbWVkPC9BcmdzPgoJPFN5c09wdGlvbiBJbml0T25seT0iMSIgTm9FcnJvcnM9IjEiLz4K\
PC9Qcm9ncmFtPgo8UHJvZ3JhbSBOYW1lPSJwa2dkIiBQYXRoPSIvdXNyL2xvY2FsL3BrZ2QvcGtn\
ZCI+Cgk8U3lzT3B0aW9uIE1heE1lbT0iOTZNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQ\
cm9ncmFtIE5hbWU9InNvaG9jZXJ0IiBQYXRoPSIvdXNyL2Jpbi9zb2hvY2VydCI+Cgk8U3lzT3B0\
aW9uIEluaXRPbmx5PSIxIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFtZT0idXBucGRpc2NvdmVy\
eSIgUGF0aD0iL3Vzci9zYmluL3VwbnBkaXNjb3ZlcnkiPgoJPFN5c09wdGlvbiBNYXhNZW09IjM2\
TSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBOYW1lPSJkaXNwbGF5ZCIgUGF0\
aD0iL3Vzci9sb2NhbC9kaXNwbGF5ZC9kaXNwbGF5ZCI+Cgk8U3lzT3B0aW9uIE1heE1lbT0iOTZN\
IiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9ImFwY3Vwc2QiIFBhdGg9\
Ii9zYmluL2FwY3Vwc2QiPgoJPEFyZ3M+LWI8L0FyZ3M+CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFt\
ZT0ibWRuc2QiIFBhdGg9Ii91c3Ivc2Jpbi9tZG5zZCI+Cgk8QXJncz4tZGVidWc8L0FyZ3M+Cgk8\
U3lzT3B0aW9uIE1heE1lbT0iMTJNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFt\
IERpc2FibGU9IjEiIE5hbWU9ImN1cHNkIiBQYXRoPSIvdXNyL3NiaW4vY3Vwc2QiPgoJPEFyZ3M+\
LWY8L0FyZ3M+Cgk8U3lzT3B0aW9uIE1heE1lbT0iMzJNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dy\
YW0+CjxQcm9ncmFtIERpc2FibGU9IjEiIE5hbWU9InNtYmQiIFBhdGg9Ii91c3IvbG9jYWwvc2Ft\
YmEvc2Jpbi9zbWJkIj4KCTxBcmdzPi1GPC9BcmdzPgoJPFN5c09wdGlvbiBDcHVBZmZpbml0eT0i\
MiIgTWF4TWVtPSIzMk0iIE5pY2U9IjEwIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9n\
cmFtIERpc2FibGU9IjEiIE5hbWU9Im5tYmQiIFBhdGg9Ii91c3IvbG9jYWwvc2FtYmEvc2Jpbi9u\
bWJkIj4KCTxBcmdzPi1GPC9BcmdzPgoJPFN5c09wdGlvbiBNYXhNZW09IjIwTSIgUmVzdGFydD0i\
LTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBEaXNhYmxlPSIxIiBOYW1lPSJ3aW5iaW5kZCIgUGF0\
aD0iL3Vzci9sb2NhbC9zYW1iYS9zYmluL3dpbmJpbmRkIj4KICAgIDxBcmdzPi1GPC9BcmdzPgog\
ICAgPFN5c09wdGlvbiBNYXhNZW09IjI1Nk0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFBy\
b2dyYW0gRGlzYWJsZT0iMSIgTmFtZT0ic25tcGQiIFBhdGg9Ii91c3Ivc2Jpbi9zbm1wZCI+Cgk8\
QXJncz4tZiAtQyAtYyAvZXRjL3NubXAvc25tcGQuY29uZjwvQXJncz4KCTxTeXNPcHRpb24gTWF4\
TWVtPSIzMk0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gRGlzYWJsZT0iMSIg\
TmFtZT0ibXQtZGFhcGQiIFBhdGg9Ii91c3IvbG9jYWwvbXQtZGFhcGQvYmluL210LWRhYXBkIj4K\
CTxBcmdzPi1mIC1tIC1jIC9tbnQvc3lzdGVtL21lZGlhL2RhYXAuY29uZjwvQXJncz4KCTxTeXNP\
cHRpb24gTWF4TWVtPSI2NE0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gRGlz\
YWJsZT0iMSIgTmFtZT0idHdvbmt5bWVkaWEiIFBhdGg9Ii91c3IvbG9jYWwvdHdvbmt5L3R3b25r\
eXN0YXJ0LnNoIj4KCTxTeXNPcHRpb24gUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3Jh\
bSBEaXNhYmxlPSIxIiBOYW1lPSJtZWRpYXRvbWIiIFBhdGg9Ii91c3IvYmluL21lZGlhdG9tYiI+\
Cgk8QXJncz4tYyAvbW50L3N5c3RlbS9tZWRpYS9tZWRpYXRvbWIueG1sPC9BcmdzPgoJPFN5c09w\
dGlvbiBNYXhNZW09IjY0TSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBEaXNh\
YmxlPSIxIiBOYW1lPSJzc2hkIiBQYXRoPSIvdXNyL3NiaW4vc3NoZCI+Cgk8U3lzT3B0aW9uIE1h\
eE1lbT0iMjBNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERpc2FibGU9IjAi\
IE5hbWU9InN2Y2QiIFBhdGg9Ii91c3IvbG9jYWwvc3ZjZC9zdmNkIj4KCTxTeXNPcHRpb24gTWF4\
TWVtPSI5Nk0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gRGlzYWJsZT0iMSIg\
TmFtZT0icHJvZnRwZCIgUGF0aD0iL3Vzci9sb2NhbC9wcm9mdHBkL3NiaW4vcHJvZnRwZCI+Cgk8\
QXJncz4tbiAtcSAtYyAvbW50L3N5c3RlbS9jb25maWcvcHJvZnRwZC5jb25mPC9BcmdzPgoJPFN5\
c09wdGlvbiBNYXhNZW09IjMyTSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBE\
aXNhYmxlPSIxIiBOYW1lPSJJRVREIiBQYXRoPSIvdXNyL3NiaW4vaWV0ZCI+Cgk8QXJncz4tZjwv\
QXJncz4KCTxBcmdzPi1jIC9tbnQvc3lzdGVtL2NvbmZpZy9pZXRkLmNvbmY8L0FyZ3M+Cgk8U3lz\
T3B0aW9uIE1heE1lbT0iMzJNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERp\
c2FibGU9IjEiIE5hbWU9IlNDU1QiIFBhdGg9Ii91c3Ivc2Jpbi9pc2NzaS1zY3N0ZCI+Cgk8QXJn\
cz4tZjwvQXJncz4KCTxTeXNPcHRpb24gTWF4TWVtPSIzMk0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJv\
Z3JhbT4KPFByb2dyYW0gRGlzYWJsZT0iMSIgTmFtZT0iaXNucyIgUGF0aD0iL3Vzci9zYmluL2lz\
bnNkIj4KCTxBcmdzPi1mPC9BcmdzPgoJPFN5c09wdGlvbiBNYXhNZW09IjMyTSIgUmVzdGFydD0i\
LTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBOYW1lPSJjcm9uZCIgUGF0aD0iL3Vzci9zYmluL2Ny\
b24iPgoJPEFyZ3M+LWY8L0FyZ3M+Cgk8U3lzT3B0aW9uIE1heE1lbT0iMzJNIiBSZXN0YXJ0PSIt\
MSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERpc2FibGU9IjEiIE5hbWU9InBvc3RmaXgiIFBhdGg9\
Ii91c3Ivc2Jpbi9wb3N0Zml4Ij4KCTxBcmdzPi1jIC91c3IvbG9jYWwvcG9zdGZpeDwvQXJncz4K\
CTxBcmdzPnN0YXJ0PC9BcmdzPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9ImFjcGlkIiBQYXRo\
PSIvdXNyL3NiaW4vYWNwaWQiPgoJPEFyZ3M+LWMgL3Vzci9sb2NhbC9hY3BpL2V2ZW50czwvQXJn\
cz4KCTxBcmdzPi1mPC9BcmdzPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERpc2FibGU9IjEiIE5hbWU9\
ImxvZ3JvdGF0aW9uIiBQYXRoPSIvdXNyL2Jpbi9sb2dyb3RhdGlvbiI+Cgk8U3lzT3B0aW9uIE1h\
eE1lbT0iMzJNIiBSZXN0YXJ0PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERpc2FibGU9IjEi\
IE5hbWU9ImJsdWV0b290aGQiIFBhdGg9Ii91c3Ivc2Jpbi9ibHVldG9vdGhkIj4KCTxBcmdzPi1u\
PC9BcmdzPgoJPFN5c09wdGlvbiBNYXhNZW09IjMyTSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFt\
Pgo8UHJvZ3JhbSBEaXNhYmxlPSIxIiBOYW1lPSJzb2JleHNydiIgUGF0aD0iL3Vzci9iaW4vc29i\
ZXhzcnYiPgoJPFN5c09wdGlvbiBNYXhNZW09IjMyTSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFt\
Pgo8UHJvZ3JhbSBEaXNhYmxlPSIxIiBOYW1lPSJibHVldG9vdGgtYWdlbnQiIFBhdGg9Ii91c3Iv\
YmluL2JsdWV0b290aC1hZ2VudCI+Cgk8U3lzT3B0aW9uIE1heE1lbT0iMzJNIiBSZXN0YXJ0PSIt\
MSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9ImFwcHNkb3dubG9hZCIgUGF0aD0iL3Vzci9i\
aW4vYXBwc2Rvd25sb2FkIj4KCTxTeXNPcHRpb24gRGF5cz0iMiIgUmFuZG9tRGVsYXk9IjE0NDAi\
IFNjaGVkdWxlZD0iMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9ImF1dG91cGciIFBhdGg9\
Ii91c3IvYmluL2F1dG91cGciPgoJPFN5c09wdGlvbiBEYXlzPSIyIiBSYW5kb21EZWxheT0iMTQ0\
MCIgU2NoZWR1bGVkPSIxIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFtZT0idXBnc2NoZWQiIFBh\
dGg9Ii91c3IvYmluL2F1dG91cGciPgoJPEFyZ3M+LXM8L0FyZ3M+Cgk8U3lzT3B0aW9uIERheXM9\
IjEiIFNjaGVkdWxlZD0iMSIgU3RhcnRUaW1lPSIwNDowMCIvPgo8L1Byb2dyYW0+CjxQcm9ncmFt\
IE5hbWU9ImNlcnRjaGsiIFBhdGg9Ii91c3IvYmluL3NvaG9jZXJ0Ij4KCTxTeXNPcHRpb24gRGF5\
cz0iMzAiIFNjaGVkdWxlZD0iMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9InJhaWRjaGsi\
IFBhdGg9Ii9iaW4vc2giPgoJPEFyZ3M+L3Vzci9iaW4vcmFpZGNoZWNrPC9BcmdzPgoJPFN5c09w\
dGlvbiBEYXlzPSIzMSIgU2NoZWR1bGVkPSIxIiBTdGFydFRpbWU9IjAyOjAwIi8+CjwvUHJvZ3Jh\
bT4KPFByb2dyYW0gRGlzYWJsZT0iMSIgTmFtZT0iYWZwZCIgUGF0aD0iL3Vzci9zYmluL25ldGF0\
YWxrIj4KCTxBcmdzPi1kIC1GIC9tbnQvc3lzdGVtL2NvbmZpZy9uZXRhdGFsay9hZnAuY29uZjwv\
QXJncz4KCTxTeXNPcHRpb24gTWF4TWVtPSIzMk0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4K\
PFByb2dyYW0gTmFtZT0iaW1nZCIgUGF0aD0iL3Vzci9sb2NhbC9pbWdkL2ltZ2QiPgoJPFN5c09w\
dGlvbiBNYXhNZW09IjE1ME0iIFJlc3RhcnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFt\
ZT0ibGxkMmRfbGF1bmNoIiBQYXRoPSIvYmluL3NoIj4KCTxBcmdzPi91c3IvbG9jYWwvd2luUmFs\
bHkvbGxkMmRfbGF1bmNoLnNoPC9BcmdzPgoJPFN5c09wdGlvbiBJbml0T25seT0iMSIgTm9FcnJv\
cnM9IjEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBEaXNhYmxlPSIxIiBOYW1lPSJyc3luYyIgUGF0\
aD0iL3Vzci9iaW4vcnN5bmMiPgoJPEFyZ3M+LS1kYWVtb248L0FyZ3M+Cgk8QXJncz4tLW5vLWRl\
dGFjaDwvQXJncz4KCTxBcmdzPi0tY29uZmlnPS9tbnQvc3lzdGVtL2NvbmZpZy9yc3luY2QuY29u\
ZjwvQXJncz4KCTxTeXNPcHRpb24gTWF4TWVtPSI5Nk0iIE5pY2U9IjciIFJlc3RhcnQ9Ii0xIi8+\
CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFtZT0iY2hrdmFyZGlmZiIgUGF0aD0iL2Jpbi9zaCI+Cgk8\
QXJncz4vdXNyL2Jpbi9jaGt2YXJkaWZmLnNoPC9BcmdzPgoJPFN5c09wdGlvbiBNYXhNZW09IjMy\
TSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBOYW1lPSJzb2hvQXVkaXQiIFBh\
dGg9Ii9iaW4vc2giPgoJPEFyZ3M+L3Vzci9iaW4vc29ob0F1ZGl0PC9BcmdzPgoJPFN5c09wdGlv\
biBNYXhNZW09Ijk2TSIgUmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8UHJvZ3JhbSBOYW1lPSJj\
cC1odHRwZC1jb252ZXJ0IiBQYXRoPSIvdXNyL2xvY2FsL2NwLXV0aWxzL2NwLWh0dHBkLWNvbnZl\
cnQiPgoJPFN5c09wdGlvbiBJbml0T25seT0iMSIgTm9FcnJvcnM9IjEiLz4KPC9Qcm9ncmFtPgo8\
UHJvZ3JhbSBOYW1lPSJhcGFjaGUiIFBhdGg9Ii91c3IvbG9jYWwvYXBhY2hlL2Jpbi9odHRwZCI+\
Cgk8QXJncz4tRCBOT19ERVRBQ0g8L0FyZ3M+Cgk8QXJncz4tZiAvcmFtL2h0dHBkLmNvbmY8L0Fy\
Z3M+Cgk8QXJncz4tayBzdGFydDwvQXJncz4KCTxTeXNPcHRpb24gTWF4TWVtPSIyME0iIFJlc3Rh\
cnQ9Ii0xIi8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gRGlzYWJsZT0iMSIgTmFtZT0icHJvdG9tZ3Jk\
IiBQYXRoPSIvdXNyL2xvY2FsL3Byb3RvbWdyZC9wcm90b21ncmQiPgoJPFN5c09wdGlvbiBNYXhN\
ZW09Ijk2TSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIERpc2FibGU9IjEiIE5hbWU9ImF0ZnRwZCIg\
UGF0aD0iL3Vzci9zYmluL2F0ZnRwZCI+Cgk8U3lzT3B0aW9uIE1heE1lbT0iMzJNIiBSZXN0YXJ0\
PSItMSIvPgo8L1Byb2dyYW0+CjxQcm9ncmFtIE5hbWU9InBjbG91ZGQiIFBhdGg9Ii91c3IvbG9j\
YWwvcGNsb3VkZC9wY2xvdWRkIj4KCTxTeXNPcHRpb24gTWF4TWVtPSIyME0iIFJlc3RhcnQ9Ii0x\
Ii8+CjwvUHJvZ3JhbT4KPFByb2dyYW0gTmFtZT0iYWN0aXZlZm9sZGVyIiBQYXRoPSIvdXNyL2xv\
Y2FsL2FjdGl2ZWZvbGRlci9hY3RpdmVmb2xkZXIiPgoJPFN5c09wdGlvbiBNYXhNZW09IjUwTSIg\
UmVzdGFydD0iLTEiLz4KPC9Qcm9ncmFtPgo8L0dyb3VwPgoKPEdyb3VwIExldmVsPSIzIj4KCTxQ\
cm9ncmFtIERpc2FibGU9IjEiIE5hbWU9ImRhdGFtb3ZlciIgUGF0aD0iL3Vzci9sb2NhbC9kYXRh\
bW92ZXIvZGF0YW1vdmVyIj4KCQk8U3lzT3B0aW9uIE1heE1lbT0iOTZNIiBSZXN0YXJ0PSItMSIv\
PgoJPC9Qcm9ncmFtPgoJPFByb2dyYW0gTmFtZT0iY29ubmVjdGQiIFBhdGg9Ii91c3IvbG9jYWwv\
Y29ubmVjdGQvY29ubmVjdGQiPgoJCTxTeXNPcHRpb24gTWF4TWVtPSI5Nk0iIFJlc3RhcnQ9Ii0x\
Ii8+Cgk8L1Byb2dyYW0+Cgk8UHJvZ3JhbSBOYW1lPSJxdWlrdHJhbnNmZXIiIFBhdGg9Ii91c3Iv\
bG9jYWwvcXVpa3RyYW5zZmVyL3F1aWt0cmFuc2ZlciI+CgkJPFN5c09wdGlvbiBNYXhNZW09Ijk2\
TSIgUmVzdGFydD0iLTEiLz4KCTwvUHJvZ3JhbT4KICAgIAk8UHJvZ3JhbSBOYW1lPSJhbWF6b24i\
IFBhdGg9Ii91c3IvbG9jYWwvYW1hem9uL2FtYXpvbiI+CgkJPFN5c09wdGlvbiBNYXhNZW09Ijk2\
TSIgUmVzdGFydD0iLTEiLz4KCTwvUHJvZ3JhbT4KPC9Hcm91cD4KCjxHcm91cCBMZXZlbD0iNCI+\
CjwvR3JvdXA+CjwvUHJvY2Vzc2VzPgo=\
 
#end_sohoprocs

# This is a work in progress. See the to-do file on my github page https://github.com/5p0ng3b0b/ix4-300d.
# todo: write routine to re-install if it is reverted to stock after firmware update 
# Check if this script is set to run at boot.
# If not, automatically add it to /usr/local/cfg/sohoProcs.xml by restoring it from sohoprocs variable.
INIT_SCRIPT=$(readlink -f "$0"); # get path and name of this file.
BOOT_FILE="/usr/local/cfg/sohoProcs.xml"
if [ -z "$(cat $BOOT_FILE | grep INIT_SCRIPT)" ]; then log "init-opt.sh missing from sohoProcs.xml"; fi

# Start the user startup script
# Put stuff you want to run at boot in /mnt/pools/A/A0/init-user.sh.

[ -f "/mnt/pools/A/A0/init-user.sh" ] && nohup sh init-user.sh &

# Added for testing this script. Usually, this script runs at boot.
echo "Type ctrl-c to exit."
log "init-opt.sh completed, script sleeping"
# If this script ends or exits without a reboot
# and it has been started from /usr/local/cfg/sohoProcs.xml, you
# could trash your system and lose all data. Nice one Lenovo!
# Visit https://mega.nz/#F!b9N2XQzZ!hdhSgCK0VQlPbYpyOXTmYA to
# download a usb flashable firmware should you bork your NAS.
# You cannot get such firmware or any support from the Lenovo dinlos.
sleep infinity
reboot
exit
