#!/usr/bin/env bash

BINDIR="${BASH_SOURCE%/*}"
if [[ ! -d "$BINDIR" ]]; then BINDIR="$PWD"; fi

# this is the subdomain for your services. could be the namespace where your services are running
subdomain="${1:-""}"
hostedZoneDomain="${2:-""}"

r53=""
elb=""
if [ -n "${AWS_ACCESS_KEY_ID_R53}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_R53}" ] && [ -n "${AWS_DEFAULT_REGION_R53}" ]; then
    r53="$(printf "\n[r53]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = %s\n" "${AWS_ACCESS_KEY_ID_R53}" "${AWS_SECRET_ACCESS_KEY_R53}" "${AWS_DEFAULT_REGION_R53}")"
fi
if [ -n "${AWS_ACCESS_KEY_ID_ELB}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_ELB}" ] && [ -n "${AWS_DEFAULT_REGION_ELB}" ]; then
    elb="$(printf "\n[elb]\naws_access_key_id = %s\naws_secret_access_key = %s\nregion = %s\n" "${AWS_ACCESS_KEY_ID_ELB}" "${AWS_SECRET_ACCESS_KEY_ELB}" "${AWS_DEFAULT_REGION_ELB}")"
fi
if [ -n "${r53}" ] && [ -n "${elb}" ]; then
    if [ ! -d "$HOME"/.aws ]; then
        mkdir "$HOME"/.aws
    fi
    printf "%s\n%s" "${r53}" "${elb}" >> $HOME/.aws/credentials
    chmod 600 $HOME/.aws/credentials
    # change the input variables
    action="${5:-""}" #as we are mutating input, let's have them all
    set -- "$subdomain" "$hostedZoneDomain" "r53" "elb" "$action"
    
fi

profileForRoute53Changes="${3:-""}"
# if your aws resources are owned by another aws account.
profileOwningELB="${4:-"$profileForRoute53Changes"}"
action="${5:-"UPSERT"}"

EDGE_PROXY_NAMESPACE="${EDGE_PROXY_NAMESPACE:-"istio-system"}"
EDGE_PROXY_SERVICE_NAME="${EDGE_PROXY_SERVICE_NAME:-"istio-ingressgateway"}"

usage="Provide the namespace where the services are running
By default, we will 
"
if [ -n "${hostedZoneDomain}" ] && [ -n "${subdomain}" ] && [ -n "${profileForRoute53Changes}" ]; then
    mappingTarget="$(kubectl -n "${EDGE_PROXY_NAMESPACE}" get service "${EDGE_PROXY_SERVICE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    if [ -z "$mappingTarget" ]; then
        echo "Mapping target is not yet assigned";exit 1
    fi
    "${BINDIR}"/create-domain-mappings-aws.sh "$profileForRoute53Changes" "${hostedZoneDomain}" "${subdomain}" "${mappingTarget}" "$action" "A" "yes" "$profileOwningELB"
else
    echo "$usage";exit 1
fi


