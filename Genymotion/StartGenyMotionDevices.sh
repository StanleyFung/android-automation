#!/bin/bash
	#Start up Geny Motion Devices
echo "Checking to see if Genymotion is installed"
if [ -z `find /Applications/Genymotion.app/Contents/MacOS/player` ];then
	echo Genymotion is not installed...
	exit 1
fi
echo "Starting Genymotion Devices: Make sure your Firewall is turned off or devices may not start properly!"
VBOX_ARRAY=`VBoxManage list vms | grep -oi "{.*}" | tr -d "{" |  tr -d "}"`
VBoxManage list vms > DeviceList.txt
for i in `echo $VBOX_ARRAY`;
do
	echo "Starting ${i}"
	/Applications/Genymotion.app/Contents/MacOS/player --vm-name "${i}" &
	sleep 1
done
SLEEP=45
echo "sleeping for ${SLEEP}"
sleep $SLEEP
echo Unlocking devices
for item in `adb devices | egrep "^[^List of Devices attached]" | tr -d "device"`;
do	
	adb -s ${item} shell input keyevent 82
done
echo Devices are ready to use!