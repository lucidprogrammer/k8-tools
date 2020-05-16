#!/usr/bin/env bash

BINDIR="${BASH_SOURCE%/*}"
if [[ ! -d "$BINDIR" ]]; then BINDIR="$PWD"; fi

# this is the subdomain for your services. could be the namespace where your services are running
subdomain="${1:-""}"
hostedZoneDomain="${2:-""}"
profileForRoute53Changes="${3:-""}"
# if your aws resources are owned by another aws account.
profileOwningELB="${4:-"$profileForRoute53Changes"}"

EDGE_PROXY_NAMESPACE="${"$EDGE_PROXY_NAMESPACE":-"istio-system"}"
EDGE_PROXY_SERVICE_NAME="${"$EDGE_PROXY_SERVICE_NAME":-"istio-ingressgateway"}"

usage="Provide the namespace where the services are running
By default, we will 
"
if [ -n "${hostedZoneDomain}" ] && [ -n "${subdomain}" ] && [ -n "${profileForRoute53Changes}" ]; then
    mappingTarget="$(kubectl -n "${EDGE_PROXY_NAMESPACE}" get service "${EDGE_PROXY_SERVICE_NAME}" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    if [ -z "$mappingTarget" ]; then
        echo "Mapping target is not yet assigned";exit 1
    fi
    "${BINDIR}"/create-domain-mappings-aws.sh "$profileForRoute53Changes" "${hostedZoneDomain}" "${subdomain}" "${mappingTarget}" "UPSERT" "A" "yes" "$profileOwningELB"
else
    echo "$usage";exit 1
fi
