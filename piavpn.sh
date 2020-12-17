#!/bin/bash

## piavpn v0.1 Copyright (C) 2019 TaigaSan Corp <taigasan@sdf.org>
#
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License Version 2 as published by
## the Free Software Foundation.
#
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License at (http://www.gnu.org/licenses/) for
## more details.

### DECLARATIONS ###
# all folders name depends of Pname
PNAME=$(basename $0 .sh)

# Colour codes for terminal.
BOLD=$(printf "\033[1m")
BLUE=$(printf "\033[34m")
GREEN=$(printf "\033[32m")
CYAN=$(printf "\033[36m")
RED=$(printf "\033[31m")
RESET=$(printf "\033[0m")

INFO=" [$BOLD$GREEN*$RESET]"
ERROR=" [$BOLD$RED"'X'"$RESET]"
PROMPT=" [$BOLD$BLUE>$RESET]"

# Folders
ETC="/etc/${PNAME}"
RUN="/var/run/${PNAME}"
# LIB=/usr/lib/${PNAME}

# files
SRV_CONF="${ETC}/servers.conf"
VPN_CONF="${ETC}/config.ovpn"
CREDENTIALS="${ETC}/credentials.d/credentials.txt"
LOG="${RUN}/${PNAME}.log"

PIA_URL="https://www.privateinternetaccess.com"

# echo $LIB
# . ${LIB}/globals
# . ${LIB}/shared_scripts
# . ${LIB}/diagnose_tools
## Flags
auto=false

### FUNCTIONS ###
_help()
{
	cat <<-EOF
	${PNAME} v0.1 PrivateInternetAccess VPN manager
	usage: ${PNAME} [options]

	  options summary:
	    -a  --auto             automatically connect to closest server
	    -p  --protocol         select <prot> communication protocol.
	                           choices are: tcp, udp, stcp, sudp
	                           default is udp
	    -l  --list-servers     display a numbered list of pia servers
	    -s  --server <server>  connect to selected server
	                           could be a name or number in server list
	    -d  --debug            high verbosity
	    -h  --help             show this help message
	EOF
}

_init()
{

	l_init_folders() 
	{
		# status; checked
		## RUN: folder for process data(log, etc)
		## ETC: data files are stored there

		for folder in $RUN $ETC; do
			if [[ ! -d $folder ]]; then
				debug "make dir '%s'\n" $folder
				mkdir -p $folder
				if [[ $? != 0 ]]; then
					error "unable to make dir $folder"
					return 1
				fi
			fi
		done
	}

	l_init_log()
	{
		## make a clean new log at each start
		echo "----------------" > $LOG
		echo "init log" $(date) >> $LOG
	}

	l_init_servers_data()
	## Check servers datas file exists and is up to date.
	{
		## servers datas are stored in $SRV_CONF
		## Initialisation will succeed if
		##	- servers data is up to date
		##	- or if updating succeed
		## return: 0 if initialisation succeed
		##         1 if failed

		# make servers data file $SRV_CONF if it doesn't exist
		if [[ ! -f $SRV_CONF ]]; then
			debug "generating servers data in $SRV_CONF"
			f_update_servers_data && return 0
		# or check servers data are up to date
		else
			debug "check servers data update"
			# get last local data update date
			last_update=$(grep "Last-Modified" $SRV_CONF | tail -c+16)
			debug "last servers update: $last_update"

			# query PIA servers for last update date
			url=${PIA_URL}/openvpn/openvpn-tcp.zip
			header=$(curl --silent --head $url --time-cond "$last_update")
			response=$(head -n1 <<< $header)
			read -r xx status info <<< $response
			debug "response: %s %s" $status "$info"
			case $status in
				200)
					info "new servers update available"
					f_update_servers_data && return 0
					;;
				304)
					debug "servers list is up to date"
					return 0
					;;
				*)
					error "unknown answer code $status"
					;;
			esac
		fi

		error "failed to initialise servers data"
		return 1

	}


	l_init_credentials()
	{
		# credentials are (quite) securely stored. for auto login
		dir=$(dirname $CREDENTIALS)
		if [[ ! -d $dir ]]; then
			install -d -m 700 $dir
			# mkdir -p $dir && chmod 700 $dir
		fi
		
		# double check dir access on each start
		mode=$(stat -c %a $dir)
		if [[ $mode != "700" ]]; then
			error "${dir} mode must be 700. mode changed"
			chmod 700 $dir
		fi

		if [[ ! -f $CREDENTIALS ]]; then
			printf "your PIA credentials will be stored for further login\n"
			printf "$PROMPT username: "
			read USERNAME

			printf "$PROMPT password: "
			read -s PASSWORD && printf '\n'

			printf "$USERNAME\n$PASSWORD\n" > $CREDENTIALS

			unset USERNAME PASSWORD
			chmod 400 $CREDENTIALS
		fi

		# force restricted mode at each start
		mode=$(stat -c %a $CREDENTIALS)
		if [[ $mode != "400" ]]; then
			error "$CREDENTIALS mode must be 400. mode changed"
			chmod 400 $CREDENTIALS
		fi

		return 0
	}

	info "initializing..."

	l_init_folders || return 1
	l_init_log || return 1
	l_init_servers_data || return 1

	# ask for credentials if not stored yet
	l_init_credentials || return 1

	info "initialization succeed"
	return 0
}

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
	*)	break
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
		msg=$(printf -- "$@")
		# printf "debug: %s\n" "$msg"
		printf "\033[2m%s\033[0m\n" "$msg" >&2
	fi
}

f_get_ip()
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

f_get_gateway_interface()
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

f_probe_network()
{
	f_get_gateway_interface || return 1
	f_get_ip || return 1

	# success
	debug "network is available"
	return 0
}


f_choose_protocol()
{
	# display a select menu, return choosen protocol
	info -t -n "Protocol selection:"

	PS3="Select a protocol: "
	select protocol in "tcp" "strong-tcp" "udp" "strong-udp"; do
		if [[ ! $protocol ]]; then
			error "invalid entry\n"
			PS3="Enter the selected number [1-4] : "
			continue
		else
			debug "protocol: %s" "$protocol"
			break
		fi
	done

	# return protocol name
	echo $protocol
}

f_choose_server_from_list()
{
	# display a menu, return choosen servername
	info -t -n "Server selection:"

	# split file on new line, not space characters
	IFS_BAK=$IFS
	IFS=$'\n'
	PS3="Server number: "
	select servername in $(f_list_servers); do
		if [[ ! $servername ]]; then
			error "invalid entry"
			n=$(f_list_servers | wc -l)
			PS3="Enter the selected number [1-$n] :" 
			continue
		else
			debug "server: %s" "$servername"
			break
		fi
	done
	IFS=$IFS_BAK

	# return server name
	echo $servername
}

f_get_closest_server()
{
	# return closest server name
	f_probe_servers | sort -n | head -n1 | cut -d' ' -f2-
}

f_list_servers()
{
	# print servers list to stdout
	# in server.conf, servers names are closed in brackets []
	cat $SRV_CONF | grep -E "^\[" | tr -d []
}

f_make_ovpn_config_file()
{
	# parse config file for openvpn. print to stdout
	make_template()
	{
		# ---template default ---
		cat <<-EOF
		# this file is auto-generated by ${PNAME}
		# any changes will be overwritten

		client
		dev tun
		proto ${proto}
		remote ${url} ${port}
		resolv-retry infinite
		nobind
		persist-key
		persist-tun
		cipher ${cipher}
		auth ${hash}
		tls-client
		remote-cert-tls server

		auth-user-pass ${CREDENTIALS}
		auth-nocache
		compress
		verb 2
		reneg-sec 0

		<crl-verify>
		EOF
		cat ${ETC}/${crl}
		cat <<-EOF
		</crl-verify>

		<ca>
		EOF
		cat ${ETC}/${ca}
		cat <<-EOF
		</ca>

		disable-occ
		EOF
	# ---end template---
	}

	get_value()
	{
		# return field value for specific server from servers.txt
		field=$1
		cat $SRV_CONF |\
			grep -A7 -E "$servername" |\
			grep $field |\
			cut -d "=" -f2  
	}

	debug "parsing ovpn config file"

	# parsing parameters
	servername="$1"
	protocol="$2"
		
	# get server data
	url=$(get_value url)
	ip=$(get_value ip)

	# define value for template
	case $protocol in
		"tcp")
			proto="tcp"
			port=$(get_value tcp_port)
			security="default" ;;
		"udp")
			proto="udp"
		 	port=$(get_value udp_port)
			security="default" ;;
		"strong-tcp")
			proto="tcp"
			port=$(get_value tcps_port)
			security="strong" ;;
		"strong-udp")
			proto="udp"
			port=$(get_value udps_port)
			security="strong" ;;
	esac

	# certificates and level of encryption
	case $security in
		"default")
			crl="crl.rsa.2048.pem"
			ca="ca.rsa.2048.crt"
			cipher="aes-128-cbc"
			hash="sha1" ;;
		"strong")
			crl="crl.rsa.4096.pem"
			ca="ca.rsa.4096.crt"
			cipher="aes-256-cbc"
			hash="sha256" ;;
	esac


	info "server: %s, %s [%s]" "$servername" "$url" "$ip"
	info "protocol:%s  port:%d" "$protocol" "$port"
	debug "crl: %s, ca: %s" "$crl" "$ca"
	debug "cipher:%s  sha:%s" "$cipher" "$hash"
	debug "\nParsed config file:"
	debug "$(make_template)"

	# make_template > $VPN_CONF
	make_template
}

f_parse_ovpn_output()
{
	# active filter for openvpn stdout
	# print both to log and terminal

	# split line in date, info
	while read -r d m n h y info; do
		# print to log
		# printf "openvpn: %s\n" "$info" >> $LOG
		log "openvpn: %s" "$info"
		
		if [[ "$info" =~ "Attempting to establish" ]]; then
			info "connecting..."
			status="connecting"
		elif [[ "$info" =~ ^(TCP|UDP) ]]; then
			info=$(echo "$info" | tail -c+4)
			if [[ "$info" =~ "connection established" ]]; then
				info "connected"
				status="connected"
			fi
		elif [[ "$info" =~ 'failed' ]]; then
			error "failed: %s" "$info"
		elif [[ "$info" =~ 'Initialization Sequence Completed' ]]; then
			info "Tunnel initialization completed\n"
			info -n -t "Tunnel is up"
			info "press Ctrl+C to stop"
			status="active"
		fi

		# remote ip
		# Peer Connection Initiated with [AF_INET]185.232.21.29:501
		if [[ $info =~ "Peer Connection Initiated with" ]]; then
			ip=$(egrep -o "[0-9.]{7,15}" <<< $info)
			info "ip [%s]" $ip
		fi

	done
}

f_probe_servers()
{
	## servers url are defined in servers.conf

	kill_jobs()
	# call on SIGINT, kill every running child processes
	{
		while read -r job xx xx; do
			# ignore empty list
			[[ ! $job ]] && continue
			job=$(tr -d '[]+-' <<< $job)
			kill %$job
		done <<< $(jobs -r)
	}

	do_probe()
	## ping server and write results to stdout
	{
		server=$1
		url=$2

		# ping count
		nping=3
		# ping process timeout in seconds
		deadline=3
		# ping response timeout in seconds
		timeout=1 

		# result will equal avg time (from last line) or failed
		result=$(ping -q -w $deadline -c $nping "$url" |\
				 tail -n1 | cut -d'=' -f2 | cut -d'/' -f2|\
				 egrep ^[0-9]+ || echo "failed")

		if [[ $result == "failed" ]]; then
			# error "$server is unreachable. ping error: $exitcode"
			return 1
		else
			# result is average time
			echo "$result $server"
			return 0
		fi
	}

	# result files of ping
	info -n -t "probing servers"
	trap kill_jobs SIGINT

	# ping each server, and print result to stdout
	while read line; do
		# each server profile begins with [servername]
		if [[ $line =~ ^\[ ]]; then
			servername=$(tr -d '[]' <<< $line)

			# look for url through this server attributes
			while read line; do
				if [[ "$line" =~ ^url ]]; then
					url=$(cut -d '=' -f2 <<< $line)
					do_probe "$servername" "$url" &
					break
				fi
			done
		fi
	done < $SRV_CONF

	# draw delayed plots to kill time, interfere with debug mesg
	info -e "please wait"
	while [[ $(jobs -r) ]]; do
		# plz be patient ............ parasites in debug mode
		info -e '.'
		sleep 0.5
	done
	# erase the "plz wait" line
	info '\033[2K\033[1A'

	# remove trap
	trap - SIGINT
}

f_update_servers_data()
## Object: Updates servers data and generate $SRV_CONF file.
{

	## All servers datas are extracted from PIA *.ovpn files
	## PrivateInternetAccess provide these datas in Zip files
	## Certificates are included in those zip archives
	## see https://www.privateinternetaccess.com/openvpn

	local response

	fcurlzip()
	## download and extract zip file ( 1st parameter )
	{
		zip=$1
		url=${PIA_URL}/openvpn/${zip}
		printf "downloading %s\n" $url

		# check file exists on server
		header=$(curl --silent --head $url)
		response=$(head -n1 <<< $header)
		read -r xx code info <<< $response
		debug "response: %s %s" $code "$info"
		# last_modified date is used to check for new update
		last_modified=$(grep "Last-Modified" <<< $header | tail -c+16)

		# extract archive and clean
		if [[ $code == "200" ]]; then
			options="--silent"
			$debug && options=""
			curl $options -o $zip $url
			unzip -qo $zip
			rm $zip
			return 0
		else
			error "'%s' download failed: %s %s\n" $url $code "$info"
			rm $zip
			return 1
		fi
	}

	info "updating servers data"
	
	# archives will be extracted in tmp
	# all datas are parsed from included .ovpn files
	# servers datas are concatenate in $SRV_CONF at the end

	tmpdir=$(mktemp -d)
	cd $tmpdir

	# make a temporary file for each VPN server in this folder
	mkdir servers 
	
	# parsed datas depend on protocol
	# each protocol got a dedicated zip files
	# each expression will be evaluated ( cmd: eval )
	protocol_list=("ip" "tcp" "strong" "strong-tcp")
	# get IP and UDP port from ip.zip
	ip_data='ip=${X}\\nudp_port=${Y}\\n'
	# get URL and TCP port from tcp.zip
	tcp_data='url=${X}\\ntcp_port=${Y}\\n'
	# get secure UDP port from strong.zip
	strong_data='udps_port=${Y}\\n'
	# get secure TCP port from tcp-strong.zip
	strong_tcp_data='tcps_port=${Y}\\n'

	# loop through zip archives
	for P in ${protocol_list[@]}; do
		zip="openvpn-${P}.zip"
		fcurlzip $zip || return 1

		# p_data: useful datas to store in server config file
		# '-' must be replaced to match variables names
		varname=$(echo ${P}_data | tr '-' '_')
		p_data=$(eval echo \$${varname})

		while read file; do
			# make a temp file for each server
			name=$(basename "$file" .ovpn)
			datafile="./servers/${name}"
			# all of these files will be concatenated in $SRV_CONF
			if [[ ! -f "$datafile" ]]; then
					echo "[$name]" > "$datafile"
					echo "name=\"${name}\"" >> "$datafile"
			fi
			# needed datas are on the "remote" line
			read -r none X Y <<< $(grep -m1 ^remote "$file")
			eval printf -- "$p_data" >> "$datafile"
			# clean
			rm "$file"
		done <<< $(ls *.ovpn)
	done		

	# server.conf stores all VPN servers datas
	tmp_conf="$server/server.conf"
	cat > $tmp_conf <<-EOF
		# this file is auto-generated with ${PNAME}
		# any changes will be overwritten

		Last-Modified: ${last_modified}

	EOF
	# concatenate all datas in server.conf
	while read file; do
		cat "$file" >> $tmp_conf
		printf "\n" >> $tmp_conf
	done <<< $(ls servers/*)

	# certificates remains behind
	debug "saving certificates:"
	for certif in $(ls *.crt *.pem | sort ); do
		debug ".. %s" $certif
		mv $certif $ETC
	done

	# move config file in place
	mv $tmp_conf $SRV_CONF
	info "successfully update servers datas"
	# clean
	rm -r $tmpdir
	return 0
}


parse_command_line()
{
	# parse command line arguments
	parsed_args=$(getopt -o adhp:ls: --long auto,debug,help,protocol:,list-servers,server: -n $PNAME -- "$@")
	if [[ $? != 0 ]]; then
		error "terminating"
		return 1
	else
		eval set -- "$parsed_args"
	fi
}

_sigint()
{
	printf "killing openvpn\n"
	kill %1
	exit 0
}

### MAIN BEGIN ###
parse_command_line $@ || exit 1

# parse parameters from command line
while true; do
	case "$1" in
	-h | --help )
		_help
		exit 0 ;;
	-l | --list-servers )
		n=1
		while read line; do
			printf "%2d: %s\n" "$((n++))" "$line"
		done <<< $(f_list_servers)
		exit 0 ;;
	-a | --auto )
		auto=true
		shift ;;
	-s | server )
		argserver=$2
		debug "argserver: $argserver"
		shift 2 ;;
	-d | --debug )
		debug=true
		debug "start in debug mode"
		shift ;;
	-p | --protocol )
		case $2 in
		tcp )
			protocol="tcp" ;;
		udp )
			protocol="udp" ;;
		stcp | strong-tcp )
			protocol="strong-tcp" ;;
		sudp | strong-udp )
			protocol="strong-udp" ;;
		* )
			error "unknown protocol $2"
			return 1 ;;
		esac
		shift 2 ;;
	# end of options
	*)	break ;;
	esac
done

debug "run in debug mode"

# Only root can change ip routes and network interfaces
if [[ $(id -u) != 0 ]]; then
	echo "$ERROR Script must be run as root."
	exit 1
fi

if ! (f_probe_network); then
	error "network seems to be down"
	exit 1
fi

if ! _init; then
	echo "unable to initialize"
	exit 1
fi

case $action in
	list-servers )
		cat -n <<< $(f_list_servers)
		exit 0 ;;
esac

# parse servername from command-line
if [[ -v argserver ]]; then
	debug "parse server from command-line"
	debug "argserver: $argserver"
	if [[ $argserver =~ [[:digit:]] ]]; then
		debug "arg is a number"
		servername=$(f_list_servers | tail -n+$argserver | head -n1)
		printf "servername: $servername\n"
	elif [[ $argserver =~ [[:alpha:]] ]]; then
		debug "server is a word"
		# match all name beginning with arg
		# declare matchlist
		# debug "matchlist:"
		nmatch=0
		while read match; do
			[[ -z $match ]] && continue
			p=$((nmatch++))
			matchlist[$p]=$match
			debug "matchlist[$p]: ${matchlist[$p]}"
		done <<< $(f_list_servers | grep -ie "\<$argserver")

		debug "nmatch: $nmatch"
		# for i in ${!matchlist[@]}; do
		# 	debug ${matchlist[$i]}
		# done

		# only one match, found servername
		if [[ $nmatch == 0 ]]; then
			echo "can't find server named '$argserver'"
			exit 1
		elif [[ $nmatch == 1 ]]; then
			servername=${matchlist[0]}
			printf "server: $servername\n"
		elif [[ $nmatch > 1 ]]; then
			printf "ambiguous servername. Please select one:\n"
			select servername in "${matchlist[@]}"; do
				if [[ ! $servername ]]; then
					printf "invalid entry. Enter a number [1-$nmatch]:\n"
					continue
				else
					printf "server: $servername\n"
					break
				fi
			done
		fi
	else
		echo "syntax error in servername '$argserver'"
		exit 1
	fi
fi



# connect to the closest server, based on ping average
if $auto; then
	if [[ -v servername ]]; then
		printf "servername is already set. Skip auto mode"
	else
		# connect to closest server
		servername=$(f_get_closest_server)
		# set protocol if not define on command line
		[[ -z $protocol ]] && protocol="strong-tcp"
	fi
fi

# select server in interactive menu if unset yet
if [[ ! -v servername ]]; then
	# ask for server to use
	servername=$(f_choose_server_from_list)
	[[ -z $protocol ]] && protocol=$(f_choose_protocol)
fi

# default protocol
[[ ! -v protocol ]] && protocol="strong-tcp"

debug "before config parsing:"
debug "servername: $servername"
debug "protocol: $protocol"

# parse config file for openvpn
vpn_conf=$(mktemp)
f_make_ovpn_config_file "$servername" "$protocol" > $vpn_conf

# check for tunnel node
node=/dev/net/tun
if [[ ! -c $node ]]; then
	debug "making tunnel node $node"
	mkdir -p $(dirname $node)
	mknod $node c 10 200
fi

# connect
info -t -n "setting tunnel up"
options="--config $vpn_conf --ping 3 --ping-exit 20 --mute-replay-warnings "

tunnel()
{
	openvpn $options | f_parse_ovpn_output
}

trap _sigint SIGINT

while true; do
	printf "starting openvpn\n"
	tunnel &
	while [[ $(jobs -r | wc -l) > 0 ]]; do
	# while [[ $(jobs %tunnel) ]] ; do
	# openvpn --config $vpn_conf | f_parse_ovpn_output
		# printf "."
		sleep 1
	done
	printf "tunnel has closed. restarting\n"
done


printf '\n'

echo "terminating"
exit
