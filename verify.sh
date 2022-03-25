#!/bin/bash

###################
# Signature Check #
###################

sig_check() { #1 = /opt/root/mdm #2 = 281248c2cf9f2a3db2ebde2a.apk
	jarsigner -verify "$1/$2" 2>/dev/null >/dev/null # checks if the apk is jar signed 
	if [[ $? -eq 0 ]]; then
		echo '[+] Signature Check Passed'
	else
		echo '[!] Signature Check Failed. Invalid Certificate.'
		cleanup
		exit
	fi
}

#######################
# Compatibility Check #
#######################

comp_check() { #1 = /root/mdm/apk_bin #2 = 281248c2cf9f2a3db2ebde2a.apk #3 = /root/mdm/process_bin``
	apktool d -s "$1/$2" -o $3 2>/dev/null >/dev/null
	COMPILE_SDK_VER=$(grep -oPm1 "(?<=compileSdkVersion=\")[^\"]+" "$PROCESS_BIN/AndroidManifest.xml")
	if [ -z "$COMPILE_SDK_VER" ]; then
		echo '[!] Failed to find target SDK version.'
		cleanup
		exit
	else
		if [ $COMPILE_SDK_VER -lt 18 ]; then
			echo "[!] APK Doesn't meet the requirements"
			cleanup
			exit
		fi
	fi
}

####################
# Basic App Checks #
####################

app_check() { #1 = /root/mdm/process_bin #2 = /root/mdm/certified_apps #3 = /root/mdm/apk_bin #4 = out.apk
	APP_NAME=$(grep -oPm1 "(?<=<string name=\"app_name\">)[^<]+" "$1/res/values/strings.xml")
	echo $APP_NAME
	if [[ $APP_NAME == *"Catch"* ]]; then
		echo -n $APP_NAME|xargs -I {} sh -c 'mkdir {}'
		mv "$3/$APK_NAME" "$2/$APP_NAME/$4"
	else
		echo "[!] App doesn't belong to Catch Global"
		cleanup
		exit
	fi
}


###########
# Cleanup #
###########

cleanup() {
	rm -rf $PROCESS_BIN;rm -rf "$DROPBOX/*" "$IN_FOLDER/*";rm -rf $(ls -A /opt/mdm | grep -v apk_bin | grep -v verify.sh)
}


###################
# MDM CheckerV1.0 #
###################

DROPBOX=/opt/mdm/apk_bin
IN_FOLDER=/root/mdm/apk_bin
OUT_FOLDER=/root/mdm/certified_apps
PROCESS_BIN=/root/mdm/process_bin

for IN_APK_NAME in $DROPBOX/*.apk;do #runs over the files in /opt/mdm/apk_bin 
	OUT_APK_NAME="$(echo ${IN_APK_NAME##*/} | cut -d '.' -f1)_verified.apk"
	APK_NAME="$(openssl rand -hex 12).apk" #Generates a random 12 chars long hexvalue e.g 281248c2cf9f2a3db2ebde2a.apk
	if [[ -L "$IN_APK_NAME" ]]; then #if the apk is a symbolic link exit
		exit
	else # else move our.apk -> /root/mdm/apk_bin/281248c2cf9f2a3db2ebde2a.apk
		mv "$IN_APK_NAME" "$IN_FOLDER/$APK_NAME"
	fi
	sig_check $IN_FOLDER $APK_NAME
	comp_check $IN_FOLDER $APK_NAME $PROCESS_BIN #1 = /root/mdm/apk_bin #2 = 281248c2cf9f2a3db2ebde2a.apk #3 = /root/mdm/process_bin
	app_check $PROCESS_BIN $OUT_FOLDER $IN_FOLDER $OUT_APK_NAME #1 = /root/mdm/process_bin #2 = /root/mdm/certified_apps #3 = /root/mdm/apk_bin #4 = out.apk
done
cleanup
