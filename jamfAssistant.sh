#!/bin/bash


####################################################################################################
# This is designed to be used from Jamf Self Service on computers that have Standard accounts. 
# v1.0 created by mjerome 07252024
####################################################################################################

function dialogInstall() {
	
	# Get the URL of the latest PKG From the Dialog GitHub repo
	dialogURL=$(curl -L --silent --fail "https://api.github.com/repos/swiftDialog/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
	
	# Expected Team ID of the downloaded PKG
	expectedDialogTeamID="PWA5E9TQ59"
	
	echo "Installing swiftDialog..."
	
	# Create a temporary working directory
	workDirectory=$( basename "$0" )
	tempDirectory=$( mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
	
	# Download the installer package
	curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
	
	# Verify the download
	teamID=$(spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
	
	# Install the package if Team ID validates
	if [[ "$expectedDialogTeamID" == "$teamID" ]]; then
		/usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
		sleep 2
		dialogVersion=$( /usr/local/bin/dialog --version )
		preFlight "swiftDialog version ${dialogVersion} installed; proceeding..."
	else
		# Display a so-called "simple" dialog if Team ID fails to validate
		osascript -e 'display dialog "Please advise your Support Representative of the following error:\r\r• Dialog Team ID verification failed\r\r" with title "'"${scriptFunctionalName}"': Error" buttons {"Close"} with icon caution'
		exitCode="1"
		quitScript
	fi
	
	# Remove the temporary working directory when done
	rm -Rf "$tempDirectory"
	
}

function dialogCheck() {
	
	# Check for Dialog and install if not found
	if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
		echo "swiftDialog not found. Installing..."
		dialogInstall
	else
		dialogVersion=$(/usr/local/bin/dialog --version)
		if [[ "${dialogVersion}" < "${swiftDialogMinimumRequiredVersion}" ]]; then
			echo "swiftDialog version ${dialogVersion} found but swiftDialog ${swiftDialogMinimumRequiredVersion} or newer is required; updating..."
			dialogInstall
		else
			echo "swiftDialog version ${dialogVersion} found; proceeding..."
		fi
	fi
	
}

dialogCheck

iconPath="${4:-""}"
appTitle="${5:-"Jamf Assistant"}"

while [[ $selection != 4 ]]; do
	selection=$(dialog --icon ${iconPath} --title ${appTitle} --message "Use the selections below to run the most common Jamf tasks." --selecttitle "Select a function",radio --selectvalues "Collect Inventory, Policy by ID, Policy by Custom Trigger, General Policy Check, Exit"  | grep "SelectedIndex" | awk -F ": " '{print $NF}')
	echo $selection
	case $selection in
		0)

			command="/usr/local/bin/jamf recon"
			# Execute the command and capture its output
			output=$(sudo $command 2>&1)
			# Display the result in a dialog box
			dialog --big --icon ${iconPath} --title "Gathering Jamf Inventory" \
			--message "$output"\
			--icon "$iconPath"
		;;
		1)
			id=$(dialog --icon ${iconPath} --title ${appTitle} --message "Enter the desired policy number" --textfield "Policy ID" | grep "Policy ID" | awk -F ": " '{print $NF}' )
			command="/usr/local/bin/jamf policy -id ${id}"
			# Execute the command and capture its output
			output=$(sudo $command 2>&1)
			dialog --big --icon ${iconPath} --title "Executing Policy ${id}" \
			--message "$output"\
			--icon "$iconPath"
			
		;;
		2)
			customTrigger=$(dialog --icon ${iconPath} --title ${appTitle} --message "Enter the desired custom trigger" --textfield "Custom Trigger"| grep "Custom Trigger" | awk -F ": " '{print $NF}')
			command="/usr/local/bin/jamf policy -trigger ${customTrigger}"
			# Execute the command and capture its output
			output=$(sudo $command 2>&1)
			dialog --big --icon ${iconPath} --title "Executing Custom Policy Trigger ${customTrigger}" \
			--message "$output"\
			--icon "$iconPath"
		;;
		3)
			command="/usr/local/bin/jamf policy "
			# Execute the command and capture its output
			output=$(sudo $command 2>&1)
			dialog --big --icon ${iconPath} --title "Executing General Policy Check" \
			--message "$output"\
			--icon "$iconPath"

		;;
		4)
			exit 0
		;;
		*)
			dialog --icon ${iconPath} --title ${appTitle} --message "ERROR"
		;;
	esac
done