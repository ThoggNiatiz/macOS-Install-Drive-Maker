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

	if [ "$setInstaller" != "" ]; then
		echo "> Selected $setInstaller"
	fi
	if [ "$setDisk" != "" ]; then
		echo "> Selected $setDisk"
	fi
	if [ "$setMessageFormat" != "" ]; then
		echo "> Step 1: Format $setDisk"
	fi
	if [ "$setMessageMountESD" != "" ]; then
		echo "> Step 2: Mount $setInstallESD"
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

	echo
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

function unmountInstallESD
{

	volume=$(diskutil list | grep Mac\ OS\ X\ Install\ ESD | awk '{print $10}' | cut -f 2 -d "k" | cut -f 1 -d "s")
	if [ "$volume" != "" ]; then
		diskutil unmountDisk force "disk$volume"
	fi

	volume=$(diskutil list | grep OS\ X\ Install\ ESD | awk '{print $9}' | cut -f 2 -d "k" | cut -f 1 -d "s")
	if [ "$volume" != "" ]; then
		diskutil unmountDisk force "disk$volume"
	fi

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

		setInstaller="$(echo ${installer[0]} | cut -f 1 -d ".")"

		# early version workaround
		if [[ "${installer[0]}" == "Install OS X Snow Leopard.app" ]] || [[ "${installer[0]}" == "Install OS X Lion.app" ]] || [[ "${installer[0]}" == "Install OS X Mountain Lion.app" ]]; then
			setBaseSystem="Mac OS X Base System"
			setInstallESD="Mac OS X Install ESD"
		else
			setBaseSystem="OS X Base System"
			setInstallESD="OS X Install ESD"
		fi

		break

	else

		read -p "Choose Installer: " input
		if [[ $input != "" ]]; then

			if [[ ${#installer[@]}+1 > $input ]] && [[ $input > 0 ]]; then

				setInstaller="$(echo ${installer[$input-1]} | cut -f 1 -d ".")"

				# early version workaround
				if [[ "${installer[$input-1]}" == "Install OS X Snow Leopard.app" ]] || [[ "${installer[$input-1]}" == "Install OS X Lion.app" ]] || [[ "${installer[$input-1]}" == "Install OS X Mountain Lion.app" ]]; then
					setBaseSystem="Mac OS X Base System"
					setInstallESD="Mac OS X Install ESD"
				else
					setBaseSystem="OS X Base System"
					setInstallESD="OS X Install ESD"
				fi

				break

			fi

		fi

	fi

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
			setDisk="disk$input"
			break

		fi

	fi

done

setMessageFormat="true"
header
echo "Ready to make an Install Disk"
echo "This will delete all data on $setDisk and create an Install Disk"
echo

read -p "Enter START to continue: " input
if [[ $input != "START" ]]; then

	exit

fi


diskutil eraseDisk JHFS+ "$setInstaller" "$setDisk"

setMessageMountESD="true"
header
hdiutil attach "/Applications/$setInstaller.app/Contents/SharedSupport/InstallESD.dmg"

setMessageCopyBaseSystem="true"
header
echo "Copying. This might take a while..."
asr restore --verbose --source "/Volumes/$setInstallESD/BaseSystem.dmg" --target "/Volumes/$setInstaller" --erase --noprompt
diskutil rename "$setBaseSystem" "$setInstaller"
rsync --progress "/Volumes/$setInstallESD/BaseSystem.chunklist" "/Volumes/$setInstaller"
rsync --progress "/Volumes/$setInstallESD/BaseSystem.dmg" "/Volumes/$setInstaller"

setMessageCopyPackages="true"
header
rm -rf "/Volumes/$setInstaller/System/Installation/Packages"
echo "Copying packages. This might take a while..."
rsync -r --progress "/Volumes/$setInstallESD/Packages/" "/Volumes/$setInstaller/System/Installation/Packages/"

setMessageCleanup="true"
header
chflags -hf hidden "/Volumes/$setInstaller/"*
chflags -f nohidden "/Volumes/$setInstaller/$setInstaller.app"
rm -rf "/Volumes/$setInstaller/.fseventsd"
rm -rf "/Volumes/$setInstaller/.Spotlight-V100"
rm -rf "/Volumes/$setInstaller/.vol"
unmountInstallESD

setMessageDone="true"
header
echo
echo "Thanks for using macOS Install Drive Maker"
echo "by Thogg Niatiz - github.com/ThoggNiatiz"
echo