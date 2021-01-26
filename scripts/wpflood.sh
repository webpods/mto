#!/usr/bin/env bash
# Use only during WP BRUTE FORCE attacks
check_environment(){
	if [ ! -f /usr/sbin/ipset ]; then
		yum install ipset -y ## This is probably redundant, but may as well check before throwing a critical error...
	fi

	if [ ! -f /usr/sbin/ipset ]; then
		echo "Could not find ipset installed. Assuming this is a CentOS 5 server and aborting, script is incompatible."
		exit 1
	fi
}

add_rules(){
	iptables=$(which iptables)

	## Before we do anything, save the domains being flooded
	FLOODED=$(curl -s http://localhost/whm-server-status | awk '{gsub("<[^>]*>", "")}1' | grep HTTP | sed 's/[0-9]*//g' | sed 's/^.........//' | sed 's/\..*$//' | sort | uniq -c | sort -n)

	## Wipe these rules if they already exist
	$iptables -F -t raw

	## Very old browser
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Mozilla/4" --algo bm --from 0 -j DROP

	## Drop all xmlrpc for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "xmlrpc" --algo bm --from 0 -j DROP

	## Drop all wp-cron for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "wp-cron" --algo bm --from 0 -j DROP

	## Drop all search for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp  -m multiport --dports 80,443 -m string --string "pki-validation" --algo bm --from 0 -j DROP

	## Drop all search for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "/?s=%" --algo bm --from 0 -j DROP

	## Drop all search for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "/?search=" --algo bm --from 0 -j DROP

	## Drop all search for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "wp-json" --algo bm --from 0 -j DROP

	## Drop all search for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "mail." --algo bm --from 0 -j DROP
	## Drop Ubuntu for the duration of the flood
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Ubuntu" --algo bm --from 0 -j DROP

	## Drop browsers that aren't very recent
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Mozilla/5" --algo bm --from 0 -m string --string "wp-login" --algo bm --from 0 \
	-m string ! --string "Chrome/7" --algo bm --from 0  \
	-m string ! --string "Firefox/6" --algo bm --from 0 \
	-m string ! --string "Safari/6" --algo bm --from 0  \
	-m string ! --string "Edge/1" --algo bm --from 0    \
	-j DROP

	## The same, but not just for wp-login
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Firefox/3." --algo bm --from 0 -j DROP
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Firefox/4." --algo bm --from 0 -j DROP
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Chrome/1" --algo bm --from 0 -j DROP
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Chrome/2" --algo bm --from 0 -j DROP
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Chrome/3" --algo bm --from 0 -j DROP
	$iptables -t raw -A PREROUTING -p tcp -m multiport --dports 80,443 -m string --string "Chrome/4" --algo bm --from 0 -j DROP
	## Restart httpd to make load avg drop
	service httpd restart
}

removal_timer(){
	## This is hacky and gross, but automatically removes the rules after 3 hours
	echo "#!/usr/bin/env bash" > /tmp/wpfloodtimer.sh
	echo "sleep 10800" >> /tmp/wpfloodtimer.sh
	echo "$iptables -F -t raw" >> /tmp/wpfloodtimer.sh
	nohup sh /tmp/wpfloodtimer.sh >/dev/null 2>&1 &
}

log_packets(){
nohup tcpdump -i eth0 -vvn -s0 -c 10000 -w "/root/rob.cap" >/dev/null 2>&1 &
echo "$FLOODED" > /root/rob.txt
}

echo_messages(){
	echo "WP flood filtering is now enabled for 3 hours."
	echo "These domains were flooded:"
	echo "$FLOODED"
	echo ""
	echo ""
}

main(){
	check_environment "$@"
	add_rules "$@"
	removal_timer "$@"
	log_packets "$@"
	echo_messages "$@"
	exit 0
}
  
main "$@"
