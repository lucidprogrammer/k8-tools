#!/usr/bin/env bash
x="$(kubectl version --short=true | grep Server | awk '{print $3}' | awk -F'.' '{printf $1} {printf "."} {printf $2}' | tr -d v)"
git ls-remote --tags --sort -v:refname --refs https://github.com/kubernetes/autoscaler | grep cluster-autoscaler-${x} | head -n 1| awk '{print $2}'| awk -F'-' '{printf "v"}{printf $3}'