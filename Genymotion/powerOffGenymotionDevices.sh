#!/bin/bash
echo Killing genymotions
#ps | grep "Genymotion\.app/Contents/MacOS/player" | awk '{print $1}' | xargs kill
pkill player
VBOX_ARRAY=`VBoxManage list vms | grep -oi "{.*}" | tr -d "{" |  tr -d "}"`
for i in `echo $VBOX_ARRAY`;
do		
	echo "Shutting down ${i}"
	VBoxManage controlvm ${i} poweroff 
	sleep 1 
done
adb kill-server
