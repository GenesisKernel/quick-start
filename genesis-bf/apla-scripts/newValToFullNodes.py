import requests
import time
import sys
import json
from pprint import pprint

from genesis_api_client import wait_txstatus

if __name__ == "__main__":
    if len (sys.argv) < 4:
        print ("Error: Too few parameters")
    else:
        prKey1 = sys.argv[1]
        host1 = sys.argv[2]
        httpPort1 = sys.argv[3]
        newVal = sys.argv[4]
        print(newVal)
        baseUrl = "http://"+host1+":"+httpPort1+"/api/v2"
        respUid = requests.get(baseUrl + '/getuid')
        resultGetuid = respUid.json()
        
        respSignTest = requests.post(baseUrl + '/signtest/', params={'forsign': resultGetuid['uid'], 'private': prKey1})
        resultSignTest = respSignTest.json()
        print(resultSignTest)
        
        fullToken = 'Bearer ' + resultGetuid['token']
        respLogin = requests.post(baseUrl +'/login', params={'pubkey': resultSignTest['pubkey'], 'signature': resultSignTest['signature']}, headers={'Authorization': fullToken})
        resultLogin = respLogin.json()
        address = resultLogin["address"]
        timeToken = resultLogin["refresh"]
        jwtToken = 'Bearer ' + resultLogin["token"]
        
        dataCont = {"Name": "full_nodes", "Value" : newVal}
        print("-------------------------------")
        resPrepareCall = requests.post(baseUrl +'/prepare/UpdateSysParam', data=dataCont, headers={'Authorization': jwtToken})
        jsPrepareCall = resPrepareCall.json()
        print(jsPrepareCall)
        print("-------------------------------")
        respSignTestPCall = requests.post(baseUrl + '/signtest/', params={'forsign': jsPrepareCall['forsign'], 'private': prKey1})
        resultSignTestPCall = respSignTestPCall.json()
        print(resultSignTestPCall)
        
        sign_resCall = {"time": jsPrepareCall['time'], "signature": resultSignTestPCall['signature']}
        dataCont.update(sign_resCall)
        respCall = requests.post(baseUrl + '/contract/UpdateSysParam', data=dataCont, headers={"Authorization": jwtToken})
        resultCallContract = respCall.json()
        print(resultCallContract)
        
        #time.sleep(20)
        wait_txstatus(baseUrl, resultCallContract["hash"], jwtToken, "FullNodes", 100)
        #statusCall = requests.get(baseUrl + '/txstatus/' + resultCallContract["hash"], headers={"Authorization": jwtToken})
        #statusCallJ = statusCall.json()
        #print(statusCallJ)
        #if len(statusCallJ["blockid"]) > 0:
        #	print("OK")
        #else:
        #	print("Error: fullNodes is not updated")
