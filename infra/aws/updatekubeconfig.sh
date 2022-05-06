#!/usr/bin/env bash

output = $(aws eks --region $1 update-kubeconfig --name $2 --profile $3)

result="{\"status\": \"$output\"}"
echo $result