#!/usr/bin/env bash
export FNDIR="${BASH_SOURCE%/*}"
if [[ ! -d "$FNDIR" ]]; then FNDIR="$PWD"; fi

usage="
Usage: create_subdomain aws_profile_name root_domain subdomaintocreate mappingTarget action recordType
1.aws_profile_name - (profile which owns route53 resources)provide it if you are working from a machine which may have multiple profiles and you want to use something other than default
                   Alternatively provide AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION as environment variables

2.hostedZoneDomain - which is the domain used for the hosted zone
3.subdomain - what is the subdomain you want to create, it could be like sub or sub.sub etc
4.mappingTarget - what is the IP address/elb address or another domain name(if you want to do CNAME)
5.action - default is UPSERT. Otherwise you say remove to DELETE the mapping
6.recordType - default is A - You can say CNAME also
7.nested - default is yes. ie it will create subdomain.maindomain and *.subdomain.maindomain
8.awsProfileForMappingTarget - aws profile which owns the mappingTarget - say elb
"
profile="${1:-""}"
if [ -n "${AWS_ACCESS_KEY_ID}" ] && [ -n "${AWS_SECRET_ACCESS_KEY}" ] && [ -n "${AWS_DEFAULT_REGION}" ] ; then
    profile="default"
fi
if [ -z "$profile" ];then
    echo "AWS Profile is needed- $usage";exit 1
fi
if [ "${profile}" == default ]; then
    profile=""
fi
export hostedZoneDomain="${2:-""}"
if [ -z "$hostedZoneDomain" ];then
    echo "root domain name is needed- $usage";exit 1
fi
# add a dot at the end
export hostedZoneDomain="$hostedZoneDomain".
export subdomain="${3:-""}"
if [ -z "$subdomain" ];then
    echo "subdomain name is needed- $usage";exit 1
fi
export mappingTarget="${4:-""}"
if [ -z "$mappingTarget" ];then
    echo "mappingTarget for CNAME/A record is needed- $usage";exit 1
fi
export action="${5:-"UPSERT"}"
export comment="Upsert subdomain"
if [[ "$action" == remove ]]; then
    action="DELETE"
    comment="Delete subdomain"
fi
export recordType="${6:-"A"}"
export nested="${7:-"yes"}"
export awsProfileForMappingTarget="${8:-"${profile}"}"

if [[ "${mappingTarget}" == *elb.amazonaws.com ]]; then
    export CanonicalHostedZoneNameID
    if [ -n "$awsProfileForMappingTarget" ]; then
        CanonicalHostedZoneNameID="$(aws elb describe-load-balancers --profile "$awsProfileForMappingTarget" | jq -r --arg CanonicalHostedZoneName "${mappingTarget}" '.LoadBalancerDescriptions[] | select(.CanonicalHostedZoneName==$CanonicalHostedZoneName)| .CanonicalHostedZoneNameID' )"
    else
        CanonicalHostedZoneNameID="$(aws elb describe-load-balancers | jq -r --arg CanonicalHostedZoneName "${mappingTarget}" '.LoadBalancerDescriptions[] | select(.CanonicalHostedZoneName==$CanonicalHostedZoneName)| .CanonicalHostedZoneNameID' )"
    fi
   
fi


export hostedzone_id
if [ -n "$profile" ]; then
    hostedzone_id="$(aws route53 list-hosted-zones --profile "$profile" | jq -r --arg hostedZoneDomain "$hostedZoneDomain" '.HostedZones[] | select(.Name==$hostedZoneDomain and .Config.PrivateZone==false)| .Id' | awk -F'/' '{print $3}')"
else
    hostedzone_id="$(aws route53 list-hosted-zones | jq -r --arg hostedZoneDomain "$hostedZoneDomain" '.HostedZones[] | select(.Name==$hostedZoneDomain and .Config.PrivateZone==false)| .Id' | awk -F'/' '{print $3}')"
fi

if [ -z "$hostedzone_id" ];then
    echo "unable to get hostedzone id";exit 1
fi
echo "$hostedzone_id"
python -c "
import os
import json
payload = dict()
payload['Comment'] = os.environ.get('comment')
changes = list()
root_change = dict()
root_change['Action'] = os.environ.get('action')
root_resource_record_set = dict()
root_resource_record_set['Name'] = '%s.%s' %(os.environ.get('subdomain'),os.environ.get('hostedZoneDomain'))
root_resource_record_set['Type'] = os.environ.get('recordType')
# root_resource_record_set['TTL'] = 300

if(os.environ.get('mappingTarget').endswith('.elb.amazonaws.com')):
    root_resource_record_set['AliasTarget'] = {
        'HostedZoneId': os.environ.get('CanonicalHostedZoneNameID'),
        'DNSName': 'dualstack.%s.' % os.environ.get('mappingTarget'),
        'EvaluateTargetHealth' : False
    }
else:
    root_resource_record_set['ResourceRecords'] = [{'Value': os.environ.get('mappingTarget')}]

nested_change = None
if(os.environ.get('nested') == 'yes'):
    nested_change = dict()
    nested_change['Action'] =  os.environ.get('action')
    nested_resource_record = dict()
    nested_resource_record['Name'] = '\052.%s.%s' %(os.environ.get('subdomain'),os.environ.get('hostedZoneDomain'))
    nested_resource_record['Type'] = os.environ.get('recordType')
    nested_resource_record['AliasTarget'] = {
        'HostedZoneId': os.environ.get('hostedzone_id'),
        'DNSName': '%s.%s' %(os.environ.get('subdomain'),os.environ.get('hostedZoneDomain')),
        'EvaluateTargetHealth' : False
    }
    nested_change['ResourceRecordSet'] = nested_resource_record
root_change['ResourceRecordSet'] = root_resource_record_set
changes.append(root_change)
if(nested_change):
    changes.append(nested_change)
 
payload['Changes'] = changes
file_name = '%s.%s-record-set.json' %(os.environ.get('subdomain'),os.environ.get('hostedZoneDomain'))
file = os.path.join(os.environ.get('FNDIR'),file_name )
print(file)
with open(file, 'w') as writer:
    writer.write(json.dumps(payload,indent=2))
"

if [ -n "$profile" ]; then
    aws route53 change-resource-record-sets --profile "$profile"  --hosted-zone-id "$hostedzone_id" --change-batch file://"${FNDIR}"/"${subdomain}.${hostedZoneDomain}"-record-set.json
else
    aws route53 change-resource-record-sets  --hosted-zone-id "$hostedzone_id" --change-batch file://"${FNDIR}"/"${subdomain}.${hostedZoneDomain}"-record-set.json
fi
