
import boto3

### BOTO Tools ###
boto = boto3.Session()
org = boto.client('organizations')
##################


def resolve_account_tag(tag):
    
    resp = org.list_accounts(
        MaxResults=2
    )
    next_token = resp.get('NextToken')
    account_list = resp['Accounts']

    for a in account_list:
        print(a)
        print(f"Checking Account named {a['Name']}")
        resp = org.list_tags_for_resource(
            ResourceId=a['Id']
        )
        for t in resp['Tags']:
            print(t)
            if t == tag:
                return {k:v for (k,v) in a.items() if isinstance(v,str)}
    
    while next_token:
        resp = org.list_accounts(
            MaxResults=2,
            NextToken=next_token
        )
        next_token = resp.get('NextToken')
        account_list = resp['Accounts']
        
        for a in account_list:
            print(a)
            
            print(f"Checking Account named {a['Name']}")
            resp = org.list_tags_for_resource(
                ResourceId=a['Id'])
            for t in resp['Tags']:
                print(t)
                if t == tag:
                    return {k:v for (k,v) in a.items() if isinstance(v,str)}
    return {}


def lambda_handler(event, context):
    tag = event['tag']

    print(f'Searching Org Accounts for the {tag["Key"]} with value {tag["Value"]}')

    account = {k:v for (k,v) in resolve_account_tag(tag).items() if isinstance(v, str)}

    return account
