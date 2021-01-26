#!/usr/bin/env bash

check_environment(){

	if ! [ "$(id -u)" = 0 ]; then
		echo "Please run this script as root, or with sudo."
  		exit 1
	fi

	RHELVERSION=$(uname -a | grep -i ".el4.")
	if [ -n "$RHELVERSION" ]; then
		echo "RHEL4 detected, aborting"
	fi
		
	if [ ! -f /usr/sbin/ipset ]; then	
		echo "ipset dependency not satisfied - attempting to install"
		yum install ipset -y
	fi
	
	if [ ! -f /scripts/upcp ]; then
		echo "cPanel not found. Aborting."
 		exit 1
	fi

	if [ ! -f /etc/csf/csf.conf ]; then
		echo "CSF is not installed. Aborting."
		exit 1
	fi
	
	CSFSTATUS=$(csf status | grep "csf:" | cut -c1-4)
	if [[ $CSFSTATUS != "csf:" ]]; then
		echo "CSF is not enabled. Aborting."
		exit 1
	fi

	if [ -f /etc/csf/csf.old ]; then
		echo "csf.old already exists. That's fine, deleting."
		rm -f /etc/csf/csf.old
	fi

	if [ -f /etc/csf/csf.blocklists.old ]; then
		echo "csf.blocklists.old already exists. That's fine, deleting."
		rm -f /etc/csf/csf.blocklists.old
	fi
	
	if [ -f /etc/csf/csf.deny.old ]; then
		echo "csf.deny.old already exists. That's fine, deleting."
		rm -f /etc/csf/csf.deny.old
	fi

	if [ -f /etc/csf/csfpost.sh.old ]; then
		echo "csfpost.sh.old already exists. That's fine, deleting."
		rm -f /etc/csf/csfpost.sh.old
	fi

	if [ -f /etc/csf/regex.custom.pm.old ]; then
		echo "regex.custom.pm.old already exists. That's fine, deleting."
		rm -f /etc/csf/regex.custom.pm.old
	fi
}

move_zig(){
	## Grab the config
	mv /etc/csf/csf.conf /etc/csf/csf.old && curl -o /etc/csf/csf.conf http://test.url/csf.conf

	## Somebody set us up the bomb
	MTO=$(cat /etc/csf/csf.conf | grep MTO)
	if [[ $MTO != "# MTO" ]]; then
		## Our csf.conf is not the new one we just tried to place
		echo "Deploying new csf.conf failed. Attempting to revert and aborting."
		rm -f /etc/csf/csf.conf
		mv /etc/csf/csf.old /etc/csf/csf.conf
		exit 1
	fi

	## Now do the same thing with blocklists
	mv /etc/csf/csf.blocklists /etc/csf/csf.blocklists.old && curl -o /etc/csf/csf.blocklists http://test/csf.blocklists

	## Somebody set us up the bomb
	MTO2=$(cat /etc/csf/csf.blocklists | grep MTO)
	if [[ $MTO2 != "# MTO" ]]; then
		## Our csf.blocklists is not the new one we just tried to place
		echo "Deploying new csf.blocklists failed. Attempting to revert and aborting."
		rm -f /etc/csf/csf.blocklists
		mv /etc/csf/csf.blocklists.old /etc/csf/csf.blocklists
		rm -f /etc/csf/csf.conf
		mv /etc/csf/csf.old /etc/csf/csf.conf
		exit 1
	fi

	## Now fix csfpost.sh
	MTO3=$(cat /etc/csf/csfpost.sh | grep wp-login)
	if [ -n "$MTO2" ]; then
		echo "wp-login is in csfpost.sh. Archiving csfpost.sh."
		mv /etc/csf/csfpost.sh /etc/csf/csfpost.sh.old
	fi

}

system_specific_config(){
	## Grab values that need to be unique from existing CSF config
	TCP_IN=$(cat /etc/csf/csf.old | grep -i "TCP_IN =")
	TCP_OUT=$(cat /etc/csf/csf.old | grep -i "TCP_OUT =")
	TCP6_IN=$(cat /etc/csf/csf.old | grep -i "TCP6_IN =")
	TCP6_OUT=$(cat /etc/csf/csf.old | grep -i "TCP6_OUT =")
	UDP_IN=$(cat /etc/csf/csf.old | grep -i "UDP_IN =")
	UDP_OUT=$(cat /etc/csf/csf.old | grep -i "UDP_OUT =")
	UDP6_IN=$(cat /etc/csf/csf.old | grep -i "UDP6_IN =")
	UDP6_OUT=$(cat /etc/csf/csf.old | grep -i "UDP6_OUT =")
	LF_IPSET_NOIPSET=$(echo 'LF_IPSET = "0"')
	LF_IPSET=$(echo 'LF_IPSET = "1"')
	DENY_IP_LIMIT=$(echo 'DENY_IP_LIMIT = "300"')
	DENY_TEMP_IP_LIMIT=$(echo 'DENY_TEMP_IP_LIMIT = "100"')
	IPV6=$(echo 'IPV6 = "1"')
	IPV6_ICMP_STRICT=$(echo 'IPV6_ICMP_STRICT = "1"')
	IPV6_SPI=$(echo 'IPV6_SPI = "1"')
	IPV6_EL5=$(echo 'IPV6 = "0"')
	IPV6_ICMP_STRICT_EL5=$(echo 'IPV6_ICMP_STRICT = "0"')
	IPV6_SPI_EL5=$(echo 'IPV6_SPI = "0"')

	SYSSPECIFIC=$(cat /etc/csf/csf.old | sed -n '/OS Specific Settings/,/DEBUG/p' /etc/csf/csf.old)
	
	echo "$TCP_IN" >> /etc/csf/csf.conf
	echo "$TCP_OUT" >> /etc/csf/csf.conf
	echo "$TCP6_IN" >> /etc/csf/csf.conf
	echo "$TCP6_OUT" >> /etc/csf/csf.conf
	echo "$UDP_IN" >> /etc/csf/csf.conf
	echo "$UDP_OUT" >> /etc/csf/csf.conf
	echo "$UDP6_IN" >> /etc/csf/csf.conf
	echo "$UDP6_OUT" >> /etc/csf/csf.conf
	echo "$DENY_IP_LIMIT" >> /etc/csf/csf.conf
	echo "$DENY_TEMP_IP_LIMIT" >> /etc/csf/csf.conf

	if [ ! -f /usr/sbin/ipset ]; then
		echo "$LF_IPSET_NOIPSET" >> /etc/csf/csf.conf
	fi
	
	if [ -f /usr/sbin/ipset ]; then	
		echo "$LF_IPSET" >> /etc/csf/csf.conf
	fi
	
	EL5CHECK=$(uname -a | grep -i ".el5.")
	if [ -n "$EL5CHECK" ]; then
		echo "$IPV6_EL5" >> /etc/csf/csf.conf
		echo "$IPV6_ICMP_STRICT_EL5" >> /etc/csf/csf.conf
		echo "$IPV6_SPI_EL5" >> /etc/csf/csf.conf
	fi
	
	if [ -z "$EL5CHECK" ]; then
		echo "$IPV6" >> /etc/csf/csf.conf
		echo "$IPV6_ICMP_STRICT" >> /etc/csf/csf.conf
		echo "$IPV6_SPI" >> /etc/csf/csf.conf
	fi
	
	echo "$SYSSPECIFIC" >> /etc/csf/csf.conf
	
}

regex_custom(){
	mv /etc/csf/regex.custom.pm /etc/csf/regex.custom.pm.old && curl -o /etc/csf/regex.custom.pm http://url/regex.custom.pm
	sed -i '/CUSTOM9_LOG/d' /etc/csf/csf.conf
	echo 'CUSTOM9_LOG = "/usr/local/apache/domlogs/*/*"' >> /etc/csf/csf.conf
}

apply(){
	mv /etc/csf/csf.deny /etc/csf/csf.deny.old && touch /etc/csf/csf.deny && csf -x && csf -e && csf -R && service lfd restart
}

main(){
	check_environment "$@"
	move_zig "$@"
	system_specific_config "$@"
	regex_custom "$@"
	apply "$@"
	exit 0
}
  
main "$@"

