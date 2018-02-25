import requests
import time
import sys
import random
import string
import json
from pprint import pprint

from genesis_api_client import wait_txstatus

def generate_random_name():
	name = []
	for _ in range(1, 30):
		sym = random.choice(string.ascii_lowercase)
		name.append(sym)
	return "".join(name)

if __name__ == "__main__":
    if len (sys.argv) < 4:
        print ("Error: Too few parameters")
    else:
        prKey = sys.argv[1]
        host = sys.argv[2]
        httpPort = sys.argv[3]
        dataPath = sys.argv[4]
        
        baseUrl = "http://" + host + ":" + httpPort + "/api/v2"

        with open(dataPath, 'br') as f:
            data = str(f.read(), 'utf-8')

        print("requesting /getuid ...")
        baseUrl = "http://" + host + ":" + httpPort + "/api/v2"
        respUid = requests.get(baseUrl + '/getuid')
        resultGetuid = respUid.json()
        print(pprint(resultGetuid))
        print("-------------------------------\n")
        
        print("requesting /signtest with private key ...")
        respSignTest = requests.post(baseUrl + '/signtest/', params={'forsign': resultGetuid['uid'], 'private': prKey})
        resultSignTest = respSignTest.json()
        print(pprint(resultSignTest))
        print("-------------------------------\n")

        print("requesting /loging ...")
        fullToken = 'Bearer ' + resultGetuid['token']
        respLogin = requests.post(baseUrl +'/login', params={'pubkey': resultSignTest['pubkey'], 'signature': resultSignTest['signature']}, headers={'Authorization': fullToken})
        resultLogin = respLogin.json()
        print(pprint(resultLogin))
        print("-------------------------------\n")

        address = resultLogin["address"]
        timeToken = resultLogin["refresh"]
        jwtToken = 'Bearer ' + resultLogin["token"]

        dataCont = {'Name': 'con_import_demo_page_' + generate_random_name()}
        dataCont['Data'] = data
        print("requesting /prepare/Import ...")
        resPrepareCall = requests.post(baseUrl +'/prepare/Import', data=dataCont, headers={'Authorization': jwtToken})
        print(pprint(resPrepareCall))
        print("-------------------------------\n")

        jsPrepareCall = resPrepareCall.json()
        
        print("requesting /signtest ...")
        respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey})
        resultSignTestPCall = respSignTestPCall.json()
        print(pprint(resultSignTestPCall))
        print("-------------------------------\n")
        
        sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
        dataCont.update(sign_resCall)
        print("requesting /contract/Import ...")
        respCall = requests.post(baseUrl + '/contract/Import', data=dataCont, headers={"Authorization": jwtToken})
        resultCallContract = respCall.json()
        print(pprint(resultCallContract))
        print("-------------------------------\n")
        
        wait_txstatus(baseUrl, resultCallContract["hash"], jwtToken,
                      "Import", 100)
           
        dataCont = {}
        print("requesting /prepare/MembersAutoreg ...")
        resPrepareCall = requests.post(baseUrl +'/prepare/MembersAutoreg', data=dataCont, headers={'Authorization': jwtToken})
        jsPrepareCall = resPrepareCall.json()
        print(pprint(jsPrepareCall))
        print("-------------------------------\n")

        print("requesting /signtest ...")
        respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey})
        resultSignTestPCall = respSignTestPCall.json()
        print(pprint(resultSignTestPCall))
        print("-------------------------------\n")
        
        sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
        dataCont.update(sign_resCall)

        print("requesting /contract/MembersAutoreg ...")
        respCall = requests.post(baseUrl + '/contract/MembersAutoreg', data=dataCont, headers={"Authorization": jwtToken})
        resultCallContract = respCall.json()
        print(pprint(resultCallContract))
        print("-------------------------------\n")

        wait_txstatus(baseUrl, resultCallContract["hash"], jwtToken,
                      "MembersAutoreg", 100)
