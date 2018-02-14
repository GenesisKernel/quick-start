import requests
import time
from pprint import pprint
import sys

def wait_txstatus(base_url, tx_hash, jwt_token, contract_name, timeout_secs=100):
    timeout_secs = 100
    print("Waiting ({} seconds) until the transaction to be completed ...".format(timeout_secs))
    end_time = time.time() + timeout_secs
    stop=False
    result=0
    cnt=1
    while not stop:
        print("  try {}  requesting /txstatus ...".format(cnt))
        status = requests.get(base_url + '/txstatus/' + tx_hash, headers={"Authorization": jwt_token})
        status_json = status.json()

        print("    checking 'blockid' key: ", end=" ")
        if 'blockid' in status_json:
            if len(status_json["blockid"]) > 0:
                result=0
                stop=True
            else:
                print("blockid is empty")
                result = 1
        else:
            print("no blockid in response")
            result = 2
        if time.time() > end_time:
            stop = True
        #print("  * * * * * * * * * * * * * * * *")
        cnt += 1
        time.sleep(1)
    print(pprint(status_json))
    if result == 1:
        raise Exception("Import Error: blockid is empty")
    elif result == 2:
        raise Exception("Import Error: no 'blockid' key in response")
    print("-------------------------------")
    print("")

