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

	fmt='%s'
	# add newline '\n' char
	endline=true

	## options:
	for arg in $@; do
	case $arg in
	'-n') # add a line break before message
		# fmt="\n${fmt}"
		printf "\n" >&2
		shift
		;;
	'-e') # do not add EOL character
		endline=false
		shift
		;;
	'-t') # title format, bold text
		fmt="\033[1m%s\033[0m"
		shift
		;;
	esac
	done

	msg=$(printf "$@")
	printf -- "$fmt" "$msg" >&2

	$endline && printf '\n' >&2
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



get_ip()
{
	info -n -t "probing for ip"
	ip=$(dig +short myip.opendns.com @resolver1.opendns.com || echo "failed")
	# exitcode=$?
	if [[ $ip == "failed" ]]; then
		error "failed to get ipv4"
		return 1
	else
		info "ip: $ip"
		return 0
	fi
}

get_gateway_interface()
{
	# look for internet gateway
	info -n -t "probing gateway"

	gates=""
	# which iface is connected to default (0.0.0.0) ?
	while read -r dest gateway xx flags xx xx xx iface; do
		# check iface is UP 
		[[ $flags =~ U ]] || continue
		debug "$iface is up"
		# check iface use gataway
		[[ $flags =~ G ]] || continue
		debug "$iface use gateway"
		gates+=$iface
	done <<< $(route | grep -i -e "^default")

	if [[ -z $gates ]]; then
		error "can't find a gateway interface"
		return 1
	else
		info "found gateway $gates"
		return 0
	fi
}

is_network_reachable()
{
	get_gateway_interface || return 1
	get_ip || return 1

	# success
	debug "network is available"
	return 0
}

