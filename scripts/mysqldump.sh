#!/bin/bash
#mySQL Dumper .01
tstamp=`date +%s`

	function mdump {

		#echo "User to connect with/ leave blank for default)"
		#read user
		#echo "Password"
		#read pass
		echo "Checking Dump directory" $DIR
		mkdir -pv $DIR
			for i in `mysql  -e "show databases"|grep -Ev "Database|information_schema|performance_schema"`
			do echo Backing up $i
			mysqldump  $i > $DIR/$i'_'$tstamp.sql
        		echo "Compressing backup of $i"
        		gzip -6 $DIR/$i'_'$tstamp.sql
			done
	        ls -larth $DIR/
	}



	if [ -z $1 ]
	then
		echo "Entering Interactive mode"
		echo "Dump mySQL to what dir? Without the trailing /"
		read DIR

		mdump
	exit 	
	else

		DIR=$1
		echo "Checking Dump directory" $DIR
		mkdir -pv $DIR

		echo "Non-Interactive Dunp to $DIR"
		mdump

	fi

exit

