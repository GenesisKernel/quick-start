import requests
import time
import sys
import random
import string
import json

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

        with open(dataPath, 'br') as f:
            data = str(f.read(), 'utf-8')

        baseUrl = "http://" + host + ":" + httpPort + "/api/v2"
        respUid = requests.get(baseUrl + '/getuid')
        resultGetuid = respUid.json()
        
        respSignTest = requests.post(baseUrl + '/signtest/', params={'forsign': resultGetuid['uid'], 'private': prKey})
        resultSignTest = respSignTest.json()
        print(resultSignTest)

        fullToken = 'Bearer ' + resultGetuid['token']
        respLogin = requests.post(baseUrl +'/login', params={'pubkey': resultSignTest['pubkey'], 'signature': resultSignTest['signature']}, headers={'Authorization': fullToken})
        resultLogin = respLogin.json()
        address = resultLogin["address"]
        timeToken = resultLogin["refresh"]
        jvtToken = 'Bearer ' + resultLogin["token"]

        dataCont = {'Name': 'con_import_demo_page_' + generate_random_name()}
        dataCont['Data'] = data
        print("-------------------------------")
        resPrepareCall = requests.post(baseUrl +'/prepare/Import', data=dataCont, headers={'Authorization': jvtToken})
        jsPrepareCall = resPrepareCall.json()
        
        print("-------------------------------")
        respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey})
        resultSignTestPCall = respSignTestPCall.json()
        print(resultSignTestPCall)
        
        sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
        dataCont.update(sign_resCall)
        respCall = requests.post(baseUrl + '/contract/Import', data=dataCont, headers={"Authorization": jvtToken})
        resultCallContract = respCall.json()
        print(resultCallContract)

        time.sleep(20)

        statusCall = requests.get(baseUrl + '/txstatus/' + resultCallContract["hash"], headers={"Authorization": jvtToken})
        statusCallJ = statusCall.json()
        print(statusCallJ)
        if len(statusCallJ["blockid"]) > 0:
            print("Import OK")
        else:
            print("Import Error")
            exit(1)
           
        dataCont = {}
        print("-------------------------------")
        resPrepareCall = requests.post(baseUrl +'/prepare/MemberAutoreg', data=dataCont, headers={'Authorization': jvtToken})
        jsPrepareCall = resPrepareCall.json()
        
        print("-------------------------------")
        respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey})
        resultSignTestPCall = respSignTestPCall.json()
        print(resultSignTestPCall)
        
        sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
        dataCont.update(sign_resCall)
        respCall = requests.post(baseUrl + '/contract/MemberAutoreg', data=dataCont, headers={"Authorization": jvtToken})
        resultCallContract = respCall.json()
        print(resultCallContract)

        time.sleep(20)

        statusCall = requests.get(baseUrl + '/txstatus/' + resultCallContract["hash"], headers={"Authorization": jvtToken})
        statusCallJ = statusCall.json()
        print(statusCallJ)
        if len(statusCallJ["blockid"]) > 0:
            print("MemberAutoreg OK")
        else:
            print("MemberAutoreg Error")
            exit(2)
