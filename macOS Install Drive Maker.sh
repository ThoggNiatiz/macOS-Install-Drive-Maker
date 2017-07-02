#!/bin/sh


if (( $EUID != 0 )); then

    echo "macOS Install Drive Maker needs to be run as superuser"
    sudo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    exit
fi


function header
{

	clear
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+                          macOS Install Drive Maker                           +"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo

	if [ "$Installer" != "" ]; then
		echo "> Selected $Installer"
	fi
	if [ "$Disk" != "" ]; then
		echo "> Selected $Disk"
	fi
	if [ "$setMessageFormat" != "" ]; then
		echo "> Step 1: Format $Disk"
	fi
	if [ "$setMessageMountESD" != "" ]; then
		echo "> Step 2: Mount $InstallESD"
	fi
	if [ "$setMessageCopyBaseSystem" != "" ]; then
		echo "> Step 3: Copy Base System to Disk"
	fi
	if [ "$setMessageCopyPackages" != "" ]; then
		echo "> Step 4: Copy Packages to Disk"
	fi
	if [ "$setMessageCleanup" != "" ]; then
		echo "> Step 5: Cleaning up"
	fi
	if [ "$setMessageDone" != "" ]; then
		echo "> Done!"
	fi
	if [ "$setAbort" != "" ]; then
		echo "> Error: Task aborted"
	fi

	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}


while [ 1 ]; do

	header
	i=0
	installer=()

	echo "Available Installers:"
	echo

	for package in /Applications/Install\ macOS\ *.app; do
		if [[ $package != "/Applications/Install macOS *.app" ]]; then
			let i++
			installer+=("${package#/Applications/}")
			echo "($i)\t${package#/Applications/}"
		fi
	done

	for package in /Applications/Install\ OS\ X\ *.app; do
		if [[ $package != "/Applications/Install OS X *.app" ]]; then
			let i++
			installer+=("${package#/Applications/}")
			echo "($i)\t${package#/Applications/}"
		fi
	done

	echo

	if [[ $i == 0 ]]; then

		header
		echo "Couldn't find Install Packages in Applications"
		echo
		echo "Please download an macOS / OS X Installer from App Store"
		echo
		echo "Thanks for using macOS Install Drive Maker"
		echo "by Thogg Niatiz - github.com/ThoggNiatiz"
		echo
		exit

	elif [[ $i == 1 ]]; then

		Installer="$(echo ${installer[0]} | rev | cut -c 5- | rev)"
		break

	else

		read -p "Choose Installer: " input
		if [[ $input != "" ]]; then

			if [[ ${#installer[@]}+1 > $input ]] && [[ $input > 0 ]]; then

				Installer="$(echo ${installer[$input-1]} | rev | cut -c 5- | rev)"
				break

			fi

		fi

	fi

done



while [ "$(ls "/Volumes/" | grep "ESD")" != "" ]; do

	image=$(diskutil list | grep "ESD" | rev | awk '{print $1}' | rev)
	hdiutil detach "/dev/$image"

done


while [ 1 ]; do

	header
	disks=()

	echo "Available target disks:"
	echo


	for volume in /dev/disk*; do

		identifier=${volume#/dev/}
		
		if [[ "$(echo $identifier | cut -f 2 -d "k")" != *"s"* ]]; then

			i="$(echo $identifier | cut -f 2 -d "k" | cut -f 1 -d "s")"
			disks+=("$i")
			echo "($i)\t$identifier"

		else

			if [[ "$(diskutil info $identifier | grep "Volume Name:" | awk '{print $3$4}')" != "Notapplicable" ]]; then
				echo "$(diskutil info $identifier | grep "Volume Name:" | cut -f 2 -d ":")"
			fi

		fi

	done

	echo

	read -p "Choose target disk: " input
	if [[ $input != "" ]]; then

		if [ -b "/dev/disk$input" ]; then

			echo "/dev/disk$input"
			Disk="disk$input"
			break

		fi

	fi

done


setMessageFormat="true"
header
echo "Ready to make an Install Disk"
echo "This will delete all data on $Disk and create an Install Disk"
echo

read -p "Enter START to continue: " input

if [[ $input != "START" ]]; then
	setAbort="true"
	header
	echo "Wrong input"
	exit
fi


diskutil eraseDisk JHFS+ "$Installer" "$Disk"

if [ "$(ls "/Volumes/" | grep "$Installer")" == "" ]; then
	setAbort="true"
	header
	echo "Formatting failed"
	exit
fi


setMessageMountESD="true"
header
hdiutil attach "/Applications/$Installer.app/Contents/SharedSupport/$(ls "/Applications/$Installer.app/Contents/SharedSupport/" | grep "ESD")"
InstallESD="$(ls "/Volumes/" | grep "ESD")"

if [ "$(ls "/Volumes/" | grep "$InstallESD")" == "" ]; then
	setAbort="true"
	header
	echo "Mounting failed"
	exit
fi


setMessageCopyBaseSystem="true"
header
echo "Copying. This might take a while..."

if [[ "$(ls "/Applications/$Installer.app/Contents/SharedSupport/" | grep "Base" | grep "dmg")" != "" ]]; then
	asr restore --verbose --source "/Applications/$Installer.app/Contents/SharedSupport/$(ls "/Applications/$Installer.app/Contents/SharedSupport/" | grep "Base" | grep "dmg")" --target "/Volumes/$Installer" --erase --noprompt
	diskutil rename "$(ls "/Volumes/" | grep "Base")" "$Installer"
	rsync --progress "/Applications/$Installer.app/Contents/SharedSupport/$(ls "/Applications/$Installer.app/Contents/SharedSupport/" | grep "Base" | grep "chunklist")" "/Volumes/$Installer"
	rsync --progress "/Applications/$Installer.app/Contents/SharedSupport/$(ls "/Applications/$Installer.app/Contents/SharedSupport/" | grep "Base" | grep "dmg")" "/Volumes/$Installer"
fi

if [[ "$(ls "/Volumes/$InstallESD/" | grep "Base" | grep "dmg")" != "" ]]; then
	asr restore --verbose --source "/Volumes/$InstallESD/$(ls "/Volumes/$InstallESD/" | grep "Base" | grep "dmg")" --target "/Volumes/$Installer" --erase --noprompt
	diskutil rename "$(ls "/Volumes/" | grep "Base")" "$Installer"
	rsync --progress "/Volumes/$InstallESD/$(ls "/Volumes/$InstallESD/" | grep "Base" | grep "chunklist")" "/Volumes/$Installer"
	rsync --progress "/Volumes/$InstallESD/$(ls "/Volumes/$InstallESD/" | grep "Base" | grep "dmg")" "/Volumes/$Installer"
fi

if [ "$(ls "/Volumes/$Installer/" | grep "Install")" == "" ]; then
	setAbort="true"
	header
	echo "Base DMG could not get restored"
	exit
fi

if [ "$(ls "/Volumes/$Installer/" | grep "$Base" | grep "chunklist")" == "" ]; then
	setAbort="true"
	header
	echo "Base Chunklist could not get copied"
	exit
fi

if [ "$(ls "/Volumes/$Installer/" | grep "$Base" | grep "dmg")" == "" ]; then
	setAbort="true"
	header
	echo "Base DMG could not get copied"
	exit
fi


setMessageCopyPackages="true"
header
rm -rf "/Volumes/$Installer/System/Installation/Packages"
echo "Copying packages. This might take a while..."
rsync -r --progress "/Volumes/$InstallESD/Packages/" "/Volumes/$Installer/System/Installation/Packages/"

if [ "$(ls "/Volumes/$Installer/System/Installation/Packages/")" == "" ]; then
	setAbort="true"
	header
	echo "Copying packages failed"
	exit
fi


setMessageCleanup="true"
header
chflags -hf hidden "/Volumes/$Installer/"*
chflags -f nohidden "/Volumes/$Installer/$Installer.app"
rm -rf "/Volumes/$Installer/.fseventsd"
rm -rf "/Volumes/$Installer/.Spotlight-V100"
rm -rf "/Volumes/$Installer/.vol"

while [ "$(ls "/Volumes/" | grep "ESD")" != "" ]; do

	image=$(diskutil list | grep "ESD" | rev | awk '{print $1}' | rev)
	hdiutil detach "/dev/$image"

done

disk=$(diskutil list | grep "$Installer" | rev | awk '{print $1}' | rev)
diskutil unmount "/dev/$disk";
diskutil mount "/dev/$disk";


setMessageDone="true"
header
echo
echo "Thanks for using macOS Install Drive Maker"
echo "by Thogg Niatiz - github.com/ThoggNiatiz"
echo
