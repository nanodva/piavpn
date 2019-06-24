#!/bin/bash


. globals.conf

fupdate_servers()
# retrieve servers list and data
{
	fzip()
	# download and extract zip file
	{
		zip=$1
		url=${PIA_URL}/openvpn/${zip}
		curl -so $zip $url
		unzip -qo $zip
		rm $zip
	}

	tmpdir=$(mktemp -d)
	cd $tmpdir
	mkdir servers 

	# default zip is udp
	fzip "openvpn.zip"
	UDP_PORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
	
	while read file; do
		name=$(basename "$file" .ovpn)
		url=$(cat "$file" | grep -m1 ^remote | awk '{print $2}')
		# create a file for each server
		datafile="./servers/${name}"
		echo "[${name}]" >> "$datafile"
		echo "url: ${url}" >> "$datafile"
		# clean
		rm "$file"
	done <<< $(ls *.ovpn)
	printf "Servers cname - ok\n"

	# get IP
	fzip "openvpn-ip.zip"
	while read file; do
		name=$(basename "$file" .ovpn)
		ip=$(cat "$file" | grep -m1 ^remote | awk '{print $2}')
		datafile="./servers/${name}"
		echo "ip: $ip" >> "$datafile"
		# clean
		rm "$file"
	done <<< $(ls *.ovpn)
	printf "Servers ip - ok\n"

	# get TCP
	fzip "openvpn-strong-tcp.zip"
	TCP_PORT=$(cat "$(ls ./*.ovpn | head -n1)" | grep -m1 ^remote | awk '{print $3}')
	printf "Servers tcp & udp ports - ok\n"

	# make servers list
	servers_file=$LIB/servers
	rm -f $servers_file
	while read file; do
		cat "$file" >> $servers_file
		printf "\n" >> $servers_file
	done <<< $(ls servers/*)

	# make config file
	config_file=$LIB/pia.conf
	rm -f $config_file
	echo "tcp_port:" $TCP_PORT >> $config_file
	echo "udp_port:" $UDP_PORT >> $config_file

	# get certificates
	mv *.crt *.pem $LIB

	# clean
	cd ..
	rm -r $tmpdir
}

ftest_portforwarding()
{
	echo ""
}
fupdate_servers
ftest_portforwarding
exit

