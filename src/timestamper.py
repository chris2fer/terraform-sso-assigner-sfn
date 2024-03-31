import datetime

def lambda_handler(event, context):
    
    p = '%Y-%m-%dT%H:%M:%S'
    ts = event['ts']
    utc_time = datetime.datetime.strptime(ts, "%Y-%m-%dT%H:%M:%S.%fZ")
    epoch_time = (utc_time - datetime.datetime(1970, 1, 1)).total_seconds()
    return int(epoch_time)
