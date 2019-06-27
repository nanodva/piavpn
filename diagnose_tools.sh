#!/bin/bash

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

get_closest_server()
{
	f_probe_servers | sort -n | head -n1 | cut -d' ' -f2-
}



