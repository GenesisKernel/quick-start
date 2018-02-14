import requests
import time
import sys
import json
from pprint import pprint

from genesis_api_client import wait_txstatus

if __name__ == "__main__":
	if len (sys.argv) < 9:
		print ("Error: Too few parameters")
	else:
		prKey1 = sys.argv[1]
		keyID1 =  sys.argv[2]
		pubKey1 = sys.argv[3]
		keyID2  = sys.argv[4]
		pubKey2 = sys.argv[5]
		host1 = sys.argv[6]
		httpPort1 = sys.argv[7]
		host2 = sys.argv[8]
		tcpPort2  = sys.argv[9]
		newVal = '[[\"'+host1+'\",\"' + keyID1 + '\",\"' + pubKey1 + '\"],[\"'+host2+':'+tcpPort2+'\",\"' + keyID2 + '\",\"' + pubKey2 + '\"]]'
		baseUrl = "http://"+host1+":"+httpPort1+"/api/v2"
		respUid = requests.get(baseUrl + '/getuid')
		resultGetuid = respUid.json()

		respSignTest = requests.post(baseUrl + '/signtest/', params={'forsign': resultGetuid['uid'], 'private': prKey1})
		resultSignTest = respSignTest.json()

		fullToken = 'Bearer ' + resultGetuid['token']
		respLogin = requests.post(baseUrl +'/login', params={'pubkey': resultSignTest['pubkey'], 'signature': resultSignTest['signature']}, headers={'Authorization': fullToken})
		resultLogin = respLogin.json()
		address = resultLogin["address"]
		timeToken = resultLogin["refresh"]
		jwtToken = 'Bearer ' + resultLogin["token"]

		dataCont = {"Name": "full_nodes", "Value" : newVal}
		resPrepareCall = requests.post(baseUrl +'/prepare/UpdateSysParam', data=dataCont, headers={'Authorization': jwtToken})
		jsPrepareCall = resPrepareCall.json()

		respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey1})
		resultSignTestPCall = respSignTestPCall.json()

		sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
		dataCont.update(sign_resCall)
		respCall = requests.post(baseUrl + '/contract/UpdateSysParam', data=dataCont, headers={"Authorization": jwtToken})
		resultCallContract = respCall.json()

		#time.sleep(10)
                wait_txstatus(baseUrl, resultCallContract["hash"], jwtToken,
                      "Import", 100)

		#statusCall = requests.get(baseUrl + '/txstatus/' + resultCallContract["hash"], headers={"Authorization": jwtToken})
		#statusCallJ = statusCall.json()
		#if len(statusCallJ["blockid"]) > 0:
		#	print("OK")
		#else:
		#	print("Error: fullNodes is not updated")
