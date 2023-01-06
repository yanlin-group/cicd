#!/bin/bash
for i in {1..999};
do
    echo "$i starts kube pod" $(date "+[%Y-%m-%d %H:%M:%S]") \;
    kubectl get pods --selector=app.kubernetes.io/name=jiameng-api-dev -o wide -n dev;
    aws elbv2 describe-target-health \
    --target-group-arn arn:aws-cn:elasticloadbalancing:cn-northwest-1:xxxxx:targetgroup/xxxxx;
    echo "$i starts curl " $(date "+[%Y-%m-%d %H:%M:%S]") \;
    curl https://example.cn/api/prefix-jiameng-api/;
    echo \;
    echo "$i ends curl" `date "+%y-%m-%d %H:%M:%S"`\;
done
