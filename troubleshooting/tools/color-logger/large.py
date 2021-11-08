import datetime
from collections import OrderedDict
import time
import os
import json 
import signal
import random
from fluent import sender

# for local fluent
logger = sender.FluentSender('large-logs-tester')

name = os.environ.get("NAME", "logger")

def print_log(obj):
    if os.environ.get("FLUENT_LOGGER", False):
        logger.emit(name, obj)
        if not logger.emit('large-logs-tester', obj):
            print(logger.last_error)
            logger.clear_last_error() # clear stored error after handled errors
    else:
        print(json.dumps(obj))


PAYLOAD_SIZE = int(os.environ.get("PAYLOAD_SIZE", 32))
PAYLOAD_COUNT = int(os.environ.get("PAYLOAD_COUNT", 100))
MESSAGE_INTERVAL = float(os.environ.get("MESSAGE_INTERVAL", 10))
SIGNAL_PAYLOAD_SIZE = int(os.environ.get("SIGNAL_PAYLOAD_SIZE", 128000))
SIGNAL_PAYLOAD_COUNT = int(os.environ.get("SIGNAL_PAYLOAD_COUNT", 100))

id = 0

def sig_handler(i):
    global id
    for _ in range(10):
        if id < SIGNAL_PAYLOAD_COUNT:
            event_id = int(random.random()*1000)
            print_log(OrderedDict({
                "payload": "x" * SIGNAL_PAYLOAD_SIZE,
                "event_id": event_id,
                "counter": id,
                "global_counter": i, 
                "time": '%s' % datetime.datetime.now(),
            }))
        id += 1
    
def main():
    for i in range(PAYLOAD_COUNT):
        sig_handler(i)
        print("Logged 10 events")
        time.sleep(MESSAGE_INTERVAL)

if __name__ == '__main__': main()
