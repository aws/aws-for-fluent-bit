The logger will create 3 types of log events.


1. Type 1: controlled by PAYLOAD_COUNT

```
{
    "time": # timestamp,
    "gauge": # a counter from 0 to PAYLOAD_COUNT - 1,
    "uuid": "abc{gauge}",
    "payload": "x" * PAYLOAD_SIZE
}
```

You can search for specific events easily in CW Logs UI with
the value of the "uuid" field. For example, search "abc77".

2. Type 2: Events sent once for every 100 Type 1 events sent

```
{
    "blue": True,
    "id": # a counter from 0 to PAYLOAD_COUNT - 1,
    "time": # timestamp,
}
```

Search for "blue" in CW Logs UI and check for id's 0, 100, 200, 300... 

3. Type 3: sent once for every 71 Type 1 events, up to SIGNAL_PAYLOAD_COUNT

```
{
    "payload": "x" * SIGNAL_PAYLOAD_SIZE,
    "event_id": event_id,
    "counter": # ID from 0 to SIGNAL_PAYLOAD_COUNT,
    "global_counter": # same as ID in type 2 above, allows you to check these large logs 
    # with the smaller ones that are sent before and after them
    "time": # timestamp,
}
```

These events are very large by default. Search for "counter" in CW Logs UI and check that 
all events are found. 




