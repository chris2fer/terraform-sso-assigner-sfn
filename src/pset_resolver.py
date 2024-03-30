import os
import json

import boto3

### BOTO Tools ###
boto = boto3.Session()
sso = boto.client('sso-admin')
##################

EXTERNAL_ID = os.getenv('TAG_ID')

def resolve_pset_tag(inst, tag):
    
    resp = sso.list_permission_sets(
        InstanceArn=inst,
        MaxResults=2
    )
    next_token = resp.get('NextToken')
    pset_list = resp['PermissionSets']

    for p in pset_list:
        resp = sso.list_tags_for_resource(
            InstanceArn=inst,
            ResourceArn=p
        )
        for t in resp['Tags']:
            if t == tag:
                return p
    
    while next_token:
        resp = sso.list_permission_sets(
            InstanceArn=inst,
            MaxResults=2,
            NextToken=next_token
        )
        next_token = resp.get('NextToken')
        pset_list = resp['PermissionSets']
        
        for p in pset_list:
            resp = sso.list_tags_for_resource(
                InstanceArn=inst,
                ResourceArn=p)
            for t in resp['Tags']:
                print(t)
                if t == tag:
                    return p
    return {}


def lambda_handler(event, context):
    inst = event['InstancesResult']['InstanceArn']
    tag = event['pvf_tag']
    print(f'Searching for Permission Set tagged with {tag["Key"]} with value {tag["Value"]}')
    pset = resolve_pset_tag(inst, tag)
    return pset
    # account = {k:v for (k,v) in resolve_account_tag(tag).items() if isinstance(v, str)}

    return {} #json.dumps(account)
