#!/bin/bash
#
#	+-----------------------------------------------------------------------#
#	| description:	check nginx backend systems				|
#	| date:		August 31st, 2018					|
#	| author:	Sascha Reimann						|
#	| git:		https://github.com/s-reimann/check_nginx_upstreams.sh	|
#	+-----------------------------------------------------------------------+

usage () {
	echo "Usage: $(basename ${0}) [ -i <ignore pattern> ] [ -w <warn threshold> ] [ -w <critical threshold> ] [ -t <seconds> ]"
	echo "-i: ignore a backend (supports regular expression)"
	echo "-w: set warn threshold (default: warning if availability is below or equal 75(%))"
	echo "-c: set critical threshold (default: critical if availability is below or equal 50(%))"
	echo "-t: amount of seconds to wait for a backend to respond"
	echo "-d: change configuration directory (default: /etc/nginx/sites-enabled)"
}

# pre-flight checks
for bin in $(echo "nginx nc grep xargs awk sed"); do
	if ! [ -x "$(command -v ${bin})" ]; then echo "UNKNOWN: ${bin} not available, unable to determine status"; exit ${state_unknown}; fi
done

# set some default variables to work with
configs_dir="/etc/nginx/sites-enabled"
threshold_warn="75"
threshold_critical="50"
timeout="1"
# set nagios exit codes
state_ok="0"
state_warning="1"
state_critical="2"
state_unknown="3"

# the function that performs the actual check
check_backends () {
	# quit if the config directory does not exist
	if [ ! -d ${configs_dir} ]; then echo "UNKNOWN: ${configs_dir} does not exist, unable to determine status"; exit ${state_unknown}; fi

	# find all config files that contain upstreams
	configs="$(grep -rE --files-with-matches "^upstream" ${configs_dir}/* 2>/dev/null|xargs echo)"

	# if the "-i" argument is used, ignore matching backends
	if [ ! -z "${ignore}" ]; then
		backends=$(awk '/^upstream/ {print $2}' ${configs} | grep -Ev "${ignore}")
	else
		backends=$(awk '/^upstream/ {print $2}' ${configs})
	fi

	# count amount of backends per upstream, check if each backend is available on the corresponding port. If everything is fine, set status to "OK". If not:
	# - set status to "CRITICAL"
	# - increase failed by 1
	# - create nagios output (status details and performance data)
	for backend in ${backends}; do
		amount="$(sed -n "/^upstream ${backend} {/,/}/p" ${configs} | grep -cE "^\s+{0,}server")"
		count="0"
		failed="0"
		while read host port; do
			(( count++ ))
			nc -nzw ${timeout} ${host} ${port}
			if [ "${?}" != "0" ]; then
				(( failed++ ))
				status="CRITICAL"
			fi
			if [ "${count}" -eq "${amount}" ]; then
				txt_info="${txt_info}\n${backend}: $((${amount} - ${failed})) of ${count} available ($((100 * (( ${amount} - ${failed})) / ${count}))%); "
				# Details about creating graphs: https://nagios-plugins.org/doc/guidelines.html#AEN200
				txt_graph="${txt_graph}${backend}=$((100 * (( ${amount} - ${failed})) / ${count}))%;${threshold_warn};${threshold_critical} "
			fi
		done < <(sed -n "/^upstream ${backend}/,/}/p" ${configs}|grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}"|awk -F: '{print $1,$2}')
		if [ -z "${status}" ]; then
			status="OK"
		fi
	done
}

# read user arguments
while getopts "i:w:c:t:d:h" opt; do
	case ${opt} in
		i)
			ignore=${OPTARG}
			;;
		w)
			threshold_warn=${OPTARG}
			;;
		c)
			threshold_critical=${OPTARG}
			;;
		t)
			timeout=${OPTARG}
			;;
		d)
			configs_dir=${OPTARG}
			;;
		*)
			usage
			exit 0
			;;
	esac
done

check_backends

# echo nagios output
if [ "${status}" = "CRITICAL" ]; then
	echo -en "BACKEND CRITICAL - Backend Availability: ${txt_info}|${txt_graph}\n"
	exit ${state_critical}
elif [ "${status}" = "OK" ]; then
	echo -en "BACKEND OK - Backend Availability: ${txt_info}|${txt_graph}\n"
	exit ${state_ok}
fi

# hopefully, we never get here
status="UNKNOWN"
echo "${status}: unable to determine status"
exit ${state_unknown}
