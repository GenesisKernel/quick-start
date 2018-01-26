#!/bin/bash

     key=`cat /s/s$1/KeyID`
     prKey1=`cat /s/s1/PrivateKey`
     keyID1=`cat /s/s1/KeyID`
     pubKey1=`cat /s/s1/NodePublicKey`
     keyID2=`cat /s/s2/KeyID`
     pubKey2=`cat /s/s2/NodePublicKey`
     keyID3=`cat /s/s3/KeyID`
     pubKey3=`cat /s/s3/NodePublicKey`
     keyID4=`cat /s/s4/KeyID`
     pubKey4=`cat /s/s4/NodePublicKey`
     keyID5=`cat /s/s5/KeyID`
     pubKey5=`cat /s/s5/NodePublicKey`
     host=127.0.0.1
     httpPort1=7001
     tcpPort2=7012
     tcpPort3=7013
     tcpPort4=7014
     tcpPort5=7015

if [ $1 == 2 ]
then
     cd /apla-tests/scripts && python3 newValToFullNodes.py "$prKey1" "$host" "$httpPort1" [[\"$host\",\"$keyID1\",\"$pubKey1\"],[\"$host:$tcpPort2\",\"$keyID2\",\"$pubKey2\"]]
fi

if [ $1 == 3 ]
then
  cd /apla-tests/scripts && python3 newValToFullNodes.py "$prKey1" "$host" "$httpPort1" [[\"$host\",\"$keyID1\",\"$pubKey1\"],[\"$host:$tcpPort2\",\"$keyID2\",\"$pubKey2\"],[\"$host:$tcpPort3\",\"$keyID3\",\"$pubKey3\"]]
fi

if [ $1 == 4 ]
then
  cd /apla-tests/scripts && python3 newValToFullNodes.py "$prKey1" "$host" "$httpPort1" [[\"$host\",\"$keyID1\",\"$pubKey1\"],[\"$host:$tcpPort2\",\"$keyID2\",\"$pubKey2\"],[\"$host:$tcpPort3\",\"$keyID3\",\"$pubKey3\"],[\"$host:$tcpPort4\",\"$keyID4\",\"$pubKey4\"]]
fi

if [ $1 == 5 ]
then
  cd /apla-tests/scripts && python3 newValToFullNodes.py "$prKey1" "$host" "$httpPort1" [[\"$host\",\"$keyID1\",\"$pubKey1\"],[\"$host:$tcpPort2\",\"$keyID2\",\"$pubKey2\"],[\"$host:$tcpPort3\",\"$keyID3\",\"$pubKey3\"],[\"$host:$tcpPort4\",\"$keyID4\",\"$pubKey4\"],[\"$host:$tcpPort5\",\"$keyID5\",\"$pubKey5\"]]
fi
