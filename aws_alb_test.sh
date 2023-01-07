#!/bin/bash
for i in {1..999};
do
    echo "$i starts kube pod" $(date "+[%Y-%m-%d %H:%M:%S.%6N]") \;
    kubectl get pods --selector=app.kubernetes.io/name=jiameng-api-dev -o wide -n dev;
    aws elbv2 describe-target-health \
    --target-group-arn arn:aws-cn:elasticloadbalancing:cn-northwest-1:xxxx:targetgroup/k8s-dev-jiamenga-edb70a94b9/xxxxxxx;
    echo "$i starts curl " $(date "+[%Y-%m-%d %H:%M:%S.%6N]") \;
    curl https://example-api.cn/prefix-jiameng-api/;
    echo \;
    echo "$i ends curl" `date "+[%Y-%m-%d %H:%M:%S.%6N]"`\;
done
