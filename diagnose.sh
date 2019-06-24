#!/bin/bash

PNAME="pia"
. globals.conf

# test config
#
flist_servers()
{
	# print servers list to stdout
	cat $SRV_CONF | grep -E "^\[" | grep -oE "[a-Z ]+"
}

fping_servers()
# sort servers in ping avg time order
{
	_kill_jobs()
	# call on SIGINT, kill every running child processes
	{
		while read -r job xx xx; do
			# ignore empty list
			[[ ! $job ]] && continue
			job=$(tr -d '[]+-' <<< $job)
			kill %$job
		done <<< $(jobs -r)
	}

	probe_server()
	# ping server and write results to stdout
	{
		server=$1; url=$2; ip=$3

		# init
		# ping count
		nping=3
		# ping process timeout
		deadline=3
		# ping response timeout
		timeout=1 

		# output line counter
		n=0
		
		log=$(mktemp)
		# parse lines from ping according to their position
		while read line; do
			# increment line counter
			((n++))
			# keep a log for debugging
			echo "[$n] $line" >> $log
			# retrieve info from ping output
			case $n in
				1)	cname=$(cut -d ' ' -f2 <<< $line) ;;
				4)	read -r send received loss xx <<<\
						$(echo $line | grep -o -E "[0-9]+" | tr '\n' ' ') ;;
				5)	read -r min max avg mdev avgtime <<<\
						$(echo $line | grep -oE "[0-9./]{2,}" | tr '/' ' ') ;;
				6)	exitcode=$line ;;
			esac
		# done <<< $( ping -q -w $deadline -W $timeout -c $nping "$url"; echo $?)
		done <<< $( ping -q -w $deadline -c $nping "$url"; echo $?)

		# print parsed result to stdout
		echo "[$server]"
		# echo "cname:    $cname"
		# echo "send:     $send"
		# echo "received: $received"
		# echo "loss:     $loss"
		# echo "min:  $min"
		# echo "max:  $max"
		echo "avg:  $avg"
		echo "mdev:  $mdev"
		echo "exitcode:  $exitcode"
		
		# clean
		rm $log
	}

	# result files of ping
	probelog=$(mktemp)
	trap _kill_jobs SIGINT

	n=0
	while read line; do
		# echo $n $line
		match=$(grep -E '\[' <<< $line)
		if [[ $match ]]; then
			servername=$(tr -d '[]' <<< $match)
			# probe_server servername
			while read line; do
				# echo $line
				match=$(grep -E "^(url|ip)" <<< $line)
				# if [[ $match ]]; then
				if [[ "$line" =~ ^url ]]; then
					url=$(cut -d '=' -f2 <<< $match)
					# echo url $url
				elif [[ "$line" =~ ^ip ]]; then
					ip=$(cut -d '=' -f2 <<< $match)
					# echo ip $ip
				fi

				if [[ $url && $ip ]]; then
					probe_server "$servername" $url $ip >> $probelog &
					unset servername url ip
					break
					# exit
				fi
			done
		fi
		((n++))
	done < $SRV_CONF

	# wait till only 3 processes remains
	while [[ $(jobs -r | wc -l) > 3 ]]; do
		# jobs >&2
		sleep 1
	done

	trap - SIGINT
	# print results to stdout
	cat $probelog
	# clean
	rm $probelog
}

fparse_log()
# get useful info and sort servers
{
	while read line; do
		match=$(<<<$line grep -E "^\[" | tr -d '[]' )
		if [[ $match ]]; then
			servername=$match
		fi

		match=$(<<<$line grep -E "^avg" | grep -oE "[0-9.]+" )
		if [[ $match ]]; then
			avg=$match
		fi

		match=$(<<<$line grep -E "^mdev" | grep -oE "[0-9.]+" )
		if [[ $match ]]; then
			mdev=$match
		fi

		match=$(<<<$line grep -E "^exitcode" | grep -o [0-9])
		if [[ $match ]]; then
			exitcode=$match
			case $exitcode in
				# failed
				1)	continue ;;
			esac
			# print useful info to stdout
			echo $avg $mdev $servername 
		fi
	done < $1
}

log=$(mktemp)
list=$(mktemp)
fping_servers > $log
fparse_log $log > $list

while read xx xx servername; do
	echo $servername
done <<<$(cat $list | sort -n)