#!/bin/bash

for i in $(seq 2 $1)
do

if [ -f "/s/s$i/apla.pid" ]
then
   rm /s/s$i/apla.pid
fi

if [ ! -d "/s/s$i" ]
then
   mkdir /s/s$i
fi

if [ $1 == 1 ]
then
   echo "1 started"
else
     cd /apla && ./go-apla -workDir=/s/s$i -tcpPort=701$1 -httpPort=700$i -dbHost=genesis-db -dbPort=5432 -dbName=eg$i -dbUser=postgres -dbPassword=111111 --configPath /dev/null -initDatabase=1 -generateFirstBlock=1 -noStart=1 > /dev/null

     key=`cat /s/s1/KeyID`
     prKey1=`cat /s/s1/PrivateKey`
     keyID1=`cat /s/s1/KeyID`
     pubKey1=`cat /s/s1/NodePublicKey`
     keyID2=`cat /s/s$i/KeyID`
     pubKey2=`cat /s/s$i/NodePublicKey`
     host1=127.0.0.1
     httpPort1=7001
     host2=127.0.0.1
     tcpPort2=701$1
fi

sed 's/INSTANCE/'$i'/g' /go_apla > /etc/supervisord.d/go_apla$i.conf
sed -i -e 's/keyID2/'$keyID2'/g' /etc/supervisord.d/go_apla$i.conf

done

