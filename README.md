DO NOT USE THIS FORK.
Currently there is a bug reported which I cannot replicate where the netcat session does not spawn on the camera.

This repository contains files related to the DCS-6100LH camera from D-Link.

In particular, it contains custom firmware intended for the camera.

# Main purpose of the custom firmware
1. Add a mechanism to setup the camera without using the official mydlink-app.
2. Add an optional telnet communications channel and reset the root password 

## What this custom firmware doesn't do:
1. It does not prevent communications with the d-link servers
2. It does not disable auto-updating, that is, if you want to prevent the camera to stop auto-updating you need to either:
a. disable auto update functionality in the mydlink-app
b. block internet access for the camera in your router.

# DISCLAIMER
This custom firwmare comes with NO WARRANTY. 
I am not to blame if something stops to work.
Changing the firmware is a large risk!

That said the firmware only updates application partitions, reverting back to original firmware should be entirely possible.


# Things of note:
This custom firmware is based on 1.03.03 due to that there are no offical downloads of the 1.04.05 firmware (as of writing this document).

# How to install:
0. Download the DCS6100LHAx_FW103B03-custom.bin
1. Power on the camera
2. Push the button on the back for at least 5 seconds to enter recovery mode
3. Camera should provide its own wireless network named DCS-XXXX
4. Connect to the network using the wifi password as provided on the sticker attached to the camera.
5. Using a web browser, access http://192.168.0.20/index.htm
6. Click the button on the web page and select the DCS6100LHAx_FW103B03-custom.bin file
7. After a minute or so the camera should reboot and rejoin it's previous wifi network or enter setup mode, orange light on the camera.

# How to use:
Custom functionality will by default only be enabled when in recovery mode.
1. Enter recovery mode by pushing the button on the back for 5 seconds. Camera LED on front should change color to red.
2. Camera will provide its own wireless network named DCS-XXX
3. Connect to the network using the wifi password as provided on the sticker attached to the camera. 
4. You can now access the vital SystemConfig.ini using a browser and accessing http://192.168.0.20/SystemConfig.ini
5. Make a local backup copy of this file as a precaution!
6. Modify your local copy of this file as you see fit. Check out SystemConfig-investigation for pointers on how to use different fields. Please note that not all fields are used and not all fields have been researched. The most important part are the Wifi setup parts since this will configure what AP the camera should connect to.
7. Once you are satisified, you can send the updated SystemConfig.ini file back to the camera using netcat on port 8001. That is, use the command: nc 192.168.0.20 8001 < SystemConfig.ini
8. If the netcat command returns the camera has received the file.
9. The camera will do a rudimentary check that the SystemConfig.ini file is correct by checking the first line. If the first line is [System] the updated SystemConfig.ini will be stored in the camera and the camera will reboot. Hopefully, if you updated the wifi settings the camera will connect to the network.

## How to enable telnet:
You can enable telnet by adding the string: Telnet = 1 in the SystemConfig.ini which you upload to the camera.

### Logging in
login using telnet, root password is a0n1ipc.
Original encrypted password is preserved in /mnt/conf/shadow.orig
Change password using passwd command

# Viewing the stream:
The stream can be accessed via:
rtsp://admin:pin@<cam-ip>:554/live/profile.0/video
E. g. rtsp://admin:123456@192.168.0.20:554/live/profile.0/video
Replace pin with the pin number located on the sticker on your camera.

# Future work
* Currently when blocking internet access the camera will not update the time, add a ntp client
* Investigate how to block mydlink access only
* Investigate if we can sniff the mydlink motion sensing

# Very future work
* Replace the supplied d-link software with a custom application performing the same tasks but without the mydlink integrtion.

# Credits
Thanks to:
mouldybread for writing good instructions on how to get started and how to find the rtsp url, https://github.com/mouldybread/DCS-6100LH
Wuseman for writing instruction on how to get access via serial, https://github.com/wuseman/DLink_6100LH/


