#!/bin/bash

## install required dependencies
## they are listed in this file:
dependencies="./dependencies.txt"

info()
{
	## display info line to stderr
	msg=$(printf "$@")
	printf "$msg\n" >&2
}

error()
{
	msg=$(printf "$@")
	printf "\033[91m%s\033[0m\n" "$msg" >&2
}


# Check if user is root.
if [[ $(id -u) != 0 ]]; then
	error "Script must be run as root"
	exit 1
fi

if [[ $(command -v pacman) ]]; then
	install_cmd="pacman --noconfirm -S"
elif [[ $(command -v apt-get) ]]; then
	install_cmd="apt-get install -y"
elif [[ $(command -v yum) ]]; then
	install_cmd="yum install -y"
else
	error "Can't determine OS package manager"
	exit 1
fi

info "found package manager: %s" $( cut -d ' ' -f1 <<< $install_cmd)


# Check for missing dependencies and install.
while read pkg; do
	command -v $pkg >/dev/null 2>&1
	if [[ $? != 0 ]]; then
		info "$pkg required, installing..."
		# $install_cmd pkg
	else
		info "$pkg is installed"
	fi
done < "$dependencies"

info "done"
