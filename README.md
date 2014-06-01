android-automation
==================

A collection of useful/convenient scripts for android automation testing. Note that these will only work on a Mac.

RunUnityTestAndroid:
==================

This script will automatically start up all available Genymotion emulators (make sure they are ARM enabled if you want to run Unity builds on them. Please refer here to do this: http://forum.xda-developers.com/showthread.php?t=2528952), install the Unity test apk onto each of the devices, output the respective LogCat results for each device, and report on whether tests failed or passed. The script will also shut down all emulators after it is done, or if the timeout limit has been reached. This process runs in parallel for each device : )

In order to use this properly, you will have to make sure you are logging some type of message in Unity to indicate that your tests have failed and completed. Make sure you have a flag message for when an individual test fails(Eg. INDIVIDUAL TEST FAILED), and when the entire suite of tests is done(Eg. ALL TESTS COMPLETED). 

1. Create a new folder Eg. MyUnityProjectTests
2. Inside that new folder, create another folder called Builds
3. Save/Copy/Export the Unity test builds you want to run into the Builds folder
4. Run RunUnityTestAndroid.sh and make sure to pass in the proper variables:
      project directory (-d)
      application name (-n)
      timeout(minutes) (-t)
      APK name(-a)  
      IndividualStopFlag(-i)
      and GlobalStopFlag(-g)

An example call would be:

./RunUnityTestsAndroid.sh -d ~/Projects/Unity/MyUnityProjectTests -n MyGame -t 5 -a MyGameTests.apk -i "INDIVIDUAL TEST FAILED" -g "ALL TESTS COMPLETED"


