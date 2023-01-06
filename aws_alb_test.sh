#!/bin/bash
for i in {1..999};
do
    echo "$i starts kube " $(date "+[%Y-%m-%d %H:%M:%S]") \;
    kubectl get pods -n dev;
    echo "$i starts curl " $(date "+[%Y-%m-%d %H:%M:%S]") \;
    curl https://example-api.cn/prefix-jiameng-api/;
    echo \;
    echo "$i ends curl" `date "+%y-%m-%d %H:%M:%S"`\;
done
