#!/bin/bash
## Parameter Definitions
while getopts d:n:t:a:i:g: option
do
        case "${option}"
        in
                d) PROJECT_DIR=${OPTARG};;
                n) PACKAGE_NAME=${OPTARG};;
				t) TIME_OUT=${OPTARG};;
				a) BUILD_NAME=${OPTARG};;
				i) STOP_FLAG_INDIVIDUAL=${OPTARG};;
				g) STOP_FLAG_ALL=${OPTARG};;
        esac
done
ERRORMSSG="ERROR Please enter a project directory (-d), application name (-n), timeout(minutes) (-t), APK name(-a),  IndividualStopFlag(-i), and GlobalStopFlag(-g) "
if [ -z $PROJECT_DIR ]; then
	echo No project directory
	echo $ERRORMSSG
	exit 1
fi
if [ -z $PACKAGE_NAME ]; then
	echo No app name
	echo $ERRORMSSG
	exit 1
fi
if [ -z $TIME_OUT ]; then
	echo No Time Out
	echo $ERRORMSSG
	exit 1
fi
if [ -z $BUILD_NAME ]; then
	echo No APK name
	echo $ERRORMSSG
	exit 1
fi
if [ -z "$STOP_FLAG_INDIVIDUAL" ]; then
	echo No STOP_FLAG_INDIVIDUAL 
	echo $ERRORMSSG
	exit 1
fi
if [ -z "$STOP_FLAG_ALL" ]; then
	echo No STOP_FLAG_ALL 
	echo $ERRORMSSG
	exit 1
fi

cd $PROJECT_DIR

echo "Create Log Folders if they don't exist"
if [ ! -d $PROJECT_DIR/Logs ]; then
        mkdir $PROJECT_DIR/Logs
fi

if [ ! -d $PROJECT_DIR/Logs/UnityAndroidTests/$BUILD_NAME ]; then
        mkdir $PROJECT_DIR/Logs/UnityAndroidTests/
        mkdir $PROJECT_DIR/Logs/UnityAndroidTests/$BUILD_NAME
fi

if [ -d $PROJECT_DIR/Logs/UnityAndroidTests/$BUILD_NAME ]; then
	echo Removing old logs
    rm $PROJECT_DIR/Logs/UnityAndroidTests/$BUILD_NAME/*
fi

echo Verifying Builds Folder
if [ ! -d $PROJECT_DIR/Builds ]; then
        mkdir $PROJECT_DIR/Builds
fi

#Check to see .apk is actually there
echo "Checking if $BUILD_NAME.apk exists"
if [ -e $PROJECT_DIR/Builds/$BUILD_NAME.apk ]; then
	echo "$BUILD_NAME.apk exists"
else
	echo "$BUILD_NAME.apk does not exist!"
	exit 1
fi

#Start ADB
echo "Checking if ADB exists"
adb start-server
#127 is command not found return code
if [ $?  == 127 ]; then
		echo "adb is either not installed or not set on PATH"
		exit 1;
else
		echo "adb was found"
fi

echo "Done starting ADB"

#Clean up previous log files
#rm "${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/*.log"
echo Touch Test Results
touch "${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/TestResults.log"

runAndCheck(){
		echo "Running ${PACKAGE_NAME}.apk on ${1}"
		adb -s "${1}" shell am start -n "${PACKAGE_NAME}/com.unity3d.player.UnityPlayerNativeActivity"
		echo "Done Installing on ${1}"

		trys=$[$TIME_OUT*60]
		echo "Checking for Completion for ${1}"
			while [ ${trys} -gt 0 ]
			do
				adb -s ${1} shell logcat -s -d Unity:D  | grep "$STOP_FLAG_ALL"
				if [ $? -eq 0 ]; then
					echo "Tests Finished for device: ${1}"
					adb -s ${1} shell logcat -s -d Unity:D  | grep "$STOP_FLAG_INDIVIDUAL"
					if [ $? -eq 0 ]; then 
							echo "Tests Failed for device ${1} on `date`" >> "${PROJECT_DIR}/Logs/UnityAndroidTests/${BUILD_NAME}/TestResults.log"
					fi 
					break
				fi
			trys=$[$trys-1]
			#In seconds
			sleep 1
			done
	if [ $trys -eq 0 ]; then
		echo "Timeout: Tests for ${1} took more than ${TIME_OUT} minutes"
		echo Killing Processes Now
			adb -s "${1}" shell am force-stop "${PACKAGE_NAME}"
	else
		echo "All Tests Done Running for ${1}"
			adb -s "${1}" shell am force-stop "${PACKAGE_NAME}"
	fi
	echo Writing To Logs
	echo "Done Tests for device: ${1} on `date`" >> "${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/TestResults.log"
	echo "LogCat Results for ${1}"
	cat ${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/LogCatUnity-${1:0:14}.log
	echo "================================================================="
}

cleanUp(){
	for item in `adb devices | egrep "^[^List of Devices attached]" | tr -d "device"`;
	do	
		adb -s "${item}" shell am force-stop "${PACKAGE_NAME}"
	done
	ps | grep "logcat" | awk '{print $1}' | xargs kill
	echo "Done Clean Up"
	shutdownGenyMotionDevices
}

startGenyMotionDevices(){
	#Start up Geny Motion Devices
	echo "Checking to see if Genymotion is installed"
	if [ -z `find /Applications/Genymotion.app/Contents/MacOS/player` ];then
		echo Genymotion is not installed...
		exit 1
	fi
	echo "Starting Genymotion Devices: Make sure your Firewall is turned off or devices may not start properly!"
	VBOX_ARRAY=`VBoxManage list vms | grep -oi "{.*}" | tr -d "{" |  tr -d "}"`
	VBoxManage list vms > ${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/DeviceList.txt
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
}

shutdownGenyMotionDevices(){
	echo Killing genymotions
	pkill player
	VBOX_ARRAY=`VBoxManage list vms | grep -oi "{.*}" | tr -d "{" |  tr -d "}"`
	for i in `echo $VBOX_ARRAY`;
	do		
		echo "Shutting down ${i}"
		VBoxManage controlvm ${i} poweroff 
		sleep 1 
	done
	adb kill-server
}

main(){	
	trap cleanUp SIGINT
	startGenyMotionDevices
	INSTALL=1
	FAIL=1
	#Get list of device ID's , install .apk on them, clear log, and run test
	DEVICE_LIST_INDEX=0
	#Geny Motion devices have an ID with all numbers, like an IP address
	#Regular devices have a mix of numbers and alphabet letters
	for item in `adb devices | egrep "^[^List of Devices attached]" | tr -d "device"`;
	do	
		#Uninstall apk on device if already installed
		adb -s ${item} shell pm list packages | grep "package:${PACKAGE_NAME}"
		if [ $? -eq 0 ]; then
				#Already installed, need to uninstall
			echo Need to Uninstall Previous Version
			adb -s "${item}" shell pm uninstall -k "${PACKAGE_NAME}"
			echo Done Uninstalling
		fi
			#clears log cat on device
		adb -s ${item} shell logcat -c
		nohup adb -s ${item} shell logcat -v time Unity:D >> "${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/LogCatUnity-${item:0:14}.log" &
		echo "Installing APK on device: ${item}"
		RESULT=`adb -s "${item}" install $PROJECT_DIR/Builds/$BUILD_NAME.apk` 
		#If fail install, should fail
		echo $RESULT | grep Failure
		if [ $? -eq 0 ]; then
			echo Could not install on device ${item}...
			INSTALL=0
			FAIL=0
		else
			DEVICE_LIST_INDEX=$[$DEVICE_LIST_INDEX+1]
			runAndCheck ${item} &
		fi
	done
	
	GLOBAL_TRYS=$[$TIME_OUT*60]
	while [ ${GLOBAL_TRYS} -gt 0 ]
	do
		if [  `cat ${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/TestResults.log | grep "Done" | wc -l` == $DEVICE_LIST_INDEX ] ; then
			break
		fi
		sleep 1
		GLOBAL_TRYS=$[$GLOBAL_TRYS-1]
	done
	if [ ${GLOBAL_TRYS} -le 0 ]; then
		cleanUp
		echo "Operation Timed Out! Whole operation took more than ${TIME_OUT} minutes"
		exit 1;
	fi
	echo "Done testing all devices"
	cleanUp
	if [ $INSTALL -eq 0 ];then
		echo "At least one device could not install the apk properly!"
	fi
	grep Failed ${PROJECT_DIR}/Logs/UnityAndroidTests/$BUILD_NAME/TestResults.log
	if [  $? -eq 0 ]; then
		echo "AT LEAST ONE TEST FAILED ON A DEVICE: Please check logs"
		FAIL=0
	fi
	echo Sleeping a bit before ending
	sleep 5
	if [ $FAIL -eq 0 ];then
		exit 1
	fi
	exit 0

}
main