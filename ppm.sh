#!/bin/bash
# PPM - Personal Password Manager
# Fork of pwm that relies on vim with the gnupg plugin to handle passwords
# Safer than the temporary file apporach used by regular pwm.
#
# In addition to a working gnupg setup with a valid recipient (yourself usually),
# this version also requires a working vim + gnupg plugin setup.

# init
pwinit(){

PPMRC="$HOME/.ppm/.ppmrc"
PPM_INSTALL_PATH="/usr/local/bin/ppm"
SELFPATH=$( cd $(dirname $0) ; pwd -P )

#term colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
GRAY=$(tput setaf 7)
DARKGRAY=$(tput setaf 8)
LRED=$(tput setaf 9)
LGREEN=$(tput setaf 10)
LYELLOW=$(tput setaf 11)
LBLUE=$(tput setaf 12)
LMAGENTA=$(tput setaf 13)
LCYAN=$(tput setaf 14)
WHITE=$(tput setaf 15)
DEF=$(tput sgr0)

# Binaries check
hash md5 2>/dev/null && md5bin="md5"
hash md5sum 2>/dev/null && md5bin="md5sum"
[[ -z "$md5bin" ]] && utpf "md5/md5sum binary not found, please install."
hash gpg 2>/dev/null || utpf "GPG binary not found, please install."

# cfg check
if ! fver "$PPMRC"; then
	utpw "Can't find ${CYAN}'$PPMRC'${DEF}."
	utpnc "Do you want to initiate the ${CYAN}setup wizard${DEF}? [Y/n] "
	read -n 1 setup
	[[ "$setup" != [nN] ]] && setuppm
fi
fver "$PPMRC" || utpf "Can't load ${CYAN}'$PPMRC'${DEF}, please create." && source "$PPMRC"

#pw storage check
dver "$PDIR" || utpf "Password dir ${CYAN}'$PDIR'${DEF} not found"
}
# /init

# ppm setup
setuppm(){
			utp
			utp "### PPM SETUP ###"

			if  ! hash ppm 2>/dev/null && ! fver "$PPM_INSTALL_PATH"; then
				utpnc "Do you wish to copy ppm to \"$PPM_INSTALL_PATH\"? (might require sudo.) [Y/n]"
				read -n 1 ppmcopy
				[[ -z "$ppmcopy" ]] || echo
				if [[ "$ppmcopy" != [nN] ]]; then
					if touch "$PPM_INSTALL_PATH"; then
						cat SELFPATH > "$PPM_INSTALL_PATH"
						chmod +x "$PPM_INSTALL_PATH"
						utp "Installed to \"$PPM_INSTALL_PATH\"."
					else
						if ! hash sudo; then
							utpw "Could not install. Permission denied and sudo not installed"
						else
							utp "No permission, attempting with sudo:"
							if sudo touch "$PPM_INSTALL_PATH"; then
								sudo cp -f $SELFPATH/ppm "$PPM_INSTALL_PATH"
								sudo chmod +x "$PPM_INSTALL_PATH"
								utp "Installed to \"$PPM_INSTALL_PATH\"."
							else
								utpw "Could not install. Permission denied."
							fi
						fi
					fi
				fi
			fi


			unset complete
			while [[ -z "$complete" ]]; do
				utpnc "What recipient will be used for GPG encryption? (Must be present in GPG keychain): "
				read srecepient &&
				if [[ -z "$srecepient" ]];then
					utpw "Recipient can not be empty."
				else
					echo -n "$LBLUE"
					gpg --list-keys $srecepient && complete=true || utpw "Could not find identity in GPG keychain."
				fi
			done

			unset complete
			while [[ -z "$complete" ]]; do
				utpnc "Where do you want to store passwords? [Def: $HOME/.ppm/pw]: "
				read spdir && [[ -z "$spdir" ]] && spdir="$HOME/.ppm/pw"
				exsw "mkdir -p "$spdir""
				dver "$spdir" && complete=true || utpw "Directory not valid."
			done

			unset complete
			cd "$spdir"
			while [[ -z "$complete" ]]; do
				srepo=n

				if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
					utp "Password directory seems to reside within a git repo."
					utp "ppm can push/pull to master branch, so that your encryped passwords are stored in the repo"
					utp "Enable this only if you know the implications/risks involved."
					utpnc "Do you want to enable git sync? [y/N] "
					read -n 1 srepo
					[[ "$srepo" == [yY] ]] && srepo="Y" && utp "Repo sync will be ${CYAN}enabled" || srepo="N" && utp "Repo sync will be ${CYAN}disabled"
					complete=true
				else
					utp "Could not detect git in pw dir, skipping repo step. (reposync can be enabled manually in .ppmrc)"
					complete=true
				fi
			done

			unset complete
			[[ "$srepo" == "Y" ]] && srepo="enabled" || srepo="disabled"
			while [[ -z "$complete" ]]; do
				utp "PPM is ready to write the following to ${CYAN}$PPMRC"
				echo -e "${YELLOW}RECEPIENT=\"$srecepient\"\nREPOSYNC=\"$srepo\"\nPDIR=\"$spdir\""
				utpnc "Save settings to file? [Y/n] "
				read -n 1 sconfirm
				[[ -z "$sconfirm" ]] || echo
				if [[ "$sconfirm" != [nN] ]]; then
					utpn "Writing and verifying configuration..."
					echo "### PPM configuration ###" > "$PPMRC"
					fver "$PPMRC" || utpf "Could not write to ${CYAN}$PPMRC${DEF}. Please check."
					echo -e "RECEPIENT=\"$srecepient\"\nREPOSYNC=\"$srepo\"\nPDIR=\"$spdir\"" >> "$PPMRC"
					source "$PPMRC"
					[[ "$RECEPIENT" == "$srecepient" ]] || utpf "Failed to verify config from .ppmrc (RECEPIENT)"
					[[ "$REPOSYNC" == "$srepo" ]] || utpf "Failed to verify config from .ppmrc (REPOSYNC)"
					[[ "$PDIR" == "$spdir" ]] || utpf "Failed to verify config from .ppmrc (PDIR)"
					utg
				fi
				complete=true
			done
}

# /ppm setup

# exec helpers
exsw(){
	eval "$@"
	[[ "$?" -ne 0 ]] && utpw "${CYAN}'$@'${DEF} returned non-zero exitcode"
}

exsf(){
	eval "$@"
	[[ "$?" -ne 0 ]] && utpf "${CYAN}'$@'${DEF} returned non-zero exitcode" && exit
}
# /exec helpers

# tty write helpers
utp(){
	echo -e "${RED}ppm${DARKGRAY}# ${DEF}$1${DEF}"
}


utpn(){
	echo -en "${RED}ppm${DARKGRAY}# ${DEF}$1${DEF}"
}

utpnc(){
	echo -en "${RED}ppm${DARKGRAY}# ${DEF}$1${LYELLOW}"
}

utpw(){
	echo -e "${RED}ppm${DARKGRAY}# ${YELLOW}WARN: ${DEF}$1${DEF}"
}

utpf(){
	echo -e "${RED}ppm${DARKGRAY}# ${LRED}FATAL: ${DEF}$1${DEF}"
	exit
}

ut(){
	echo -e "$1 $DEF"
}

utg(){
	echo -e "${GREEN} OK${DEF}"
}

utn(){
	echo -en "$1 $DEF"
}

# /tty write helpers

# fs tests
dver(){
	[[ -d "$1" ]]
}

fver(){
	[[ -f "$1" ]]
	#echo $?
}

# /fs tests

# checksum related
sumbin(){
	[[ md5bin == "md5sum" ]] &&	echo $(md5sum "$1" | cut -c -32) || echo $(md5 -q "$1")
}

sumver(){
	[[ $(sumbin "$1") == $(sumbin "$2") ]] && true || false
}
# /checksum related

# fs operations
sdel(){
	if hash srm 2>/dev/null; then
        srm "$1"
    else
    	utpw "srm not found, using plain rm for deletion"
        rm -f "$1"
    fi
}
# /fs operations
