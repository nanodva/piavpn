#!/bin/bash

# these are scripts shared by all programms

log()
{
	# print msg to log file $LOG
	msg=$(printf "$@")
	printf "%s\n" "$msg" >> $LOG
}

info()
{
	## display info line to stderr
	## usage: info [options] <message>
	#
	## message: is parsed with printf
	tag="info"
	fmt="${tag}: %s\n"
	## options:
	# case $1 in
	for arg in $@; do
	case $arg in
	# -n 	: add a line break before message
	'-n')	shift
			printf "\n" >&2
			;;
	# title format, bold text
	'-t')	shift
			fmt="\033[1m%s\033[0m\n"
			;;
	esac
	done

	msg=$(printf "$@")
	
	printf "$fmt" "$msg" >&2
}

error()
{
	msg=$(printf "$@")
	# printf "error: %s\n" "$msg"
	printf "\033[91m%s\033[0m\n" "$msg" >&2
}

debug()
{
	# be more verbose when global debug=true
	if [[ $debug ]]; then
		msg=$(printf "$@")
		# printf "debug: %s\n" "$msg"
		printf "\033[2m%s\033[0m\n" "$msg" >&2
	fi
}
