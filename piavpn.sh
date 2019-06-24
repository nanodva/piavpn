#!/bin/bash

## piavpn v0.1 Copyright (C) 2019 TaigaSan Corp.
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

PNAME=$(basename $0 .sh)
# LIBPATH="/etc/${PNAME}"
. globals.conf


# Only root can play with network.
if [[ $(id -u) != 0 ]]; then
	echo "$ERROR Script must be run as root."
	exit 1
fi

# debug=true
debug=false



fupdateservers()
{
	fcurlzip()
	# download and extract zip file
	{
		zip=$1
		url=${PIA_URL}/openvpn/${zip}
		$debug && printf "downloading %s\n" $url
		# ask server and manage HTTP response
		response=$(curl -vo $zip $url |& grep -oE "HTTP/1.1 [0-9]{3}[a-Z ]+")
		read -r xx status info <<< $response

		# status 200 is ok. 
		if [[ $status == "200" ]]; then
			unzip -qo $zip
			rm $zip
			return 0
		else
			printf "'%s' download failed: %s %s\n" "$url" "$status" "$info"
			rm $zip
			return 1
		fi
	}

	# retrieve servers list and data from PIA zip packs
	printf "updating servers data\n"
	
	# files will be extracted in tmp
	# concatenate at the end
	tmpdir=$(mktemp -d)
	pushd . >/dev/null
	cd $tmpdir
	# temp storage place for servers conf
	mkdir servers 

	# parse server IP and UDP port
	if ! (fcurlzip "openvpn-ip.zip"); then
		return 1
	else
		# UDP_PORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
		while read file; do
			name=$(basename "$file" .ovpn)
			# ip=$(cat "$file" | grep -m1 ^remote | awk '{print $2}')
			read -r xx ip port <<< $(cat "$file" | grep -m1 ^remote )
			datafile="./servers/${name}"
			cat > "$datafile" <<-EOF
				[${name}]
				name="${name}"
				ip=$ip
				udp_port=${port}
			EOF
			# clean
			rm "$file"
		done <<< $(ls *.ovpn)
		$debug && printf " ... ip - ok\n"
		$debug && printf " ... udp ports - ok\n"
	fi

	# parse server url and TCP port
	if ! (fcurlzip "openvpn-tcp.zip"); then
		return 1
	else
		# TCP_PORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
		
		# get servers name and url, as well as default certificates
		while read file; do
			name=$(basename "$file" .ovpn)
			# url=$(cat "$file" | grep -m1 ^remote | awk '{print $2}')
			read -r xx url port <<< $(cat "$file" | grep -m1 ^remote )
			datafile="./servers/${name}"
			cat >> "$datafile" <<-EOF
				url=${url}
				tcp_port=${port}
			EOF
			# clean
			rm "$file"
		done <<< $(ls *.ovpn)
		$debug && printf " ... url - ok\n"
		$debug && printf " ... tcp ports - ok\n"
	fi

	# parse strong UDP port
	if ! (fcurlzip "openvpn-strong.zip"); then
		return 1
	else
		# UDP_SPORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
		while read file; do
			name=$(basename "$file" .ovpn)
			read -r xx xx port <<< $(cat "$file" | grep -m1 ^remote )
			datafile="./servers/${name}"
			cat >> "$datafile" <<-EOF
				udps_port=${port}
			EOF
			# clean
			rm "$file"
		done <<< $(ls *.ovpn)
		$debug && printf " ... udp strong ports - ok\n"
	fi

	# parse strong TCP port
	if ! (fcurlzip "openvpn-strong-tcp.zip"); then
		return 1
	else
		# TCP_SPORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
		while read file; do
			name=$(basename "$file" .ovpn)
			read -r xx xx port <<< $(cat "$file" | grep -m1 ^remote )
			datafile="./servers/${name}"
			cat >> "$datafile" <<-EOF
				tcps_port=${port}
			EOF
			# clean
			rm "$file"
		done <<< $(ls *.ovpn)
		$debug && printf " ... tcp strong ports - ok\n"
	fi

	# create servers list
	cat > $SRV_CONF <<-EOF
		# this file is auto-generated with ${PNAME}
		# any changes will be overwritten

	EOF
	# concatenate all config files in ./servers
	while read file; do
		cat "$file" >> $SRV_CONF
		printf "\n" >> $SRV_CONF
	done <<< $(ls servers/*)

	# $debug && printf "set ports UDP:%s UDPS:%s TCP:%s TCPS:%s\n"\
	# 		$UDP_PORT $UDP_SPORT $TCP_PORT $TCP_SPORT

	# save certificates
	$debug && printf "saving certificates:\n"
	for certif in $(ls *.crt *.pem | sort ); do
		$debug && printf "... %s\n" $certif
		mv $certif $LIBPATH
	done

	# clean
	popd > /dev/null
	rm -r $tmpdir
	return 0
}

ftestportforwarding()
{

	echo "test port forwarding"
	cd $VPNPATH
	while read -r NAME URL; do
		CONFIG="$NAME.ovpn"
		echo $CONFIG
		openvpn --config $CONFIG &
		pid=$!
		sleep 5
		kill $pid
	done < servers.txt
	# curl -v -m 4 "http://209.222.18.222:2000/?client_id=$(cat $VPNPATH/client_id)"
	exit
}

finit_log() {
	# make a clean new log at each start
	log_dir=$(dirname $LOG)
	# rm -fr $log_dir
	mkdir -p $log_dir
	echo "----------------" > $LOG
	echo "init log" $(date) >> $LOG
}

finitcheck()
{
	# log
	finit_log

	# All data files are stored here
	if [[ ! -d $LIBPATH ]]; then
		printf "make dir '%s'\n" $LIBPATH
		mkdir -p $LIBPATH
	fi

	# check server list
	if [[ ! -f $SRV_CONF ]]; then
		if fupdateservers; then
			printf "update succeed\n\n"
		else
			printf "update failed\n\n"
			return 1
		fi
	fi

	# ask for credentials if not stored yet
	fcheck_credentials

	# printf "init succeed\n"
	return 0
}

fcheck_credentials()
{
	# credentials are securely stored. for auto login
	dirpath=$(dirname $CREDENTIALS)
	
	# change mode on each start
	mkdir -p $dirpath && chmod 700 $dirpath
	
	if [[ ! -f $CREDENTIALS ]]; then
		printf "your PIA credentials will be stored for further login\n"
		printf "$PROMPT username: "
		read USERNAME

		printf "$PROMPT password: "
		read -s PASSWORD && printf '\n'

		printf "$USERNAME\n$PASSWORD\n" > $CREDENTIALS
		unset USERNAME PASSWORD
	fi
	# force restricted mode at each start
	chmod 400 $CREDENTIALS
	return 0
}

fchoose_server()
{
	list=$(mktemp)
	# servers names are closed in brackets []
	cat $SRV_CONF | grep -E "^\[" | grep -oE "[a-Z ]+" > $list

	# display a menu, return choosen value
	IFS_BAK=$IFS && IFS=$'\n'
	# count=$(cat $list | wc -l)
	PS3="Select a server: "
	select servername in $(cat $list); do
		# printf "%d\n" $servername
		if [[ ! $servername ]]; then
			printf "invalid entry\n"
			PS3="Enter the selected number: "
			continue
		else
			IFS=$IFS_BAK
			rm $list
			break
		fi
	done

	# return server name
	echo $servername
}

fchoose_protocol()
{
	# protocol
	PS3="Select a protocol: "
	select protocol in "tcp" "strong tcp" "udp" "strong udp"; do
		if [[ ! $protocol ]]; then
			printf "invalid entry\n"
			PS3="Enter the selected number: "
			continue
		else
			break
		fi
	done
	# return protocol name
	echo $protocol
}

fmake_ovpn_config_file()
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
		remote ${ip} ${port}
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
		cat ${LIBPATH}/${crl}
		cat <<-EOF
		</crl-verify>

		<ca>
		EOF
		cat ${LIBPATH}/${ca}
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
			grep -A7 -E "$name" |\
			grep $field |\
			cut -d "=" -f2  
	}

	# parsing parameters
	name="$1"
	protocol="$2"
	# strenght="$3"

	# info line
	# printf "parsing ovpn config file for %s\n" "$name"

	# get server data
	url=$(get_value url)
	ip=$(get_value ip)

	# port on server
	case $protocol in
		"tcp")
			proto="tcp"
			port=$(get_value tcp_port)
			security="default" ;;
		"udp")
			proto="udp"
		 	port=$(get_value udp_port)
			security="default" ;;
		"strong tcp")
			proto="tcp"
			port=$(get_value tcps_port)
			security="strong" ;;
		"strong udp")
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


	printf '\n'
	if $debug; then
		printf "server: %s, %s, %s\n" "$name" "$url" "$ip"
		printf "port: %s, %d\n" "$protocol" "$port"
		printf "crl: %s, ca: %s\n" "$crl" "$ca"
		printf "cipher:%s  sha:%s\n" "$cipher" "$hash"
	else
		printf "server: %s [%s]\n" "$url" "$ip"
		printf "protocol:%s  port:%d\n\n" "$protocol" "$port"
	fi

	make_template > $VPN_CONF
}

fparse_ovpn_output()
{
	while read -r d m n h y info; do
		# print to log
		printf "openvpn: %s\n" "$info" >> $LOG
		
		if [[ "$info" =~ "Attempting to establish" ]]; then
			echo "connecting..."
			status="connecting"
		elif [[ "$info" =~ ^(TCP|UDP) ]]; then
			info=$(echo "$info" | tail -c+4)
			if [[ "$info" =~ "connection established" ]]; then
				echo "connected"
				status="connected"
			fi
		elif [[ "$info" =~ 'failed' ]]; then

			echo "failed" $info
		elif [[ "$info" =~ 'Initialization Sequence Completed' ]]; then
			printf "Tunnel initialization completed\n"
			status="active"
		fi
	done
}

flist_servers()
{
	# print servers list to stdout
	cat $SRV_CONF | grep -E "^\[" | grep -oE "[a-Z ]+"
}

auto=true

finitcheck || echo "init failed"
printf '\n'

if [[ $auto ]]; then
	# connect to closest server
	servername=$(./diagnose.sh | head -n1)
	protocol="tcp"
else
	# ask for server to use
	servername=$(fchoose_server)
	printf '\n'
	protocol=$(fchoose_protocol)
fi

# parse config file
fmake_ovpn_config_file "$servername" "$protocol"

# connect
openvpn --config "$VPN_CONF" | fparse_ovpn_output

exit
