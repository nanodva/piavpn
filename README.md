# piavpn
It is a vpn manager for Private Internet Access VPN. This program is inspired by the pia manager from d4rkcat.\
It is designed for Debian based distro, and is still on work.Run this at your own risk.



Usage:
==========
After installation, to open a VPN tunnel to a PIA server, run:
	
	piavpn

To let pia select the closest server:

	# strong-tcp is the default protocol
	piavpn --auto

To conect directly to a server:

	# servers are numbered in servers list
	piavpn -l
	# connect to luxembourg server
	sudo piavpn -s 23
	sudo piavpn -s lux

At first launch, you'll be prompted for pia user credentials.\
They will be saved in /etc/piavpn/credentials.d/credentials.

	usage: piavpn [-adhp] [--auto] [--protocol <prot>]
				  [--debug] [--help]

	options summary:
	-a  --auto 				automatically connect to closest server
	-p  --protocol 			select <prot> communication protocol.
							choices are: tcp, udp, stcp, sudp
							default is strong-tcp
	-l  --list-servers 		display a numbered list of pia servers
	-s  --server <server> 	connect to selected server
							could be a name or number in server list
	-d  --debug 			high verbosity
	-h  --help 				show this help message


Dependencies:
============
Required:
- openvpn
- curl
- net-tools
- unzip
- openssl
- ca-certificates
- dnsutils
- inetutils-ping

Suggested:
- dnsmasq

To manually install dependencies:  
	
	apt update  
	apt install openvpn curl unzip

you can remove then later with:  
	
	apt remove openvpn curl unzip

be sure to install the latest versions.



Manual installation:
===================
copy the repository to your disk
	
	git clone https://github.com/taigasan/piavpn

install dependencies

	# depencies are listed in dependencies.txt
	sudo install_dependencies.sh

install piavpn
	
	make install

uninstall
	
	# remove only binary
	make remove
	# remove all files
	make purge



Installation from PPA:
=====================
Required:
- gnupg

Add the repository to APT repositories list

	# open /etc/apt/sources-list for edition
	sudo apt edit-sources

	# add this line to /etc/apt/sources-list
	deb http://ppa.launchpad.net/taigasan/ppa/ubuntu eoan main
	# and this one for sources
	deb-src http://ppa.launchpad.net/taigasan/ppa/ubuntu eoan main

Add the PPA gpg key to apt keyring.\
key fingerprint: 90B3FC4D4909D303

	# you need gnupg
	sudo apt install gnupg
	# retrieve public key from ubuntu.com keyserver
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key 90B3FC4D4909D303

install pia-vpn-client

	sudo apt update
	sudo apt install pia-vpn-client



Security and Privacy:
====================
Do mind:
- credentials are stored in clear, in /etc/piavpn/credentials.d/.
- This program does not manage DNS, DNS leaks may occurs.  
	Please check that here:  
			https://ipleak.net  
			https://dnsleaktest.com  
	To prevent this, you could install dnsmasq, and use PIA DomainNameServer.\
	See Dnsmasq Section below.



Using Dnsmasq:
=============
Dnsmasq is an easy lightweight dns server.

install dnsmasq
	
	apt update  
	apt install dnsmasq  

edit /etc/dnsmasq.conf

	# make a backup of the default configuration
	nano -B /etc/dnsmasq.conf
	
add those lines for a minimal configuration

	# sanity options
	domain-needed
	bogus-priv
	# do not use resolv.conf to determine used NameServers
	no-resolv
	# set Nameservers to PIA's
	server=209.222.18.222
	server=209.222.18.218

restart dnsmasq

	service dnsmasq restart
	systemctl dnsmasq restart

see it works

	service dnsmasq status

	# get ip where dns request are send
	# this is usually 127.0.0.1:53 ( localhost, port 53)
	nslookup server

	# this shows which program receive dns request
	# it should return dnsmasq
	netstat -lpnt | grep "127.0.0.1:53"



enjoy...