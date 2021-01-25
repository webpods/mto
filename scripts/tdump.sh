#!/bin/bash

if [ -z $1 ]
then
echo "mySQL Table Dump"
echo ""
echo "Database name"
read db
echo "Table name"
read tb
echo "Dumping table $tb from $db to `pwd`/$tb.sql"
mysqldump $db $tb > `pwd`/$tb.sql

else
echo "Dumping Table $2 from $2 to $3/$2.sql"
mysqldump $1 $2 > $3/$2.sql

fi
exit
